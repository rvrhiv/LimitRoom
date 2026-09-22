import AppKit
import Observation

@MainActor @Observable
final class PresentationCoordinator {
  private(set) var showsMenuBar = true
  @ObservationIgnored private let model: AppModel
  @ObservationIgnored private let windows: ApplicationWindows
  @ObservationIgnored private var notch: NotchPanelController?
  @ObservationIgnored private weak var menuBarPanel: NSWindow?
  @ObservationIgnored private var observations: [(NotificationCenter, NSObjectProtocol)] = []
  @ObservationIgnored private var presentationObservation: NSKeyValueObservation?
  @ObservationIgnored private var settleTask: Task<Void, Never>?
  @ObservationIgnored private var started = false
  @ObservationIgnored private var sleeping = false
  @ObservationIgnored private var inactiveSession = false

  init(model: AppModel) {
    self.model = model
    windows = ApplicationWindows(model: model)
  }

  func start() {
    guard !started else { return }
    started = true
    notch = NotchPanelController(
      model: model,
      openHistory: { [weak self] in self?.openHistory() },
      openSettings: { [weak self] in self?.openSettings() })
    model.presentation.onModeChange = { [weak self] in
      self?.notch?.hide()
      self?.reconcile()
    }
    model.presentation.onLayoutChange = { [weak self] in
      self?.notch?.preferencesDidChange()
    }
    observe(NSApplication.didChangeScreenParametersNotification) { [weak self] in
      self?.reconcile()
      self?.scheduleReconcile()
    }
    let workspace = NSWorkspace.shared.notificationCenter
    observe(NSWorkspace.activeSpaceDidChangeNotification, center: workspace) { [weak self] in
      // A stationary all-Spaces panel is already in place. Do not order it out,
      // discard the pinned/open state, then recreate it after the debounce.
      self?.reconcile()
      self?.scheduleReconcile()
    }
    observe(NSWorkspace.didActivateApplicationNotification, center: workspace) { [weak self] in
      self?.scheduleReconcile()
    }
    observe(NSWorkspace.willSleepNotification, center: workspace) { [weak self] in
      self?.sleeping = true
      self?.notch?.hide()
    }
    observe(NSWorkspace.didWakeNotification, center: workspace) { [weak self] in
      self?.sleeping = false
      self?.scheduleReconcile()
    }
    observe(NSWorkspace.sessionDidResignActiveNotification, center: workspace) { [weak self] in
      self?.inactiveSession = true
      self?.notch?.hide()
    }
    observe(NSWorkspace.sessionDidBecomeActiveNotification, center: workspace) { [weak self] in
      self?.inactiveSession = false
      self?.scheduleReconcile()
    }
    presentationObservation = NSApp.observe(\.currentSystemPresentationOptions, options: [.new]) {
      [weak self] _, _ in
      Task { @MainActor [weak self] in self?.scheduleReconcile() }
    }
    reconcile()
  }

  func stop() {
    started = false
    settleTask?.cancel()
    presentationObservation?.invalidate()
    presentationObservation = nil
    for (center, token) in observations { center.removeObserver(token) }
    observations.removeAll()
    model.presentation.onModeChange = nil
    model.presentation.onLayoutChange = nil
    notch?.stop()
    notch = nil
  }

  func openHistory() {
    presentAuxiliaryWindow { windows.openHistory() }
  }
  func openSettings() {
    presentAuxiliaryWindow { windows.openSettings() }
  }

  func captureMenuBarPanel(_ window: NSWindow) {
    menuBarPanel = window
  }

  func dismissMenuBarPanel() {
    menuBarPanel?.orderOut(nil)
  }

  private func presentAuxiliaryWindow(_ present: () -> Void) {
    notch?.close()
    dismissMenuBarPanel()
    present()
  }

  private func observe(
    _ name: Notification.Name, center: NotificationCenter = .default,
    action: @escaping @MainActor @Sendable () -> Void
  ) {
    let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
      MainActor.assumeIsolated { action() }
    }
    observations.append((center, token))
  }

  private func scheduleReconcile() {
    settleTask?.cancel()
    settleTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
      guard !Task.isCancelled else { return }
      self?.reconcile()
    }
  }

  private func reconcile() {
    guard started else { return }
    guard model.presentation.mode == .notch else {
      showsMenuBar = true
      model.presentation.fallbackMessage = nil
      notch?.hide()
      return
    }
    guard let geometry = NSScreen.screens.compactMap({ NotchGeometry(screen: $0) }).first else {
      showsMenuBar = true
      model.presentation.fallbackMessage = localized(
        "Встроенный экран с вырезом недоступен. Временно используется строка меню; выбор режима сохранён.",
        "A built-in notched display is unavailable. Temporarily using the menu bar; your preference is saved."
      )
      notch?.hide()
      return
    }
    showsMenuBar = false
    model.presentation.fallbackMessage = nil
    if sleeping || inactiveSession || isFullscreen(on: geometry) {
      notch?.hide()
    } else {
      notch?.show(on: geometry)
    }
  }

  private func isFullscreen(on geometry: NotchGeometry) -> Bool {
    let options = NSApp.currentSystemPresentationOptions
    guard options.contains(.fullScreen) || options.contains(.hideMenuBar) else { return false }
    // No pixels, titles, URLs or documents are read. Bounds disambiguate another
    // display's full-screen app; collectionBehavior additionally excludes full-screen Spaces.
    guard let owner = NSWorkspace.shared.frontmostApplication?.processIdentifier,
      let list = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID) as? [[String: Any]]
    else { return true }
    let display = CGDisplayBounds(geometry.displayID)
    return list.contains { info in
      guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == owner,
        (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
        let dictionary = info[kCGWindowBounds as String] as? [String: Any],
        let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary)
      else { return false }
      let overlap = bounds.intersection(display)
      return !overlap.isNull && overlap.width >= display.width - 4
        && overlap.height >= display.height - geometry.cameraFrame.height - 4
    }
  }
}

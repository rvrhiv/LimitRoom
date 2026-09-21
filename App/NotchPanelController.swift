import AppKit
import SwiftUI

@MainActor
final class NotchPanelController {
  let state = NotchPanelState()
  private let model: AppModel
  private let openHistory: () -> Void
  private let openSettings: () -> Void
  private var panel: NotchWindow?
  private var geometry: NotchGeometry?
  private var isVisible = false
  private var hoverArmed = false
  private var isAnimating = false
  private var menuDepth = 0
  private var lastHapticAt = -Double.infinity
  private var openTask: Task<Void, Never>?
  private var closeTask: Task<Void, Never>?
  private var resizeTask: Task<Void, Never>?
  private var keyMonitor: Any?
  private var localPointerMonitor: Any?
  private var globalPointerMonitor: Any?
  private var observers: [NSObjectProtocol] = []

  init(model: AppModel, openHistory: @escaping () -> Void, openSettings: @escaping () -> Void) {
    self.model = model
    self.openHistory = openHistory
    self.openSettings = openSettings
  }

  func show(on geometry: NotchGeometry) {
    if self.geometry == geometry && isVisible { return }
    hide()
    self.geometry = geometry
    state.cameraWidth = geometry.cameraFrame.width
    state.cameraHeight = geometry.cameraFrame.height
    state.expandedHeight = geometry.expandedHeight
    if panel == nil { createWindow() }
    guard let panel, let frame = targetFrame(expanded: false) else { return }
    applyFrame(frame, to: panel)
    panel.hasShadow = false
    isVisible = true
    hoverArmed = !pointerInside
    installPointerMonitors()
    panel.orderFrontRegardless()
  }

  func hide() {
    cancelOpen()
    cancelClose()
    resizeTask?.cancel()
    resizeTask = nil
    removePointerMonitors()
    isAnimating = false
    isVisible = false
    hoverArmed = false
    state.isExpanded = false
    state.isHeld = false
    menuDepth = 0
    panel?.orderOut(nil)
  }

  func preferencesDidChange() {
    guard isVisible else { return }
    cancelOpen()
    cancelClose()
    if !state.isExpanded, let frame = targetFrame(expanded: false) {
      // Enlarging a wing underneath a stationary pointer is not user intent to open.
      hoverArmed = !containsPointer(frame)
    }
    resize(expanded: state.isExpanded)
  }

  func close() {
    cancelOpen()
    cancelClose()
    guard isVisible else { return }
    state.isHeld = false
    guard state.isExpanded else { return }
    state.isExpanded = false
    panel?.resignKey()
    if let frame = targetFrame(expanded: false) { hoverArmed = !containsPointer(frame) }
    resize(expanded: false)
  }

  func stop() {
    hide()
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    keyMonitor = nil
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    panel?.close()
    panel = nil
  }

  private func createWindow() {
    let panel = NotchWindow(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isFloatingPanel = true
    // Set AFTER isFloatingPanel: AppKit resets the level to .floating (3) there.
    // Above status items (25), below native menus (101) and protected system UI.
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    panel.becomesKeyOnlyIfNeeded = false
    panel.isMovable = false
    panel.acceptsMouseMovedEvents = true
    panel.animationBehavior = .none
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
    let hosting = TrackingHostingView(
      rootView: NotchRootView(
        model: model, state: state,
        open: { [weak self] in self?.expand(userInitiated: true) },
        toggleHold: { [weak self] in self?.toggleHold() },
        close: { [weak self] in self?.close() },
        openHistory: { [weak self] in self?.openHistory() },
        openSettings: { [weak self] in self?.openSettings() }))
    hosting.sizingOptions = []
    hosting.autoresizingMask = [.width, .height]
    hosting.hoverChanged = { [weak self] in self?.pointerMoved() }
    panel.contentView = hosting
    self.panel = panel

    // Escape is LOCAL only, and handled only when a click has made this panel key.
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      let isEscape = event.keyCode == 53
      let handled = MainActor.assumeIsolated {
        guard let self, self.state.isExpanded, self.panel?.isKeyWindow == true, isEscape
        else { return false }
        self.close()
        return true
      }
      return handled ? nil : event
    }
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated {
          guard let self, self.isVisible, self.state.isExpanded else { return }
          self.menuDepth += 1
          self.cancelClose()
        }
      })
    observers.append(
      center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated {
          guard let self else { return }
          self.menuDepth = max(0, self.menuDepth - 1)
          if !self.pointerInside { self.scheduleClose() }
        }
      })
  }

  private func installPointerMonitors() {
    removePointerMonitors()
    let mask: NSEvent.EventTypeMask = [
      .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
      .leftMouseUp, .rightMouseUp, .otherMouseUp,
    ]
    // Global mouse events cover the physical cutout when another app is active.
    // No global keyboard events, stored event data, event suppression or polling.
    globalPointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
      MainActor.assumeIsolated { self?.pointerMoved() }
    }
    localPointerMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
      MainActor.assumeIsolated { self?.pointerMoved() }
      return event
    }
  }

  private func removePointerMonitors() {
    if let localPointerMonitor { NSEvent.removeMonitor(localPointerMonitor) }
    if let globalPointerMonitor { NSEvent.removeMonitor(globalPointerMonitor) }
    localPointerMonitor = nil
    globalPointerMonitor = nil
  }

  private func targetFrame(expanded: Bool) -> CGRect? {
    geometry?.panelFrame(
      expanded: expanded, leftWidth: model.presentation.leftWidth,
      rightWidth: model.presentation.rightWidth)
  }

  private func containsPointer(_ frame: CGRect) -> Bool {
    let point = NSEvent.mouseLocation
    // Include the top edge: the pointer can sit exactly on screen.frame.maxY.
    return point.x >= frame.minX && point.x <= frame.maxX
      && point.y >= frame.minY && point.y <= frame.maxY
  }

  private var pointerInside: Bool {
    guard isVisible else { return false }
    // A closing body must not remain an opening hot zone during its animation.
    guard let frame = state.isExpanded ? panel?.frame : targetFrame(expanded: false) else {
      return false
    }
    return containsPointer(frame)
  }

  private func pointerMoved() {
    guard isVisible else { return }
    if pointerInside {
      cancelClose()
      guard NSEvent.pressedMouseButtons == 0 else {
        cancelOpen()
        return
      }
      guard !state.isExpanded, hoverArmed, openTask == nil else { return }
      // Do not restart this delay on each mouseMoved event.
      openTask = Task { [weak self] in
        do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
        guard let self, !Task.isCancelled else { return }
        self.openTask = nil
        guard self.pointerInside, self.hoverArmed, NSEvent.pressedMouseButtons == 0 else { return }
        self.expand(userInitiated: true)
      }
    } else {
      hoverArmed = true
      cancelOpen()
      scheduleClose()
    }
  }

  private func cancelOpen() {
    openTask?.cancel()
    openTask = nil
  }

  private func cancelClose() {
    closeTask?.cancel()
    closeTask = nil
  }

  private func scheduleClose() {
    guard closeTask == nil, isVisible, state.isExpanded, !state.isHeld, !isAnimating, menuDepth == 0
    else { return }
    closeTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(360)) } catch { return }
      guard let self, !Task.isCancelled else { return }
      self.closeTask = nil
      guard !self.pointerInside, !self.state.isHeld, self.menuDepth == 0 else { return }
      self.close()
    }
  }

  private func expand(userInitiated: Bool) {
    cancelOpen()
    cancelClose()
    guard isVisible, !state.isExpanded else { return }
    state.isExpanded = true
    resize(expanded: true)
    let now = ProcessInfo.processInfo.systemUptime
    if userInitiated, !model.isDemo, model.presentation.hapticsEnabled, now - lastHapticAt >= 0.8 {
      lastHapticAt = now
      NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
  }

  private func toggleHold() {
    guard state.isExpanded else { return }
    state.isHeld.toggle()
    cancelClose()
    if !state.isHeld && !pointerInside { scheduleClose() }
  }

  private func applyFrame(_ frame: CGRect, to panel: NotchWindow) {
    guard let geometry else { return }
    // The window may expand asymmetrically; the camera must never drift with it.
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      panel.setFrame(frame, display: false)
      state.cameraLeading = geometry.cameraFrame.minX - panel.frame.minX
      panel.contentView?.layoutSubtreeIfNeeded()
      panel.displayIfNeeded()
    }
  }

  private func resize(expanded: Bool) {
    resizeTask?.cancel()
    guard let panel, let geometry, let target = targetFrame(expanded: expanded) else { return }
    let initial = panel.frame
    // A native shadow can reveal a separate top edge against the camera.
    panel.hasShadow = false
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || initial == target {
      isAnimating = false
      applyFrame(target, to: panel)
      panel.invalidateShadow()
      if expanded && !pointerInside { scheduleClose() }
      return
    }
    isAnimating = true
    let began = ProcessInfo.processInfo.systemUptime
    let duration = expanded ? 0.32 : 0.22
    // Finite, cancellable transition only; no animation clock runs while idle.
    resizeTask = Task { [weak self, weak panel] in
      while !Task.isCancelled {
        guard let self, let panel, self.isVisible else { return }
        let progress = min(1, (ProcessInfo.processInfo.systemUptime - began) / duration)
        let eased = CGFloat(1 - pow(1 - progress, 3))
        let x = initial.minX + (target.minX - initial.minX) * eased
        let width = initial.width + (target.width - initial.width) * eased
        let height = initial.height + (target.height - initial.height) * eased
        self.applyFrame(
          CGRect(x: x, y: geometry.screenFrame.maxY - height, width: width, height: height),
          to: panel)
        if progress >= 1 {
          self.isAnimating = false
          self.resizeTask = nil
          panel.invalidateShadow()
          if expanded && !self.pointerInside { self.scheduleClose() }
          return
        }
        do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
      }
    }
  }
}

private final class NotchWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }
}

private final class TrackingHostingView<Content: View>: NSHostingView<Content> {
  var hoverChanged: (() -> Void)?
  private var area: NSTrackingArea?
  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let area { removeTrackingArea(area) }
    let next = NSTrackingArea(
      rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self, userInfo: nil)
    addTrackingArea(next)
    area = next
  }
  override func mouseEntered(with event: NSEvent) { hoverChanged?() }
  override func mouseExited(with event: NSEvent) { hoverChanged?() }
}

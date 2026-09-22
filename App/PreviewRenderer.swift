import AllowanceCore
import AppKit
import SwiftUI

/// Developer-only rendering of our own synthetic views, not a screen capture.
/// Requires --demo; neither a collector nor a presentation controller is started.
@MainActor
enum PreviewRenderer {
  static func renderIfRequested(model: AppModel) -> Bool {
    guard model.isDemo, CommandLine.arguments.contains("--render-preview") else { return false }
    guard let output = argument("--render-preview") else {
      fail("--render-preview requires an output path.")
    }
    let dark = CommandLine.arguments.contains("--dark")
    if let raw = argument("--mode"), let mode = PresentationMode(rawValue: raw) {
      model.presentation.mode = mode
    }
    if let raw = argument("--settings-agent"), let agent = AgentID(rawValue: raw) {
      model.settingsAgent = agent
    }
    model.presentation.showPercentage = !CommandLine.arguments.contains("--hide-percentage")
    for side in ["left", "right", "menu"] {
      if let raw = argument("--\(side)-components") {
        let values = Set(raw.split(separator: ",").map(String.init))
        guard values.isSubset(of: ["icon", "ring", "percentage", "none"]) else {
          fail("Components must be icon,ring,percentage or none.")
        }
        let components = IndicatorComponents(
          icon: values.contains("icon"), ring: values.contains("ring"),
          percentage: values.contains("percentage"))
        switch side {
        case "left": model.presentation.leftComponents = components
        case "right": model.presentation.rightComponents = components
        default: model.presentation.menuComponents = components
        }
      }
    }
    if let raw = argument("--left") {
      guard let value = NotchSlotContent(rawValue: raw) else { fail("Invalid --left content.") }
      model.presentation.leftContent = value
    }
    if let raw = argument("--right") {
      guard let value = NotchSlotContent(rawValue: raw) else { fail("Invalid --right content.") }
      model.presentation.rightContent = value
    }
    if let raw = argument("--reset-style") {
      guard let value = ResetDisplayStyle(rawValue: raw) else { fail("Invalid --reset-style.") }
      model.presentation.resetStyle = value
    }
    if let raw = argument("--side-width") {
      guard let value = Double(raw), value.isFinite, (56...160).contains(value) else {
        fail("--side-width must be between 56 and 160 points.")
      }
      model.presentation.sideWidth = value
    }
    let tab = argument("--tab").flatMap(DashboardTab.init(rawValue:)) ?? .quotas
    if let raw = argument("--statistics-mode"), let mode = StatisticsMode(rawValue: raw) {
      model.statisticsMode = mode
    }
    if let raw = argument("--history-days"), let days = Int(raw), [1, 3, 7, 30, 90].contains(days) {
      model.historyDays = days
    }
    let surface = argument("--surface") ?? "menu"
    let content: AnyView
    let size: CGSize
    switch surface {
    case "agent-details":
      guard let snapshot = model.snapshots.first(where: { $0.agent == model.settingsAgent }) else {
        fail("Missing demo agent.")
      }
      size = CGSize(width: 414, height: 600)
      content = AnyView(
        VStack {
          AgentCard(
            snapshot: snapshot, selection: model.selection, now: model.displayDate,
            pin: { _ in }, connect: {}, expanded: true)
          Spacer(minLength: 0)
        }.padding(20)
          .frame(width: size.width, height: size.height, alignment: .top)
          .environment(\.colorScheme, dark ? .dark : .light)
          .background(dark ? Color.black : Color.white))
    case "history":
      size = CGSize(width: 860, height: 740)
      content = AnyView(
        HistoryView(model: model)
          .environment(\.colorScheme, dark ? .dark : .light)
          .background(dark ? Color.black : Color.white))
    case "connections":
      model.settingsPage = .agents
      size = CGSize(width: 840, height: 700)
      content = AnyView(
        SettingsView(model: model)
          .environment(\.colorScheme, dark ? .dark : .light))
    case "settings":
      model.settingsPage =
        argument("--settings-page").flatMap(SettingsPage.init(rawValue:)) ?? .appearance
      size = CGSize(width: 840, height: 700)
      content = AnyView(
        SettingsView(model: model)
          .environment(\.colorScheme, dark ? .dark : .light))
    case "menu":
      size = CGSize(width: 414, height: 638)
      content = AnyView(
        DashboardView(model: model, tab: tab)
          .environment(\.colorScheme, dark ? .dark : .light)
          .background(dark ? Color.black : Color.white))
    case "notch-compact", "notch-expanded":
      let expanded = surface == "notch-expanded"
      let state = NotchPanelState()
      state.cameraWidth = 185
      state.expandedHeight = 686
      state.isExpanded = expanded
      let panelWidth =
        expanded
        ? max(
          NotchGeometry.expandedWidth,
          state.cameraWidth + 2 * max(model.presentation.leftWidth, model.presentation.rightWidth))
        : state.cameraWidth + model.presentation.leftWidth + model.presentation.rightWidth
      state.cameraLeading =
        expanded ? (panelWidth - state.cameraWidth) / 2 : model.presentation.leftWidth
      let bodyHeight: CGFloat = expanded ? state.expandedHeight : state.cameraHeight
      size = CGSize(width: panelWidth + 32, height: bodyHeight + 16)
      content = AnyView(
        VStack(spacing: 0) {
          NotchRootView(
            model: model, state: state, open: {}, toggleHold: {}, close: {},
            openHistory: {}, openSettings: {}
          )
          .frame(
            width: panelWidth, height: bodyHeight)
          Spacer(minLength: 16)
        }.frame(width: size.width, height: size.height)
          .background(Color(red: 0.28, green: 0.32, blue: 0.36)))
    case "indicator":
      size = CGSize(width: 160, height: 32)
      content = AnyView(
        MenuBarIndicatorImage(model: model)
          .frame(width: size.width, height: size.height)
          .environment(\.colorScheme, dark ? .dark : .light)
          .background(dark ? Color.black : Color.white))
    case "display-settings":
      size = CGSize(width: 430, height: 800)
      content = AnyView(
        VStack(alignment: .leading, spacing: 16) {
          Text("\(AppIdentity.name) · DEMO · v\(AppIdentity.version)").font(
            .system(size: 13, weight: .semibold))
          DisplayPreferencesControls(model: model)
            .font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
          Spacer(minLength: 0)
        }.padding(18).frame(width: size.width, height: size.height, alignment: .top)
          .environment(\.colorScheme, dark ? .dark : .light)
          .background(dark ? Color.black : Color.white))
    default:
      fail("Unknown preview surface: \(surface).")
    }
    // Offscreen windows are inactive; render native controls as they appear
    // while the user is interacting with the settings window.
    let hosting = NSHostingView(rootView: content.environment(\.controlActiveState, .active))
    let frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(
      contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: dark || surface.hasPrefix("notch") ? .darkAqua : .aqua)
    window.contentView = hosting
    hosting.frame = frame
    // NSScrollView-backed content is not included by SwiftUI ImageRenderer.
    // Only this offscreen hierarchy is rendered; no desktop or other app is captured.
    DispatchQueue.main.async {
      hosting.layoutSubtreeIfNeeded()
      guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
        fail("Could not allocate the preview image.")
      }
      hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
      guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fail("Could not encode the preview image.")
      }
      do { try data.write(to: URL(fileURLWithPath: output), options: .atomic) } catch {
        fail("Could not write the preview image: \(error.localizedDescription)")
      }
      withExtendedLifetime(window) { NSApp.terminate(nil) }
    }
    return true
  }

  private static func argument(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name),
      CommandLine.arguments.indices.contains(index + 1),
      !CommandLine.arguments[index + 1].hasPrefix("--")
    else { return nil }
    return CommandLine.arguments[index + 1]
  }
  private static func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(EXIT_FAILURE)
  }
}

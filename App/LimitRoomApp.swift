import AllowanceCore
import AppKit
import SwiftUI

@main
struct LimitRoomApp: App {
  @NSApplicationDelegateAdaptor(LimitRoomDelegate.self) private var delegate
  @State private var model: AppModel
  @State private var presentation: PresentationCoordinator

  init() {
    let model = AppModel()
    let presentation = PresentationCoordinator(model: model)
    _model = State(initialValue: model)
    _presentation = State(initialValue: presentation)
    LimitRoomDelegate.model = model
    LimitRoomDelegate.presentation = presentation
  }
  var body: some Scene {
    MenuBarExtra(
      isInserted: Binding(
        get: { presentation.showsMenuBar && !LimitRoomDelegate.isRenderingPreview },
        set: { _ in })
    ) {
      DashboardView(
        model: model, openHistory: presentation.openHistory,
        openSettings: presentation.openSettings)
    } label: {
      MenuBarIndicatorImage(model: model)
    }
    .menuBarExtraStyle(.window)
  }
}

@MainActor
final class LimitRoomDelegate: NSObject, NSApplicationDelegate {
  static weak var model: AppModel?
  static weak var presentation: PresentationCoordinator?
  static var isRenderingPreview: Bool {
    model?.isDemo == true && CommandLine.arguments.contains("--render-preview")
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    if let model = Self.model, PreviewRenderer.renderIfRequested(model: model) { return }
    Self.model?.updates.start()
    Self.presentation?.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    Self.presentation?.stop()
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    Self.presentation?.openSettings()
    return false
  }
  func application(_ application: NSApplication, open urls: [URL]) {
    guard urls.contains(where: { $0.scheme == "limitroom" && $0.host == "history" }) else { return }
    Self.presentation?.openHistory()
  }
}

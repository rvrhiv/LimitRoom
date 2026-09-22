import AppKit
import SwiftUI

@MainActor
final class ApplicationWindows {
  private let model: AppModel
  private var history: NSWindow?
  private var settings: NSWindow?
  init(model: AppModel) { self.model = model }

  func openHistory() {
    if history == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered, defer: false)
      window.title = localized("История \(AppIdentity.name)", "\(AppIdentity.name) history")
      window.contentView = NSHostingView(
        rootView: HistoryView(model: model).frame(minWidth: 690, minHeight: 470))
      window.isReleasedWhenClosed = false
      window.center()
      history = window
    }
    history?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func openSettings() {
    if settings == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 840, height: 700),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered, defer: false)
      window.title = localized("Настройки \(AppIdentity.name)", "\(AppIdentity.name) settings")
      window.contentView = NSHostingView(
        rootView: SettingsView(model: model))
      window.contentMinSize = NSSize(width: 800, height: 640)
      window.isReleasedWhenClosed = false
      window.center()
      settings = window
    }
    settings?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}

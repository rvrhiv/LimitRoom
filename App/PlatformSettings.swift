import AppKit
import ServiceManagement
import UserNotifications

@MainActor
enum PlatformSettings {
  static var loginStatus: SMAppService.Status { SMAppService.mainApp.status }
  static func setLaunchAtLogin(_ enabled: Bool) throws {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }
  static func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
  static func requestNotifications() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]))
      ?? false
  }
  static func notify(id: String, title: String, body: String) async {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    try? await UNUserNotificationCenter.current().add(
      UNNotificationRequest(identifier: id, content: content, trigger: nil))
  }
}

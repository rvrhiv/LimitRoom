import AppKit
import ServiceManagement
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
  case appearance, agents, notifications, general, updates
  var id: String { rawValue }
  var title: String {
    switch self {
    case .appearance: localized("Внешний вид", "Appearance")
    case .agents: localized("Агенты", "Agents")
    case .notifications: localized("Уведомления", "Notifications")
    case .general: localized("Основные", "General")
    case .updates: localized("Обновления", "Updates")
    }
  }
  var symbol: String {
    switch self {
    case .appearance: "menubar.rectangle"
    case .agents: "square.stack.3d.up"
    case .notifications: "bell"
    case .general: "gearshape"
    case .updates: "arrow.down.circle"
    }
  }
}

struct SettingsView: View {
  @Bindable var model: AppModel
  @State private var loginEnabled = PlatformSettings.loginStatus == .enabled

  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 10) {
          AppIconView().frame(width: 32, height: 32)
          VStack(alignment: .leading, spacing: 2) {
            Text("LimitRoom").font(.headline)
            Text(AppIdentity.versionLabel).font(.caption).foregroundStyle(.secondary)
          }
        }.padding(.horizontal, 10).padding(.top, 20).padding(.bottom, 18)
        ForEach(SettingsPage.allCases) { page in
          Button {
            model.settingsPage = page
          } label: {
            Label(page.title, systemImage: page.symbol)
              .font(.system(size: 13))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 10).padding(.vertical, 10)
              .contentShape(Rectangle())
          }
          .buttonStyle(DashboardTabButtonStyle(isSelected: model.settingsPage == page))
          .accessibilityAddTraits(model.settingsPage == page ? .isSelected : [])
        }
        Spacer()
        Text(localized("Оформление сохраняется сразу", "Appearance saves automatically"))
          .font(.caption2).foregroundStyle(.secondary).padding(10)
      }.padding(.horizontal, 10).frame(width: 176).background(.regularMaterial)
      Divider()
      VStack(alignment: .leading, spacing: 8) {
        Text(model.settingsPage.title).font(.title2.bold())
          .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 10)
        pageContent.frame(maxWidth: .infinity, maxHeight: .infinity)
        if let message = model.errorMessage {
          Text(message).font(.caption).foregroundStyle(.orange)
            .padding(.horizontal, 24).padding(.bottom, 12)
        }
      }
    }
    .frame(minWidth: 800, minHeight: 640)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear { loginEnabled = PlatformSettings.loginStatus == .enabled }
  }

  @ViewBuilder private var pageContent: some View {
    switch model.settingsPage {
    case .appearance:
      ScrollView {
        DisplayPreferencesControls(model: model).padding(.horizontal, 24).padding(.bottom, 24)
      }
    case .agents:
      AgentSettingsView(model: model)
    case .notifications:
      Form {
        Section {
          Toggle(
            localized("Предупреждать о низкой квоте", "Warn about low allowance"),
            isOn: Binding(
              get: { model.notificationsEnabled },
              set: { enabled in Task { await model.setNotifications(enabled) } })
          )
          .disabled(model.isDemo)
          Text(
            localized(
              "Уведомления при 20% и 10% остатка. Только по свежим показаниям.",
              "Notifications at 20% and 10% remaining. Only for fresh readings.")
          )
          .font(.callout).foregroundStyle(.secondary)
        }
      }.formStyle(.grouped)
    case .general:
      Form {
        Section {
          Toggle(
            localized("Запускать при входе в macOS", "Launch at login"),
            isOn: Binding(
              get: { loginEnabled },
              set: { enabled in
                do { try PlatformSettings.setLaunchAtLogin(enabled) } catch {
                  model.errorMessage = localized(
                    "Проверьте разрешение автозапуска в macOS.",
                    "Check the login item permission in macOS.")
                }
                loginEnabled = PlatformSettings.loginStatus == .enabled
              })
          ).disabled(model.isDemo)
          if PlatformSettings.loginStatus == .requiresApproval {
            Button(localized("Разрешить в macOS…", "Approve in macOS…")) {
              PlatformSettings.openLoginSettings()
            }
          }
        }
        Section(localized("Приложение", "Application")) {
          LabeledContent(
            localized("Язык и оформление", "Language and appearance"),
            value: localized("Как в macOS", "Follow macOS"))
          LabeledContent(
            localized("Обновление показаний", "Allowance refresh"),
            value: localized("Каждые 5 минут", "Every 5 minutes"))
          Text(
            localized(
              "История хранится только на этом Mac. Пароли и токены не попадают в историю.",
              "History stays on this Mac. Passwords and tokens are not stored in history.")
          )
          .font(.callout).foregroundStyle(.secondary)
        }
        Section(localized("Виджет macOS", "macOS widget")) {
          Text(
            localized(
              "Для установки виджета нужна подписанная сборка с App Group. В локальной сборке виджет не установлен.",
              "Installing the widget requires a signed build with an App Group. The local build does not install the widget."
            )
          )
          .font(.callout).foregroundStyle(.secondary)
        }
      }.formStyle(.grouped)
    case .updates:
      UpdateSettingsView(updates: model.updates)
    }
  }
}

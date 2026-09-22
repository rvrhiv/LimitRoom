import AllowanceCore
import AppKit
import SwiftUI

struct AgentSettingsView: View {
  @Bindable var model: AppModel
  @State private var copied = false
  @State private var confirmClaudeReconnect = false
  @State private var confirmCursorLocal = false

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 8) {
        ForEach(AgentID.allCases) { agent in
          Button {
            model.settingsAgent = agent
          } label: {
            HStack(spacing: 7) {
              AgentIcon(agent: agent, size: 16)
              Text(agent.title)
            }.frame(maxWidth: .infinity).padding(.vertical, 8)
              .contentShape(Rectangle())
          }
          .buttonStyle(DashboardTabButtonStyle(isSelected: model.settingsAgent == agent))
          .accessibilityAddTraits(model.settingsAgent == agent ? .isSelected : [])
        }
      }.padding(.horizontal, 20)
      Form {
        Section {
          LabeledContent(
            localized("Состояние", "Status"),
            value: model.snapshots.first { $0.agent == model.settingsAgent }?.state.label
              ?? SourceState.needsSetup.label)
        }
        if model.settingsAgent == .codex {
          Section("Codex") {
            Text(
              localized(
                "Используется текущий вход в Codex. Обычно ничего настраивать не нужно.",
                "Uses your current Codex sign-in. Usually no setup is needed.")
            )
            .foregroundStyle(.secondary)
            Button(localized("Обновить подключение", "Refresh connection")) {
              Task { await model.refresh() }
            }.disabled(model.isDemo || model.isRefreshing)
            DisclosureGroup(localized("Другой путь к Codex CLI", "Custom Codex CLI path")) {
              TextField(
                localized("Путь к Codex CLI (необязательно)", "Codex CLI path (optional)"),
                text: $model.codexPath
              )
              .textFieldStyle(.roundedBorder)
              HStack {
                Text(
                  localized(
                    "Используется существующий вход Codex.", "Uses your existing Codex sign-in.")
                )
                .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(localized("Применить", "Apply")) { Task { await model.applyCodexPath() } }
                  .disabled(
                    model.isDemo)
              }
            }.disclosureGroupStyle(FullRowDisclosureStyle())
          }

        } else if model.settingsAgent == .claude {
          Section("Claude Code") {
            Text(
              localized(
                "Кнопка настроит statusLine автоматически. Существующая команда продолжит работать; перед изменением сохраняется резервная копия. Вход в аккаунт остаётся в Claude Code.",
                "Connect configures statusLine automatically. An existing command keeps working, and settings are backed up first. Account sign-in stays in Claude Code."
              )
            )
            .font(.caption).foregroundStyle(.secondary)
            HStack {
              Button(
                model.claudeConnecting
                  ? localized("Подключение…", "Connecting…")
                  : model.claudeConfigured
                    ? localized("Настроить заново", "Configure again")
                    : localized("Подключить", "Connect")
              ) { Task { await model.connectClaude() } }
              .disabled(model.isDemo || model.claudeConnecting)
              if model.claudeManaged {
                Button(localized("Отключить", "Disconnect")) {
                  Task { await model.disconnectClaude() }
                }
                .disabled(model.isDemo || model.claudeConnecting)
              }
            }
            if let message = model.claudeMessage {
              Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            DisclosureGroup(localized("Ручная настройка", "Manual setup")) {
              Text(model.claudeSettingsURL.path).font(.caption2).foregroundStyle(.secondary)
                .textSelection(.enabled)
              Text(claudeCommand).font(.system(.caption2, design: .monospaced)).textSelection(
                .enabled
              )
              .lineLimit(3)
              Button(
                copied
                  ? localized("Скопировано", "Copied")
                  : localized("Скопировать команду", "Copy command")
              ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(claudeCommand, forType: .string)
                copied = true
              }
            }.disclosureGroupStyle(FullRowDisclosureStyle())
            HStack {
              Link(
                localized("Инструкция Claude", "Claude documentation"),
                destination: URL(string: "https://code.claude.com/docs/en/statusline")!)
            }
            Text(
              localized(
                "Квота появляется после ответа Claude Code, если подписка передаёт rate_limits (Pro/Max). Настройки проекта могут переопределить statusLine. При смене аккаунта переподключите источник; аккаунт автоматически не определяется.",
                "Quota arrives after a Claude Code response when the plan exposes rate_limits (Pro/Max). Project settings can override statusLine. Reconnect after switching accounts; account identity is not detected automatically."
              )
            )
            .font(.caption2).foregroundStyle(.secondary)
            Button(localized("Я сменил аккаунт Claude…", "I changed my Claude account…")) {
              confirmClaudeReconnect = true
            }.disabled(model.isDemo || model.claudeConnecting)
          }

        } else {
          Section("Cursor") {
            Text(localized("Личная подписка", "Personal subscription"))
            Text(
              localized(
                "Используйте аккаунт, в который уже вошли в установленном Cursor. Квоту запрашиваем у Cursor, а не вычисляем по локальным чатам.",
                "Use the account already signed in to the installed Cursor app. Usage comes from Cursor, not estimates from local chats."
              )
            ).font(.caption).foregroundStyle(.secondary)
            HStack {
              Button(
                model.cursorUsesLocalSession
                  ? localized("Переподключить Cursor.app…", "Reconnect Cursor.app…")
                  : localized("Подключить Cursor.app…", "Connect Cursor.app…")
              ) {
                confirmCursorLocal = true
              }
              .disabled(model.isDemo || model.cursorDisconnecting || model.cursorConnecting)
              if model.cursorUsesLocalSession || model.cursorSignIn != nil {
                Button(localized("Отключить", "Disconnect")) {
                  Task { await model.disconnectCursor() }
                }
                .disabled(model.isDemo || model.cursorDisconnecting || model.cursorConnecting)
              }
            }
            if model.cursorUsesLocalSession {
              Text(
                localized(
                  "Источник входа: установленный Cursor.app", "Sign-in source: installed Cursor.app"
                )
              )
              .font(.caption2).foregroundStyle(.secondary)
            }
            Text(
              model.cursorMessage
                ?? localized(
                  "Доступ к локальному входу включается только после подтверждения. Браузеры и Keychain не читаются.",
                  "Local sign-in access is enabled only after confirmation. Browsers and Keychain are not read."
                )
            )
            .font(.caption).foregroundStyle(.secondary)
            DisclosureGroup(localized("Другой способ входа", "Alternative sign-in")) {
              Text(
                localized(
                  "Отдельный web-профиль LimitRoom. Некоторые способы SSO могут не работать. Выбор заменит источник Cursor.app и может использовать другой аккаунт.",
                  "A separate LimitRoom web profile. Some SSO methods may not work. This replaces the Cursor.app source and may use a different account."
                )
              ).font(.caption).foregroundStyle(.secondary)
              Button(localized("Войти на сайте Cursor…", "Sign in on Cursor's website…")) {
                Task { await model.connectCursor() }
              }
              .disabled(model.isDemo || model.cursorDisconnecting || model.cursorConnecting)
            }.disclosureGroupStyle(FullRowDisclosureStyle())
          }

        }
      }.formStyle(.grouped)
    }
    .alert(
      localized("Подключить аккаунт Cursor.app?", "Connect the Cursor.app account?"),
      isPresented: $confirmCursorLocal
    ) {
      Button(localized("Разрешить и подключить", "Allow and connect")) {
        Task { await model.connectLocalCursor() }
      }
      Button(localized("Отмена", "Cancel"), role: .cancel) {}
    } message: {
      Text(
        localized(
          "LimitRoom прочитает только ключ текущего входа из локальной базы Cursor (User/globalStorage/state.vscdb) и отправит его только на cursor.com для чтения квоты и подписки. Ключ не сохраняется в LimitRoom. Чаты, проекты, браузеры и Keychain не читаются; вход в Cursor не меняется. Доступ можно отключить здесь в любой момент.",
          "LimitRoom will read only the current sign-in token from Cursor's local database (User/globalStorage/state.vscdb) and send it only to cursor.com to read usage and subscription. LimitRoom does not save the token. Chats, projects, browsers and Keychain are not read, and Cursor sign-in is unchanged. You can disconnect here at any time."
        ))
    }
    .alert(
      localized("Отделить историю нового аккаунта?", "Start a separate account history?"),
      isPresented: $confirmClaudeReconnect
    ) {
      Button(localized("Переподключить", "Reconnect")) {
        Task {
          await model.reconnectClaude()
          copied = false
        }
      }
      Button(localized("Отмена", "Cancel"), role: .cancel) {}
    } message: {
      Text(
        localized(
          "Автоматическое подключение будет обновлено; ручную команду нужно скопировать заново. Перезапустите Claude Code. Старая история сохранится отдельно.",
          "Automatic setup will be updated; a manual command must be copied again. Restart Claude Code. Previous history stays separate."
        ))
    }
  }

  private var claudeCommand: String {
    let path = Bundle.main.bundleURL.appendingPathComponent(
      "Contents/Helpers/limitroom-claude-bridge"
    ).path
    func quote(_ value: String) -> String {
      "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
    return "\(quote(path)) --scope \(quote(model.claudeScope))"
  }
}

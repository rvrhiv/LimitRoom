import SwiftUI

struct UpdateSettingsView: View {
  @Bindable var updates: UpdateController
  var body: some View {
    Form {
      Section {
        if updates.isDemo {
          Text(
            localized(
              "DEMO · Проверка и установка отключены",
              "DEMO · Checking and installation are disabled")
          ).font(.caption).foregroundStyle(.secondary)
        }
        LabeledContent(
          localized("Установленная версия", "Installed version"), value: AppIdentity.versionLabel)
        Label(
          updates.status,
          systemImage: updates.phase == .available
            ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath"
        )
        .foregroundStyle(updates.phase == .available ? Color.accentColor : .primary)
        if let version = updates.availableVersion {
          LabeledContent(localized("Новая версия", "New version"), value: version)
        }
        if let date = updates.lastChecked {
          LabeledContent(
            localized("Последняя проверка", "Last checked"),
            value: date.formatted(date: .abbreviated, time: .shortened))
        }
        if updates.isBusy {
          ProgressView(value: updates.progress).progressViewStyle(.linear)
        }
        if let message = updates.message {
          Text(message).font(.callout).foregroundStyle(.secondary)
        }
        HStack {
          if updates.phase == .available {
            Button(localized("Обновить и перезапустить", "Update and relaunch")) {
              updates.install()
            }
            .buttonStyle(.borderedProminent).disabled(!updates.canInstall)
          }
          Button(localized("Проверить обновления", "Check for updates")) { updates.check() }
            .disabled(!updates.canCheck || updates.isBusy || updates.isDemo)
          if updates.canCancel {
            Button(localized("Отмена", "Cancel")) { updates.cancel() }
          }
        }
        Link(
          localized("Что нового в релизах ↗", "What's new in releases ↗"),
          destination: UpdateController.releases)
      }
      Section {
        Toggle(
          localized("Проверять обновления автоматически", "Check for updates automatically"),
          isOn: Binding(get: { updates.automaticChecks }, set: { updates.setAutomaticChecks($0) })
        )
        .disabled(updates.phase == .disabled || updates.isDemo)
        Text(
          localized(
            "Новая версия подсвечивается в панели. Установка — только по кнопке, с проверкой подписи и перезапуском приложения. Данные агентов не отправляются.",
            "New versions are highlighted in the panel. Installation requires a click and verifies the signature before relaunching. Agent data is never sent."
          )
        )
        .font(.callout).foregroundStyle(.secondary)
      }
    }.formStyle(.grouped)
  }
}

struct CompactUpdateButton: View {
  var updates: UpdateController
  var openSettings: () -> Void
  var body: some View {
    if updates.phase == .available || updates.isBusy || updates.phase == .failed {
      Button {
        if updates.canInstall { updates.install() } else { openSettings() }
      } label: {
        HStack(spacing: 4) {
          Image(
            systemName: updates.phase == .failed
              ? "exclamationmark.arrow.triangle.2.circlepath" : "arrow.down.circle.fill")
          if let progress = updates.progress {
            Text(progress, format: .percent.precision(.fractionLength(0)))
          } else if updates.phase == .available {
            Text(localized("Обновить", "Update"))
          }
        }.padding(.horizontal, 6).padding(.vertical, 4).contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(updates.phase == .failed ? Color.orange : Color.accentColor)
      .background(Color.accentColor.opacity(0.12), in: Capsule())
      .help(updates.status + (updates.availableVersion.map { " · " + $0 } ?? ""))
      .accessibilityLabel(updates.status)
    }
  }
}

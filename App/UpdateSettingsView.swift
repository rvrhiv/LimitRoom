import AppKit
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
          AppIdentity.isDevelopmentBuild
            ? localized(
              "Локальная сборка не заменяется релизами из GitHub. Чтобы обновить LimitRoom Dev, соберите приложение заново.",
              "GitHub releases do not replace local builds. Rebuild the app to update LimitRoom Dev."
            )
            : localized(
              "Новая версия подсвечивается в панели. Установка — только по кнопке, с проверкой подписи и перезапуском приложения. Данные агентов не отправляются.",
              "New versions are highlighted in the panel. Installation requires a click and verifies the signature before relaunching. Agent data is never sent."
            )
        )
        .font(.callout).foregroundStyle(.secondary)
      }
    }.formStyle(.grouped)
  }
}

struct AppUpdateButton: View {
  var updates: UpdateController
  var openSettings: () -> Void
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    if updates.phase == .available || updates.isBusy || updates.phase == .failed {
      Button {
        if updates.canInstall { updates.install() } else { openSettings() }
      } label: {
        HStack(spacing: 8) {
          Image(
            systemName: updates.phase == .failed
              ? "exclamationmark.arrow.triangle.2.circlepath" : "arrow.down.circle.fill")
          Text(title).lineLimit(1)
          Spacer(minLength: 0)
          if updates.isBusy, let progress = updates.progress {
            Text(progress, format: .percent.precision(.fractionLength(0))).monospacedDigit()
          } else {
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
          }
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 6).padding(.vertical, 6)
        .frame(maxWidth: .infinity).contentShape(Rectangle())
      }
      .buttonStyle(
        AppUpdateButtonStyle(
          color: updates.phase == .failed ? .orange : presentationAccent(scheme),
          foreground: updates.phase == .failed || scheme == .dark ? .black : .white)
      )
      .help(updates.status + (updates.availableVersion.map { " · " + $0 } ?? ""))
      .accessibilityLabel(title)
      .accessibilityValue(
        updates.progress?.formatted(.percent.precision(.fractionLength(0))) ?? ""
      )
      .accessibilityHint(
        updates.canInstall
          ? localized(
            "Установить обновление и перезапустить LimitRoom", "Install and relaunch LimitRoom")
          : localized("Открыть настройки обновлений", "Open update settings")
      )
      .padding(.top, 6).padding(.bottom, 4)
    }
  }

  private var title: String {
    if updates.phase == .available {
      return localized("Обновить LimitRoom", "Update LimitRoom")
        + (updates.availableVersion.map { " · v" + $0 } ?? "")
    }
    return updates.status
  }
}

/// The notch is intentionally non-activating. Keep its update action distinct
/// even when AppKit would draw an inactive prominent button in gray.
private struct AppUpdateButtonStyle: ButtonStyle {
  var color: Color
  var foreground: Color
  @State private var isHovered = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 6).padding(.vertical, 4)
      .foregroundStyle(foreground)
      .background(
        color.opacity(configuration.isPressed ? 0.72 : isHovered ? 0.88 : 1),
        in: RoundedRectangle(cornerRadius: 8)
      )
      .contentShape(RoundedRectangle(cornerRadius: 8))
      .onHover { isHovered = $0 }
      .onContinuousHover { phase in
        switch phase {
        case .active: NSCursor.pointingHand.set()
        case .ended: NSCursor.arrow.set()
        }
      }
      .onDisappear { if isHovered { NSCursor.arrow.set() } }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
  }
}

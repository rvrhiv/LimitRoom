import AllowanceCore
import AppKit
import SwiftUI

enum DashboardStyle { case menuBar, notch }
enum DashboardTab: String, CaseIterable {
  case quotas, statistics, settings
  var title: String {
    switch self {
    case .quotas: localized("Квоты", "Allowances")
    case .statistics: localized("Статистика", "Statistics")
    case .settings: localized("Настройки", "Settings")
    }
  }
  var symbol: String {
    switch self {
    case .quotas: "square.grid.2x2"
    case .statistics: "chart.xyaxis.line"
    case .settings: "slider.horizontal.3"
    }
  }
}

func presentationAccent(_ scheme: ColorScheme) -> Color {
  scheme == .dark
    ? Color(red: 0.51, green: 0.82, blue: 0.71)
    : Color(red: 0.09, green: 0.48, blue: 0.38)
}

struct DashboardView: View {
  @Bindable var model: AppModel
  var style: DashboardStyle = .menuBar
  var isHeld = false
  var toggleHold: (() -> Void)?
  var close: (() -> Void)?
  var openHistory: (() -> Void)?
  var openSettings: (() -> Void)?
  var captureWindow: ((NSWindow) -> Void)?
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State var tab = DashboardTab.quotas
  private var contentInset: CGFloat { style == .notch ? 22 : 20 }

  var body: some View {
    VStack(spacing: 0) {
      header
      HStack(spacing: 3) {
        ForEach(DashboardTab.allCases, id: \.self) { item in
          Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.14)) { tab = item }
          } label: {
            Label(item.title, systemImage: item.symbol)
              .font(.system(size: 11, weight: tab == item ? .medium : .regular))
              .frame(maxWidth: .infinity).padding(.vertical, 7)
              .contentShape(Rectangle())
          }.buttonStyle(DashboardTabButtonStyle(isSelected: tab == item))
            .accessibilityAddTraits(tab == item ? .isSelected : [])
        }
      }.padding(3).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, contentInset).padding(.bottom, 14)
      ScrollView {
        VStack(spacing: 10) {
          switch tab {
          case .quotas: quotas
          case .statistics: HistorySummaryView(model: model, openHistory: showHistory)
          case .settings:
            PresentationSettingsView(model: model, openSettings: showSettings)
          }
        }.padding(.horizontal, contentInset).padding(.bottom, 8)
      }.scrollIndicators(.hidden).frame(maxWidth: .infinity, maxHeight: .infinity)
      AppUpdateButton(updates: model.updates) {
        model.settingsPage = .updates
        showSettings()
      }
      .padding(.horizontal, contentInset)
      footer
    }
    .padding(.top, style == .notch ? 12 : 6)
    .padding(.bottom, style == .notch ? 12 : 6)
    .frame(width: style == .notch ? 430 : 414)
    .frame(
      height: style == .menuBar ? min(638, (NSScreen.main?.visibleFrame.height ?? 800) - 60) : nil
    )
    .tint(presentationAccent(scheme))
    .background {
      if let captureWindow {
        PanelWindowReader(onWindowAvailable: captureWindow).allowsHitTesting(false)
      }
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      AppIconView().frame(width: 25, height: 25).accessibilityHidden(true)
      Text(AppIdentity.name).font(.system(size: 13, weight: .semibold))
      if model.isDemo {
        Text("DEMO").font(.system(size: 8, weight: .medium)).padding(.horizontal, 4).padding(
          .vertical, 2
        )
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.3)))
        .foregroundStyle(.secondary)
      }
      Spacer()
      if style == .notch, let toggleHold {
        Button(action: toggleHold) {
          Image(systemName: isHeld ? "pin.fill" : "pin").frame(width: 24, height: 24)
            .background(
              isHeld ? presentationAccent(scheme).opacity(0.16) : .clear,
              in: RoundedRectangle(cornerRadius: 6))
        }.foregroundStyle(isHeld ? presentationAccent(scheme) : .secondary)
          .help(localized("Удерживать панель открытой", "Keep the panel open"))
          .accessibilityLabel(localized("Удерживать панель открытой", "Keep the panel open"))
          .accessibilityValue(isHeld ? localized("Включено", "On") : localized("Выключено", "Off"))
      }
      Menu {
        Button(localized("Обновить показания", "Refresh readings"), systemImage: "arrow.clockwise")
        {
          Task { await model.refresh() }
        }.disabled(model.isRefreshing || model.isDemo)
        Button(localized("Полная история…", "Full history…"), action: showHistory)
        Button(
          localized("Подключения и настройки…", "Connections and settings…"), action: showSettings)
        Divider()
        Button(localized("Завершить \(AppIdentity.name)", "Quit \(AppIdentity.name)")) {
          NSApp.terminate(nil)
        }
      } label: {
        Image(systemName: "ellipsis").frame(width: 22, height: 24)
      }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help(localized("Действия", "Actions"))
      Button {
        dismissPanel()
      } label: {
        Image(systemName: "xmark").frame(width: 22, height: 24)
      }
      .help(localized("Закрыть панель", "Close panel"))
      .accessibilityLabel(localized("Закрыть панель", "Close panel"))
    }.font(.system(size: 12)).buttonStyle(.plain)
      .padding(.horizontal, contentInset).frame(height: 49)
  }

  @ViewBuilder private var quotas: some View {
    if !model.onboardingComplete && !model.isDemo {
      VStack(alignment: .leading, spacing: 10) {
        Text(localized("Ваши квоты, одним взглядом", "Your allowances at a glance"))
          .font(.system(size: 13, weight: .semibold))
        Text(
          localized(
            "Подключите агенты и выберите окно для индикатора.",
            "Connect your agents and choose a window for the indicator.")
        )
        .font(.caption).foregroundStyle(.secondary)
        Toggle(localized("Запускать при входе", "Launch at login"), isOn: $model.wantsLoginItem)
          .toggleStyle(.switch).controlSize(.mini).font(.caption)
        Button(localized("Настроить подключения", "Set up connections")) {
          model.finishOnboarding()
          showSettings()
        }.buttonStyle(.borderedProminent).controlSize(.small)
      }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
    }
    if model.selection != nil && model.pinned == nil {
      Text(
        localized(
          "Выбранное окно временно недоступно. Ваш выбор сохранён.",
          "The selected window is unavailable. Your selection is preserved.")
      )
      .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
      .padding(10).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }
    ForEach(AgentID.allCases) { agent in
      let snapshot = model.snapshots.first { $0.agent == agent } ?? AgentSnapshot(agent: agent)
      AgentCard(
        snapshot: snapshot, selection: model.selection, now: model.displayDate,
        connectionMessage: agent == .claude
          ? model.claudeMessage : agent == .cursor ? model.cursorMessage : nil,
        connectionInProgress: agent == .claude
          ? model.claudeConnecting : agent == .cursor && model.cursorConnecting,
        connectionConfigured: agent == .claude && model.claudeConfigured
      ) { window in
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
          model.pin(agent: snapshot.agent, window: window)
        }
      } connect: {
        if agent == .claude {
          Task { await model.connectClaude() }
        } else {
          model.settingsPage = .agents
          model.settingsAgent = agent
          showSettings()
        }
      }
    }
    if let error = model.errorMessage {
      Text(error).font(.caption).foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var footer: some View {
    HStack(spacing: 5) {
      Circle().fill(footerIsFresh ? presentationAccent(scheme) : .secondary).frame(
        width: 5, height: 5)
      Text(footerLabel).lineLimit(1)
      Spacer(minLength: 6)
      Text(AppIdentity.versionLabel).monospacedDigit().help(AppIdentity.versionDescription)
        .accessibilityLabel(AppIdentity.versionDescription)
    }.font(.system(size: 9)).foregroundStyle(.secondary).padding(.horizontal, contentInset).frame(
      height: 33)
  }
  private var footerIsFresh: Bool {
    model.snapshots.contains { $0.isFresh(at: model.displayDate) }
      && !model.snapshots.contains { snapshot in
        !snapshot.windows.isEmpty
          && snapshot.windows.contains {
            !snapshot.windowIsFresh($0, at: model.displayDate)
          }
      }
  }
  private var footerLabel: String {
    if model.isDemo { return localized("Демонстрационные показания", "Demonstration readings") }
    if model.isRefreshing { return localized("Обновление…", "Refreshing…") }
    guard let latest = model.snapshots.compactMap(\.observedAt).max() else {
      return localized("Ожидаем показания", "Waiting for readings")
    }
    return
      (footerIsFresh
      ? localized("Обновлено · ", "Updated · ")
      : localized("Последние данные · ", "Last readings · "))
      + latest.formatted(date: .omitted, time: .shortened)
  }
  private func showHistory() {
    dismissPanel()
    if let openHistory {
      openHistory()
    } else {
      openWindow(id: "history")
      NSApp.activate(ignoringOtherApps: true)
    }
  }
  private func showSettings() {
    dismissPanel()
    if let openSettings {
      openSettings()
    } else {
      openWindow(id: "settings")
      NSApp.activate(ignoringOtherApps: true)
    }
  }
  private func dismissPanel() {
    if let close { close() } else { dismiss() }
  }
}

private struct PanelWindowReader: NSViewRepresentable {
  let onWindowAvailable: (NSWindow) -> Void

  func makeNSView(context: Context) -> PanelWindowReaderView {
    let view = PanelWindowReaderView()
    view.onWindowAvailable = onWindowAvailable
    return view
  }

  func updateNSView(_ nsView: PanelWindowReaderView, context: Context) {
    nsView.onWindowAvailable = onWindowAvailable
    if let window = nsView.window { onWindowAvailable(window) }
  }
}

private final class PanelWindowReaderView: NSView {
  var onWindowAvailable: ((NSWindow) -> Void)?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let window { onWindowAvailable?(window) }
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct DashboardTabButtonStyle: ButtonStyle {
  var isSelected: Bool
  var usesAccent = false
  @State private var isHovered = false
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(
        isSelected && usesAccent
          ? presentationAccent(scheme) : isSelected || isHovered ? Color.primary : Color.secondary
      )
      .background(
        (isSelected && usesAccent ? presentationAccent(scheme) : Color.primary).opacity(
          configuration.isPressed
            ? (usesAccent ? 0.23 : 0.15)
            : isHovered ? (usesAccent ? 0.15 : 0.11) : isSelected ? (usesAccent ? 0.12 : 0.07) : 0),
        in: RoundedRectangle(cornerRadius: 6)
      )
      .contentShape(Rectangle())
      .onHover { isHovered = $0 }
      .onContinuousHover { phase in
        switch phase {
        case .active: NSCursor.pointingHand.set()
        case .ended: NSCursor.arrow.set()
        }
      }
      .onDisappear { if isHovered { NSCursor.arrow.set() } }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
  }
}

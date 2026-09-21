import AllowanceCore
import SwiftUI

struct AgentCard: View {
  let snapshot: AgentSnapshot
  let selection: WindowSelection?
  let now: Date
  var connectionMessage: String? = nil
  var connectionInProgress = false
  var connectionConfigured = false
  let pin: (AllowanceWindow) -> Void
  let connect: () -> Void
  @Environment(\.colorScheme) private var scheme
  @State private var expanded = false

  private var selectedAgent: Bool { selection?.agent == snapshot.agent }
  private var accent: Color { presentationAccent(scheme) }
  private var state: SourceState {
    snapshot.state == .ready
      && (!snapshot.isFresh(at: now)
        || snapshot.windows.contains { !snapshot.windowIsFresh($0, at: now) })
      ? .stale : snapshot.state
  }
  private var needsConnection: Bool { state == .needsSetup || state == .signedOut }
  private var cardColor: Color {
    selectedAgent
      ? accent.opacity(scheme == .dark ? 0.12 : 0.045)
      : (scheme == .dark ? Color(red: 0.115, green: 0.133, blue: 0.157) : .white.opacity(0.7))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 9) {
        AgentIcon(agent: snapshot.agent, size: 16)
          .foregroundStyle(
            snapshot.agent == .claude ? Color(red: 0.73, green: 0.52, blue: 0.4) : .primary
          )
          .frame(width: 29, height: 29)
          .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 3) {
          Text(snapshot.agent.title).font(.system(size: 12, weight: .semibold))
          Text(
            snapshot.plan
              ?? (needsConnection
                ? localized("Требуется подключение", "Connection required")
                : localized("План не указан источником", "Plan not provided"))
          )
          .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        Spacer(minLength: 6)
        VStack(alignment: .trailing, spacing: 3) {
          if selectedAgent {
            Label(localized("Выбран", "Selected"), systemImage: "checkmark")
              .font(.system(size: 9, weight: .medium)).foregroundStyle(accent)
          }
          if state != .ready {
            Text(state.label).font(.system(size: 9)).foregroundStyle(.secondary)
          }
        }
      }.padding(.bottom, 8)
      if snapshot.windows.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text(connectionMessage ?? emptyDescription).font(.system(size: 11)).foregroundStyle(
            .secondary
          )
          .fixedSize(horizontal: false, vertical: true)
          if needsConnection {
            Button(
              connectionInProgress
                ? localized("Подключение…", "Connecting…")
                : connectionConfigured
                  ? localized("Настроено · ждём данные", "Configured · awaiting data")
                  : localized("Подключить", "Connect"), action: connect
            )
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(connectionInProgress || connectionConfigured)
          }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 11)
          .overlay(alignment: .top) { Divider().opacity(0.55) }
      } else {
        ForEach(snapshot.windows) { window in windowRow(window) }
      }
      DisclosureGroup(isExpanded: $expanded) {
        subscriptionDetails.padding(.top, 6).padding(.bottom, 9)
      } label: {
        Text(localized("Подписка и источник", "Subscription and source"))
          .font(.system(size: 10)).foregroundStyle(.secondary)
      }.disclosureGroupStyle(FullRowDisclosureStyle())
        .padding(.top, 2).padding(.bottom, 2)
        .overlay(alignment: .top) { Divider().opacity(0.55) }
    }.padding(.horizontal, 12).padding(.top, 10)
      .background(cardColor, in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12).strokeBorder(
          selectedAgent ? accent.opacity(0.85) : .primary.opacity(0.11),
          lineWidth: selectedAgent ? 1.2 : 1)
      )
      .accessibilityElement(children: .contain)
      .accessibilityLabel(
        snapshot.agent.title
          + (selectedAgent
            ? localized(", выбран для индикатора", ", selected for the indicator") : ""))
  }

  private func windowRow(_ window: AllowanceWindow) -> some View {
    let chosen = selection == WindowSelection(agent: snapshot.agent, windowID: window.id)
    let fresh = snapshot.windowIsFresh(window, at: now)
    return Button {
      pin(window)
    } label: {
      HStack(spacing: 8) {
        ZStack {
          Circle().stroke(chosen ? accent : .secondary.opacity(0.6), lineWidth: 1.1)
          if chosen { Circle().fill(accent).padding(3) }
        }.frame(width: 13, height: 13).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 5) {
            Text(window.title).font(.system(size: 11, weight: .medium)).lineLimit(2)
            if chosen {
              Text(localized("В индикаторе", "In indicator"))
                .font(.system(size: 8)).foregroundStyle(accent).fixedSize()
            }
          }
          Text(
            fresh
              ? resetLabel(window.resetsAt)
              : localized("Последнее известное значение", "Last known reading")
          )
          .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: .leading)
        VStack(alignment: .trailing, spacing: 5) {
          Text(remainingPercentLabel(window.remainingPercent, compact: true))
            .font(.system(size: 14, weight: .semibold)).monospacedDigit()
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule().fill(.primary.opacity(0.1))
              if let percent = window.remainingPercent {
                Capsule().fill(chosen ? accent : .secondary.opacity(0.65))
                  .frame(width: geometry.size.width * percent / 100)
              }
            }
          }.frame(width: 70, height: 3).opacity(fresh ? 1 : 0.5)
        }.frame(width: 72, alignment: .trailing)
      }.padding(.vertical, 6).contentShape(Rectangle())
    }.buttonStyle(.plain)
      .overlay(alignment: .top) { Divider().opacity(0.55) }
      .accessibilityLabel(
        localized("Показывать в индикаторе: ", "Show in indicator: ")
          + snapshot.agent.title + ", " + window.title
      )
      .accessibilityValue(
        remainingPercentLabel(window.remainingPercent, compact: false)
          + (chosen ? localized(", выбрано", ", selected") : "")
          + (fresh ? "" : localized(", устарело", ", stale"))
      )
      .accessibilityAddTraits(chosen ? .isSelected : [])
      .help(
        localized(
          "Выбрать это окно для обоих режимов отображения",
          "Select this window for both presentation modes"))
  }

  private var subscriptionDetails: some View {
    VStack(alignment: .leading, spacing: 7) {
      detail(
        localized("Аккаунт", "Account"),
        snapshot.accountLabel ?? localized("Не указан источником", "Not provided"))
      detail(
        localized("Источник", "Source"),
        snapshot.source.isEmpty ? localized("Не подключён", "Not connected") : snapshot.source)
      if let date = snapshot.observedAt {
        detail(
          localized("Наблюдение", "Observed"), date.formatted(date: .abbreviated, time: .shortened))
      }
      if let info = snapshot.subscription {
        if let date = info.billingCycleStart {
          detail(
            localized("Начало оплаты", "Billing start"),
            date.formatted(date: .abbreviated, time: .omitted))
        }
        if let date = info.billingCycleEnd {
          detail(
            localized("Конец оплаты", "Billing end"),
            date.formatted(date: .abbreviated, time: .omitted))
        }
        if let used = info.planUsedUSD {
          detail(localized("Расход плана", "Plan usage"), used.formatted(.currency(code: "USD")))
        }
        if let limit = info.planLimitUSD {
          detail(localized("Лимит плана", "Plan limit"), limit.formatted(.currency(code: "USD")))
        }
        if let used = info.onDemandUsedUSD {
          detail(
            localized("Доп. расход", "On-demand usage"), used.formatted(.currency(code: "USD")))
        }
        if let limit = info.onDemandLimitUSD {
          detail(
            localized("Лимит доп. расхода", "On-demand limit"),
            limit.formatted(.currency(code: "USD")))
        }
        if let balance = info.creditBalance { detail("Credits", balance) }
        if info.isUnlimited == true {
          Text(localized("Источник сообщает безлимит", "Source reports unlimited usage"))
            .foregroundStyle(.secondary)
        }
      }
      if snapshot.subscription?.billingCycleEnd == nil {
        detail(
          localized("Оплата", "Billing"),
          localized("Дата не получена от источника", "Date not provided"))
      }
      ForEach(snapshot.windows) { window in
        Divider().opacity(0.5)
        detail(window.title, remainingPercentLabel(window.remainingPercent, compact: false))
        detail(
          localized("Сброс", "Reset"),
          window.resetsAt?.formatted(date: .abbreviated, time: .shortened)
            ?? localized("Время неизвестно", "Time unavailable"))
      }
    }.font(.system(size: 10)).textSelection(.enabled)
  }

  private func detail(_ title: String, _ value: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text(title).foregroundStyle(.secondary).frame(width: 103, alignment: .leading)
      Text(value).frame(maxWidth: .infinity, alignment: .leading).fixedSize(
        horizontal: false, vertical: true)
    }
  }
  private var emptyDescription: String {
    if snapshot.subscription?.isUnlimited == true {
      return localized(
        "Источник сообщает безлимит. Процент остатка неприменим.",
        "Source reports unlimited usage. A remaining percentage does not apply.")
    }
    switch state {
    case .unsupported:
      return localized(
        "Источник не предоставил числовую квоту.", "The source did not provide a numeric allowance."
      )
    case .unavailable, .stale:
      return localized(
        "Источник временно недоступен. Попробуйте обновить показания.",
        "The source is unavailable. Try refreshing readings.")
    case .ready:
      return localized(
        "Источник не вернул доступных окон квоты.", "The source returned no allowance windows.")
    case .needsSetup, .signedOut:
      switch snapshot.agent {
      case .codex:
        return localized(
          "Используется существующий вход в Codex CLI.", "Uses your existing Codex CLI sign-in.")
      case .claude:
        return localized(
          "Подключите statusLine Claude Code. Показания появятся после ответа агента.",
          "Connect Claude Code statusLine. Readings arrive after an agent response.")
      case .cursor:
        return localized(
          "Подключите аккаунт установленного Cursor в настройках.",
          "Connect your installed Cursor account in Settings.")
      }
    }
  }
}

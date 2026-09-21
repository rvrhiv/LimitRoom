import AllowanceCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
  @Bindable var model: AppModel
  @State private var confirmingClear = false
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text(localized("Квоты и активность", "Allowances & activity")).font(
            .system(size: 25, weight: .semibold, design: .rounded))
          Text(
            localized(
              "Остаток подписок и реальные счётчики — отдельно",
              "Subscription headroom and reported token counts, kept separate")
          )
          .font(.callout).foregroundStyle(.secondary)
        }
        Spacer()
        if model.isDemo { Text("DEMO").font(.caption.bold()).foregroundStyle(.orange) }
        StatisticsPeriodPicker(model: model)
      }
      ScrollView {
        StatisticsContentView(model: model).padding(.bottom, 8)
      }
      Divider()
      if model.statisticsMode == .quota {
        HStack {
          Text(
            localized("\(model.samples.count) наблюдений", "\(model.samples.count) observations")
          )
          .font(
            .caption
          ).foregroundStyle(.secondary)
          Spacer()
          Menu(localized("Экспорт квот", "Export quotas")) {
            Button("JSON") { save(csv: false) }
            Button("CSV") { save(csv: true) }
          }.disabled(model.isDemo || model.samples.isEmpty)
          Button(localized("Удалить историю квот…", "Clear quota history…"), role: .destructive) {
            confirmingClear = true
          }
          .disabled(model.isDemo || model.samples.isEmpty)
        }
      } else {
        Text(
          localized(
            "Источник: Codex App Server · без сохранения токенов на диск",
            "Source: Codex App Server · token counts are not stored on disk")
        )
        .font(.caption).foregroundStyle(.secondary)
      }
    }.padding(28)
      .alert(
        localized("Удалить локальную историю квот?", "Clear local quota history?"),
        isPresented: $confirmingClear
      ) {
        Button(localized("Удалить", "Clear"), role: .destructive) {
          Task { await model.clearHistory() }
        }
        Button(localized("Отмена", "Cancel"), role: .cancel) {}
      } message: {
        Text(
          localized(
            "Будут удалены только локальные измерения. Подписки и авторизации останутся подключёнными.",
            "Only local observations will be deleted. Your subscriptions and sign-ins stay connected."
          ))
      }
  }
  private func save(csv: Bool) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = csv ? "LimitRoom-history.csv" : "LimitRoom-history.json"
    panel.allowedContentTypes = csv ? [.commaSeparatedText] : [.json]
    panel.begin { response in
      guard response == .OK, let url = panel.url else { return }
      Task { @MainActor in await model.export(to: url, csv: csv) }
    }
  }
}

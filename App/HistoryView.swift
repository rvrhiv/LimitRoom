import AllowanceCore
import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
  @Bindable var model: AppModel
  @State private var confirmingClear = false
  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text(localized("Ритм работы", "Your working rhythm")).font(
            .system(size: 25, weight: .semibold, design: .rounded))
          Text(
            localized(
              "Как быстро расходуются выбранные окна подписок",
              "How quickly your selected allowances are being used")
          )
          .font(.callout).foregroundStyle(.secondary)
        }
        Spacer()
        if model.isDemo { Text("DEMO").font(.caption.bold()).foregroundStyle(.orange) }
        Picker(localized("Период", "Period"), selection: $model.historyDays) {
          Text(localized("24 часа", "24 hours")).tag(1)
          Text(localized("7 дней", "7 days")).tag(7)
          Text(localized("30 дней", "30 days")).tag(30)
          Text(localized("90 дней", "90 days")).tag(90)
        }.frame(width: 130)
      }
      HStack(spacing: 20) {
        ForEach(model.snapshots) { snapshot in
          VStack(alignment: .leading, spacing: 6) {
            Label {
              Text(snapshot.agent.title)
            } icon: {
              AgentIcon(agent: snapshot.agent, size: 14)
            }.font(
              .caption.weight(.semibold))
            Picker(
              snapshot.agent.title,
              selection: Binding(
                get: { model.chartSelections[snapshot.agent] ?? "" },
                set: { model.setChartWindow($0, agent: snapshot.agent) }
              )
            ) {
              if snapshot.windows.isEmpty { Text("—").tag("") }
              ForEach(snapshot.windows) { Text($0.title).tag($0.id) }
            }.labelsHidden().disabled(snapshot.windows.isEmpty)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      if model.rates.isEmpty {
        ContentUnavailableView {
          Label(
            localized("Ждём первые измерения", "Waiting for comparable readings"),
            systemImage: "chart.xyaxis.line")
        } description: {
          Text(
            localized(
              "График появится, когда накопятся последовательные показания одного окна. Сбросы и пробелы в данных не считаются расходом.",
              "The chart appears after successive readings of the same window. Resets and missing observations are not counted as consumption."
            ))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Chart(model.rates) { rate in
          LineMark(
            x: .value(localized("Время", "Time"), rate.date),
            y: .value(localized("п.п. / сутки", "pp / day"), rate.pointsPerDay),
            series: .value("segment", rate.segment)
          )
          .foregroundStyle(by: .value(localized("Агент", "Agent"), rate.agent.title))
          .interpolationMethod(.linear)
        }
        .chartForegroundStyleScale(
          domain: AgentID.allCases.map(\.title), range: [Color.primary, Color.orange, Color.teal]
        )
        .chartYAxisLabel(
          localized("Процентных пунктов окна / сутки", "Percentage points of window / day")
        )
        .chartLegend(position: .bottom, spacing: 16)
        .frame(minHeight: 220)
      }
      Text(
        localized(
          "Сравнивается доля выбранной квоты, а не стоимость или число запросов. Разные подписки имеют разный объём. История — только на этом Mac, 90 дней.",
          "This compares fractions of selected allowances, not cost or request counts. Plans have different capacities. History stays on this Mac for 90 days."
        )
      )
      .font(.caption).foregroundStyle(.secondary)
      Divider()
      HStack {
        Text(localized("\(model.samples.count) наблюдений", "\(model.samples.count) observations"))
          .font(
            .caption
          ).foregroundStyle(.secondary)
        Spacer()
        Menu(localized("Экспорт", "Export")) {
          Button("JSON") { save(csv: false) }
          Button("CSV") { save(csv: true) }
        }.disabled(model.isDemo || model.samples.isEmpty)
        Button(localized("Удалить историю…", "Clear history…"), role: .destructive) {
          confirmingClear = true
        }
        .disabled(model.isDemo || model.samples.isEmpty)
      }
    }.padding(28)
      .alert(
        localized("Удалить всю историю LimitRoom?", "Clear all LimitRoom history?"),
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

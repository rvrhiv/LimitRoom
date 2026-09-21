import AllowanceCore
import Charts
import SwiftUI

struct HistorySummaryView: View {
  @Bindable var model: AppModel
  let openHistory: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(localized("Темп расхода", "Consumption trend")).font(
          .system(size: 13, weight: .semibold))
        Spacer()
        Picker(localized("Период", "Period"), selection: $model.historyDays) {
          Text(localized("24 часа", "24 hours")).tag(1)
          Text(localized("7 дней", "7 days")).tag(7)
          Text(localized("30 дней", "30 days")).tag(30)
          Text(localized("90 дней", "90 days")).tag(90)
        }.labelsHidden().frame(width: 110).controlSize(.small)
      }
      if model.rates.isEmpty {
        VStack(spacing: 10) {
          Image(systemName: "chart.xyaxis.line").font(.system(size: 28)).foregroundStyle(.secondary)
          Text(localized("Ждём последовательные измерения", "Waiting for comparable readings"))
            .font(.system(size: 12, weight: .medium))
          Text(
            localized(
              "График появится после нескольких показаний одного окна. Сбросы и пробелы не считаются расходом.",
              "The chart appears after successive readings of one window. Resets and gaps do not count as consumption."
            )
          )
          .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(24)
          .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 11))
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
          domain: AgentID.allCases.map(\.title),
          range: [Color.mint, Color.orange, Color.blue]
        )
        .chartLegend(position: .bottom, alignment: .leading)
        .chartYAxisLabel(localized("п.п. / сутки", "pp / day"))
        .frame(height: 183).padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 11))
      }
      ForEach(AgentID.allCases) { agent in
        let windows = model.snapshots.first { $0.agent == agent }?.windows ?? []
        HStack {
          AgentIcon(agent: agent, size: 14).frame(width: 17).foregroundStyle(.secondary)
          Text(agent.title).font(.system(size: 11, weight: .medium))
          Spacer()
          Picker(
            agent.title,
            selection: Binding(
              get: { model.chartSelections[agent] ?? "" },
              set: { model.setChartWindow($0, agent: agent) })
          ) {
            if windows.isEmpty { Text("—").tag("") }
            ForEach(windows) { Text($0.title).tag($0.id) }
          }.labelsHidden().frame(width: 160).controlSize(.small).disabled(windows.isEmpty)
        }
      }
      Text(
        localized(
          "Сравнивается изменение доли квоты, а не стоимость или число токенов. Окно графика выбирается независимо от индикатора.",
          "Compares changes in allowance fractions, not cost or token counts. Chart windows are independent of the indicator."
        )
      )
      .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(
        horizontal: false, vertical: true)
      Button(localized("Открыть полную историю…", "Open full history…"), action: openHistory)
        .buttonStyle(.bordered).controlSize(.small)
    }.padding(.vertical, 3)
  }
}

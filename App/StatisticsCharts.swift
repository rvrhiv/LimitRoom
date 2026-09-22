import AllowanceCore
import Charts
import SwiftUI

/// Cached presentation projection; full observations remain available for hover.
struct QuotaChartData {
  struct Bridge: Identifiable {
    let previous: QuotaHistoryPoint
    let next: QuotaHistoryPoint
    var id: String { "bridge/\(previous.id)/\(next.id)" }
  }
  let displayPoints: [QuotaHistoryPoint]
  let agentPoints: [AgentID: [QuotaHistoryPoint]]
  let bridges: [Bridge]

  init(points: [QuotaHistoryPoint], compact: Bool) {
    displayPoints = TrendCalculator.chartPoints(from: points, maximumBuckets: compact ? 32 : 72)
    agentPoints = Dictionary(grouping: points, by: { $0.sample.agent })
    bridges = agentPoints.values.flatMap { series in
      zip(series, series.dropFirst()).compactMap { previous, next -> Bridge? in
        guard next.transition != nil,
          previous.sample.accountScope == next.sample.accountScope,
          previous.sample.windowID == next.sample.windowID,
          previous.sample.plan == next.sample.plan,
          previous.sample.observedAt < next.sample.observedAt
        else { return nil }
        return Bridge(previous: previous, next: next)
      }
    }
  }

  func latest(_ agent: AgentID, in range: ClosedRange<Date>) -> QuotaHistoryPoint? {
    let series = agentPoints[agent] ?? []
    var low = 0
    var high = series.count
    while low < high {
      let middle = (low + high) / 2
      if series[middle].sample.observedAt <= range.upperBound {
        low = middle + 1
      } else {
        high = middle
      }
    }
    guard low > 0, range.contains(series[low - 1].sample.observedAt) else { return nil }
    return series[low - 1]
  }
}

enum StatisticsMode: String, CaseIterable {
  case quota, tokens
  var title: String {
    switch self {
    case .quota: localized("Остаток квоты", "Quota remaining")
    case .tokens: localized("Токены", "Tokens")
    }
  }
}

struct StatisticsPeriodPicker: View {
  @Bindable var model: AppModel
  var body: some View {
    Picker(localized("Период", "Period"), selection: $model.historyDays) {
      Text(
        model.statisticsMode == .quota
          ? localized("24 часа", "24 hours") : localized("Последний день", "Latest day")
      ).tag(1)
      Text(localized("3 дня", "3 days")).tag(3)
      Text(localized("7 дней", "7 days")).tag(7)
      Text(localized("30 дней", "30 days")).tag(30)
      Text(localized("90 дней", "90 days")).tag(90)
    }.labelsHidden().frame(width: 130).controlSize(.small)
  }
}

struct StatisticsContentView: View {
  @Bindable var model: AppModel
  var compact = false

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 10 : 14) {
      Picker(localized("Показатель", "Metric"), selection: $model.statisticsMode) {
        ForEach(StatisticsMode.allCases, id: \.self) { Text($0.title).tag($0) }
      }.pickerStyle(.segmented).labelsHidden()
      switch model.statisticsMode {
      case .quota:
        let data = model.quotaChartData(compact: compact)
        QuotaHistoryChart(
          data: data, range: model.historyRange, maximumGap: model.historyMaximumGap,
          compact: compact)
        ForEach(AgentID.allCases) { agent in
          quotaRow(agent, last: data.latest(agent, in: model.historyRange))
        }
        Text(
          localized(
            "Сглаженный остаток квоты, 0–100%. Пунктир — пауза, изменение показаний или неизвестный цикл; ромб — первое показание после сброса. Точные измерения — при наведении. Окна графика не меняют индикатор.",
            "Smoothed quota remaining, 0–100%. Dashed lines bridge pauses, adjustments or an unknown cycle; a diamond marks the first reading after a reset. Hover for exact observations. Chart windows do not change your indicator."
          )
        ).font(.system(size: compact ? 10 : 12)).foregroundStyle(.secondary)
      case .tokens:
        TokenHistoryChart(
          histories: model.tokenHistories, dayCount: model.historyDays,
          now: model.displayDate, maximumAge: max(600, model.quotaRefreshInterval.duration * 1.5),
          compact: compact)
      }
    }
  }

  private func quotaRow(_ agent: AgentID, last: QuotaHistoryPoint?) -> some View {
    let windows = model.snapshots.first { $0.agent == agent }?.windows ?? []
    let selectedID = model.chartSelections[agent] ?? ""
    return HStack(spacing: 10) {
      AgentIcon(agent: agent, size: 16).foregroundStyle(statisticsColor(agent))
      VStack(alignment: .leading, spacing: 3) {
        Text(agent.title).font(.system(size: 12, weight: .semibold))
        if let last {
          Text(last.sample.observedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
            .font(.system(size: 10)).foregroundStyle(.secondary)
        } else {
          Text(localized("Нет измерений", "No readings")).font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 4)
      Picker(
        localized("Окно графика: ", "Chart window: ") + agent.title,
        selection: Binding(
          get: { selectedID }, set: { model.setChartWindow($0, agent: agent) })
      ) {
        if !windows.contains(where: { $0.id == selectedID }) {
          Text(localized("Недоступно", "Unavailable")).tag(selectedID)
        }
        ForEach(windows) { Text($0.title).tag($0.id) }
      }.labelsHidden().frame(width: compact ? 120 : 190).controlSize(.small)
        .disabled(windows.isEmpty)
      Text(last.map { percentLabel($0.remainingPercent) } ?? "—")
        .font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
        .frame(width: 46, alignment: .trailing)
        .accessibilityLabel(localized("Последний остаток", "Last observed remaining quota"))
    }
    .padding(compact ? 7 : 11)
    .background(statisticsColor(agent).opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
  }
}

private struct QuotaHistoryChart: View {
  let data: QuotaChartData
  let range: ClosedRange<Date>
  let maximumGap: TimeInterval
  let compact: Bool
  @State private var hoveredDate: Date?

  private var hoveredPoints: [QuotaHistoryPoint] {
    guard let hoveredDate else { return [] }
    // Snap to real observations only, and never reach across a wide visual gap.
    let tolerance = min(range.upperBound.timeIntervalSince(range.lowerBound) / 80, maximumGap / 2)
    return AgentID.allCases.compactMap { agent in
      let series = data.agentPoints[agent] ?? []
      var low = 0
      var high = series.count
      while low < high {
        let middle = (low + high) / 2
        if series[middle].sample.observedAt < hoveredDate {
          low = middle + 1
        } else {
          high = middle
        }
      }
      let nearest = [low - 1, low].filter {
        series.indices.contains($0) && range.contains(series[$0].sample.observedAt)
      }.map { series[$0] }.min {
        abs($0.sample.observedAt.timeIntervalSince(hoveredDate))
          < abs($1.sample.observedAt.timeIntervalSince(hoveredDate))
      }
      return nearest.flatMap {
        range.contains($0.sample.observedAt)
          && abs($0.sample.observedAt.timeIntervalSince(hoveredDate)) <= tolerance ? $0 : nil
      }
    }
  }

  var body: some View {
    let visiblePoints = data.displayPoints.filter { range.contains($0.sample.observedAt) }
    let segments = Dictionary(grouping: visiblePoints, by: \.segment)
    let markedPointIDs = Set(
      segments.values.flatMap { series in
        [series.first?.id, series.last?.id].compactMap { $0 }
      })
    VStack(alignment: .leading, spacing: 10) {
      Chart {
        ForEach(visiblePoints) { point in
          LineMark(
            x: .value(localized("Время", "Time"), point.sample.observedAt),
            y: .value(localized("Осталось", "Remaining"), point.remainingPercent),
            series: .value("segment", point.segment)
          ).foregroundStyle(by: .value(localized("Агент", "Agent"), point.sample.agent.title))
            .lineStyle(
              StrokeStyle(
                lineWidth: 2.3, lineCap: .round, lineJoin: .round,
                dash: point.sample.cycleKey == nil ? [4, 4] : [])
            )
            .interpolationMethod(.monotone)
          if point.beginsNewCycle || markedPointIDs.contains(point.id) {
            PointMark(
              x: .value(localized("Время", "Time"), point.sample.observedAt),
              y: .value(localized("Осталось", "Remaining"), point.remainingPercent)
            ).foregroundStyle(by: .value(localized("Агент", "Agent"), point.sample.agent.title))
              .symbol(point.beginsNewCycle ? .diamond : .circle)
              .symbolSize(point.beginsNewCycle ? 65 : 8)
              .accessibilityLabel(point.sample.agent.title + " · " + point.sample.windowTitle)
              .accessibilityValue(
                percentLabel(point.remainingPercent) + " · "
                  + point.sample.observedAt.formatted(date: .abbreviated, time: .shortened)
                  + (point.beginsNewCycle ? localized(" · Новый цикл", " · New cycle") : ""))
          }
        }
        ForEach(data.bridges) { bridge in
          if range.contains(bridge.previous.sample.observedAt),
            range.contains(bridge.next.sample.observedAt)
          {
            ForEach([bridge.previous, bridge.next]) { point in
              LineMark(
                x: .value(localized("Время", "Time"), point.sample.observedAt),
                y: .value(localized("Осталось", "Remaining"), point.remainingPercent),
                series: .value("segment", bridge.id)
              ).foregroundStyle(by: .value(localized("Агент", "Agent"), point.sample.agent.title))
                .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 4]))
                .interpolationMethod(.linear)
                .accessibilityHidden(true)
            }
          }
        }
        ForEach(hoveredPoints) { point in
          PointMark(
            x: .value(localized("Время", "Time"), point.sample.observedAt),
            y: .value(localized("Осталось", "Remaining"), point.remainingPercent)
          ).foregroundStyle(statisticsColor(point.sample.agent)).symbolSize(40)
        }
        if let date = hoveredPoints.first?.sample.observedAt {
          RuleMark(x: .value(localized("Время", "Time"), date))
            .foregroundStyle(.secondary.opacity(0.45)).lineStyle(StrokeStyle(dash: [3, 3]))
        }
      }
      .chartXScale(domain: range)
      .chartYScale(domain: 0...100)
      .chartYAxis {
        AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
          AxisGridLine()
          AxisValueLabel { if let number = value.as(Int.self) { Text("\(number)%") } }
        }
      }
      .chartXAxis {
        AxisMarks(
          values: range.upperBound.timeIntervalSince(range.lowerBound) <= 86400
            ? .automatic(desiredCount: compact ? 3 : 6)
            : .stride(
              by: .day,
              count: max(
                1,
                Int(
                  ceil(
                    range.upperBound.timeIntervalSince(range.lowerBound) / 86400
                      / Double(compact ? 3 : 6)))))
        ) { value in
          AxisGridLine()
          AxisValueLabel(anchor: axisLabelAnchor(value)) {
            if let date = value.as(Date.self) {
              if range.upperBound.timeIntervalSince(range.lowerBound) <= 86400 {
                Text(date, format: .dateTime.hour().minute())
              } else {
                Text(date, format: .dateTime.month(.abbreviated).day())
              }
            }
          }
        }
      }
      .chartForegroundStyleScale(
        domain: AgentID.allCases.map(\.title), range: AgentID.allCases.map(statisticsColor)
      )
      .chartLegend(.hidden)
      .chartOverlay { proxy in
        GeometryReader { geometry in
          Color.clear.contentShape(Rectangle()).onContinuousHover { phase in
            switch phase {
            case .active(let location):
              guard let plot = proxy.plotFrame else { return }
              let frame = geometry[plot]
              hoveredDate =
                frame.contains(location)
                ? proxy.value(atX: location.x - frame.minX, as: Date.self) : nil
            case .ended: hoveredDate = nil
            }
          }
        }
      }
      .frame(height: compact ? 150 : 220)
      .overlay {
        if !AgentID.allCases.contains(where: { data.latest($0, in: range) != nil }) {
          Text(localized("Здесь появятся измерения квоты", "Quota readings will appear here"))
            .font(.callout).foregroundStyle(.secondary).padding(12).background(.regularMaterial)
        }
      }
      .overlay(alignment: .topLeading) {
        if hoveredDate != nil {
          VStack(alignment: .leading, spacing: 5) {
            if hoveredPoints.isEmpty {
              Text(localized("Рядом нет измерений", "No readings near this time"))
                .foregroundStyle(.secondary)
            } else {
              ForEach(hoveredPoints) { point in
                Text(
                  "\(point.sample.agent.title) · \(point.sample.windowTitle) · \(percentLabel(point.remainingPercent)) · "
                    + point.sample.observedAt.formatted(date: .abbreviated, time: .shortened)
                ).foregroundStyle(statisticsColor(point.sample.agent))
              }
            }
          }.font(.caption).padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .allowsHitTesting(false)
        }
      }
    }.padding(12)
      .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 11))
  }
}

func statisticsColor(_ agent: AgentID) -> Color {
  switch agent {
  case .codex: .mint
  case .claude: .orange
  case .cursor: .blue
  }
}

private func percentLabel(_ value: Double) -> String {
  value.formatted(.number.precision(.fractionLength(0...1))) + "%"
}

func axisLabelAnchor(_ value: AxisValue) -> UnitPoint {
  if value.index == 0 { return .topLeading }
  if value.index == value.count - 1 { return .topTrailing }
  return .top
}

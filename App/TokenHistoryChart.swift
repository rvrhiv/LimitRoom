import AllowanceCore
import Charts
import SwiftUI

struct AgentTokenHistory: Identifiable {
  var id: AgentID { agent }
  let agent: AgentID
  let usage: TokenUsage?
}

/// Providers share one calendar axis, not independent "latest day" offsets.
/// Only explicitly reported daily counts become points; a missing day is not zero.
private struct TokenChartData {
  struct Point: Identifiable {
    var id: String { "\(agent.rawValue)/\(day.day)" }
    let agent: AgentID
    let day: TokenDay
    let date: Date
    let segment: Int
  }
  struct Bridge: Identifiable {
    var id: String { "bridge/\(previous.id)/\(next.id)" }
    let previous: Point
    let next: Point
  }
  let points: [Point]
  let bridges: [Bridge]
  let dates: [Date]

  init(histories: [AgentTokenHistory], dayCount: Int, now: Date) {
    let formatter = Self.dayFormatter
    let latest = histories.compactMap { history -> String? in
      guard history.usage?.state == .ready else { return nil }
      return history.usage?.days?.map(\.day).max()
    }.max()
    let end =
      latest.flatMap { formatter.date(from: $0) }
      ?? formatter.date(from: formatter.string(from: now))!
    let count = max(1, min(90, dayCount))
    dates = (0..<count).map { end.addingTimeInterval(Double($0 - count + 1) * 86400) }
    let start = dates[0]
    var readings: [Point] = []
    var connections: [Bridge] = []
    for history in histories where history.usage?.state == .ready {
      var previous: Point?
      var segment = 0
      for day in (history.usage?.days ?? []).sorted(by: { $0.day < $1.day }) {
        guard day.tokens >= 0, let date = formatter.date(from: day.day),
          formatter.string(from: date) == day.day, date >= start, date <= end
        else { continue }
        let missingDays = previous.map { date.timeIntervalSince($0.date) > 86400 } ?? false
        if missingDays { segment += 1 }
        let point = Point(agent: history.agent, day: day, date: date, segment: segment)
        if missingDays, let previous {
          connections.append(Bridge(previous: previous, next: point))
        }
        readings.append(point)
        previous = point
      }
    }
    points = readings
    bridges = connections
  }

  static var dayFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    return formatter
  }
  static func dayLabel(_ date: Date) -> String {
    let formatter = dayFormatter
    formatter.locale = .current
    formatter.setLocalizedDateFormatFromTemplate("d MMM")
    return formatter.string(from: date)
  }
}

struct TokenHistoryChart: View {
  let histories: [AgentTokenHistory]
  let dayCount: Int
  let now: Date
  let maximumAge: TimeInterval
  let compact: Bool
  @State private var hoveredDate: Date?

  var body: some View {
    let data = TokenChartData(histories: histories, dayCount: dayCount, now: now)
    VStack(alignment: .leading, spacing: compact ? 10 : 14) {
      chart(data)
      ForEach(histories) { history in
        agentRow(history, days: data.points.filter { $0.agent == history.agent }.map(\.day))
      }
      Text(
        localized(
          "Токены за каждый день, а не накопительный итог. Общая шкала заканчивается последним днём с данными; сегодняшний день может быть неполным. Пунктир — пропущенные дни, не нулевой расход. Даты Codex — как у источника, Cursor — UTC. Активность аккаунта не ограничена этим Mac.",
          "Tokens per day, not a running total. The shared timeline ends on the latest reported day; today may be partial. Dashed lines bridge missing days, not zero usage. Codex keeps source dates; Cursor uses UTC. Account activity is not limited to this Mac."
        )
      ).font(.system(size: compact ? 10 : 12)).foregroundStyle(.secondary)
    }
  }

  private func chart(_ data: TokenChartData) -> some View {
    let dates = data.dates
    let range =
      dates[0].addingTimeInterval(-43200)...dates[dates.count - 1].addingTimeInterval(43200)
    let selected = hoveredDate.flatMap { hovered in
      dates.min { abs($0.timeIntervalSince(hovered)) < abs($1.timeIntervalSince(hovered)) }
    }
    return VStack(alignment: .leading, spacing: 8) {
      Chart {
        ForEach(data.points) { point in
          LineMark(
            x: .value(localized("День", "Day"), point.date),
            y: .value(localized("Токены", "Tokens"), point.day.tokens),
            series: .value("segment", "\(point.agent.rawValue)/\(point.segment)")
          ).foregroundStyle(by: .value(localized("Агент", "Agent"), point.agent.title))
            .lineStyle(StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
          PointMark(
            x: .value(localized("День", "Day"), point.date),
            y: .value(localized("Токены", "Tokens"), point.day.tokens)
          ).foregroundStyle(by: .value(localized("Агент", "Agent"), point.agent.title))
            .symbolSize(point.date == selected ? 45 : (dayCount <= 7 ? 18 : 5))
            .accessibilityLabel(point.agent.title + " · " + point.day.day)
            .accessibilityValue(
              localized(
                "\(point.day.tokens.formatted()) токенов", "\(point.day.tokens.formatted()) tokens")
            )
        }
        ForEach(data.bridges) { bridge in
          ForEach([bridge.previous, bridge.next]) { point in
            LineMark(
              x: .value(localized("День", "Day"), point.date),
              y: .value(localized("Токены", "Tokens"), point.day.tokens),
              series: .value("segment", bridge.id)
            ).foregroundStyle(by: .value(localized("Агент", "Agent"), point.agent.title))
              .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4]))
              .interpolationMethod(.linear).accessibilityHidden(true)
          }
        }
        if let selected {
          RuleMark(x: .value(localized("День", "Day"), selected))
            .foregroundStyle(.secondary.opacity(0.45)).lineStyle(StrokeStyle(dash: [3, 3]))
        }
      }
      .chartXScale(domain: range)
      .chartYScale(domain: 0...max(1, Double(data.points.map(\.day.tokens).max() ?? 1) * 1.08))
      .chartForegroundStyleScale(
        domain: AgentID.allCases.map(\.title), range: AgentID.allCases.map(statisticsColor)
      )
      .chartLegend(.hidden)
      .chartXAxis {
        AxisMarks(
          values: dates.enumerated().compactMap { index, date in
            index % max(1, Int(ceil(Double(dates.count - 1) / Double(compact ? 2 : 5)))) == 0
              || index == dates.count - 1 ? date : nil
          }
        ) { value in
          AxisGridLine()
          AxisValueLabel(anchor: axisLabelAnchor(value)) {
            if let date = value.as(Date.self) { Text(TokenChartData.dayLabel(date)) }
          }
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
          AxisGridLine()
          AxisValueLabel {
            if let number = value.as(Double.self) {
              Text(number.formatted(.number.notation(.compactName)))
            }
          }
        }
      }
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
        if data.points.isEmpty {
          Text(localized("История токенов пока недоступна", "Token history is not available yet"))
            .font(.callout).foregroundStyle(.secondary).padding(12).background(.regularMaterial)
        }
      }
      Text(hoverText(data, selected: selected))
        .font(.caption).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: compact ? 30 : 16, alignment: .leading)
    }.padding(12)
      .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 11))
  }

  private func hoverText(_ data: TokenChartData, selected: Date?) -> String {
    guard let selected else {
      return TokenChartData.dayLabel(data.dates[0]) + " — "
        + TokenChartData.dayLabel(data.dates[data.dates.count - 1]) + " · "
        + localized("Наведите для точных значений", "Hover for exact counts")
    }
    let label = TokenChartData.dayLabel(selected)
    let readings = data.points.filter { $0.date == selected }
    guard !readings.isEmpty else { return label + " · " + localized("Нет данных", "No data") }
    return label + " · "
      + readings.map { "\($0.agent.title): \($0.day.tokens.formatted())" }.joined(separator: " · ")
  }

  private func agentRow(_ history: AgentTokenHistory, days: [TokenDay]) -> some View {
    let total = TokenUsage.total(for: days)
    return HStack(spacing: 10) {
      AgentIcon(agent: history.agent, size: 16).foregroundStyle(statisticsColor(history.agent))
      VStack(alignment: .leading, spacing: 3) {
        Text(history.agent.title).font(.system(size: 12, weight: .semibold))
        Text(status(history, count: days.count))
          .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(
            horizontal: false, vertical: true)
        if !compact, let usage = history.usage, usage.state == .ready {
          if let fetched = usage.observedAt {
            Text(
              (now.timeIntervalSince(fetched) > maximumAge
                ? localized("Устарело · ", "Stale · ") : "")
                + fetched.formatted(date: .abbreviated, time: .shortened)
            ).font(.system(size: 10)).foregroundStyle(.secondary)
          }
          if let lifetime = usage.lifetimeTokens {
            Text(localized("За всё время: ", "All time: ") + lifetime.formatted())
              .font(.system(size: 10)).foregroundStyle(.secondary)
          }
        }
      }
      Spacer(minLength: 4)
      Text(total.map { $0.formatted(.number.notation(.compactName)) } ?? "—")
        .font(.system(size: compact ? 16 : 20, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .help(total.map { $0.formatted() } ?? localized("Нет данных", "No data"))
        .accessibilityLabel(localized("Токены за доступные дни", "Tokens for reported days"))
        .accessibilityValue(total.map { $0.formatted() } ?? localized("Нет данных", "No data"))
    }.padding(compact ? 8 : 11)
      .background(
        statisticsColor(history.agent).opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
  }

  private func status(_ history: AgentTokenHistory, count: Int) -> String {
    if let usage = history.usage, usage.state == .ready {
      let calendar = usage.dayBoundary == .utc ? "UTC" : localized("даты источника", "source dates")
      let stale = usage.observedAt.map { now.timeIntervalSince($0) > maximumAge } ?? false
      return (compact && stale ? localized("Устарело · ", "Stale · ") : "")
        + localized("Дней с данными: \(count)/\(dayCount)", "Days reported: \(count)/\(dayCount)")
        + " · " + calendar
    }
    if history.agent == .claude {
      return localized(
        "Текущее подключение не передаёт историю токенов",
        "This connection does not provide token history")
    }
    return history.usage?.state == .unsupported
      ? localized(
        "Источник не поддерживает историю токенов", "The source does not support token history")
      : localized("Нет данных от подключённого аккаунта", "No data from the connected account")
  }
}

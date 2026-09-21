import Foundation

public struct UsageRate: Identifiable, Sendable {
  public var id: String {
    "\(agent.rawValue)/\(accountScope)/\(windowID)/\(date.timeIntervalSince1970)"
  }
  public let agent: AgentID
  public let accountScope: String
  public let windowID: String
  public let date: Date
  public let pointsPerDay: Double
  public let coveredSeconds: TimeInterval
  public let segment: String
}

public enum TrendCalculator {
  /// Fixed cycles only. Missing cycles, replenishment, account changes and gaps break the series.
  public static func rates(from samples: [HistorySample]) -> [UsageRate] {
    struct SeriesKey: Hashable {
      let agent: AgentID
      let account: String
      let window: String
    }
    let grouped = Dictionary(grouping: samples) {
      SeriesKey(agent: $0.agent, account: $0.accountScope, window: $0.windowID)
    }
    return grouped.values.flatMap { series -> [UsageRate] in
      let ordered = series.sorted { $0.observedAt < $1.observedAt }
      var rates: [UsageRate] = []
      var segment = 0
      for (previous, current) in zip(ordered, ordered.dropFirst()) {
        let elapsed = current.observedAt.timeIntervalSince(previous.observedAt)
        let delta = current.usedPercent - previous.usedPercent
        guard let cycle = current.cycleKey, cycle == previous.cycleKey,
          current.plan == previous.plan, elapsed >= 60, elapsed <= 1800,
          delta >= 0, delta.isFinite
        else {
          segment += 1
          continue
        }
        rates.append(
          UsageRate(
            agent: current.agent, accountScope: current.accountScope,
            windowID: current.windowID, date: current.observedAt,
            pointsPerDay: delta * 86400 / elapsed, coveredSeconds: elapsed,
            segment:
              "\(current.agent.rawValue)/\(current.accountScope)/\(current.windowID)/\(cycle)/\(segment)"
          ))
      }
      return rates
    }.sorted { $0.date < $1.date }
  }

  public static func estimatedDaysRemaining(remaining: Double, rates: [UsageRate]) -> Double? {
    guard let last = rates.last else { return nil }
    let segment = rates.filter { $0.segment == last.segment }
    let seconds = segment.reduce(0) { $0 + $1.coveredSeconds }
    guard segment.count >= 24, seconds >= 7200, remaining > 0 else { return nil }
    let weightedRate = segment.reduce(0) { $0 + $1.pointsPerDay * $1.coveredSeconds } / seconds
    guard weightedRate > 0 else { return nil }
    return remaining / weightedRate
  }
}

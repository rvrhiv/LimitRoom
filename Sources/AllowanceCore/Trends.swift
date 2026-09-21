import Foundation

public struct QuotaHistoryPoint: Identifiable, Sendable {
  public var id: String { sample.id }
  public let sample: HistorySample
  public let segment: String
  public let beginsNewCycle: Bool
  public var remainingPercent: Double { min(100, max(0, 100 - sample.usedPercent)) }
}

public enum TrendCalculator {
  /// Observed remaining allowance, never an extrapolated consumption rate.
  public static func remaining(
    from samples: [HistorySample], maximumGap: TimeInterval
  ) -> [QuotaHistoryPoint] {
    struct SeriesKey: Hashable {
      let agent: AgentID
      let account: String
      let window: String
    }
    let grouped = Dictionary(grouping: samples) {
      SeriesKey(agent: $0.agent, account: $0.accountScope, window: $0.windowID)
    }
    return grouped.values.flatMap { series -> [QuotaHistoryPoint] in
      let ordered = series.filter { $0.usedPercent.isFinite && $0.usedPercent >= 0 }
        .sorted { $0.observedAt < $1.observedAt }
      var points: [QuotaHistoryPoint] = []
      var previous: HistorySample?
      var segment = 0
      for current in ordered {
        var beginsNewCycle = false
        if let previous {
          let elapsed = current.observedAt.timeIntervalSince(previous.observedAt)
          // A changed deadline is a reset marker only after the previous deadline
          // passed. Corrections and unknown/rolling cycles simply break the line.
          if let cycle = current.cycleKey, let oldCycle = previous.cycleKey,
            cycle != oldCycle, current.plan == previous.plan,
            let oldDeadline = Double(oldCycle), oldDeadline.isFinite,
            oldDeadline > previous.observedAt.timeIntervalSince1970,
            oldDeadline <= current.observedAt.timeIntervalSince1970
          {
            beginsNewCycle = true
          }
          if current.cycleKey == nil || current.cycleKey != previous.cycleKey
            || current.plan != previous.plan || elapsed <= 0 || elapsed > maximumGap
            || current.usedPercent < previous.usedPercent
          {
            segment += 1
          }
        }
        points.append(
          QuotaHistoryPoint(
            sample: current,
            segment:
              "\(current.agent.rawValue)/\(current.accountScope)/\(current.windowID)/\(segment)",
            beginsNewCycle: beginsNewCycle))
        previous = current
      }
      return points
    }.sorted {
      $0.sample.observedAt == $1.sample.observedAt
        ? $0.id < $1.id : $0.sample.observedAt < $1.sample.observedAt
    }
  }

  /// Display projection only: collapse flat runs, then keep bucket extrema and
  /// cycle markers. Original segment IDs prevent lines across any missing data.
  /// Hover details still use every observation, including omitted singletons.
  public static func chartPoints(
    from points: [QuotaHistoryPoint], maximumBuckets: Int = 500
  ) -> [QuotaHistoryPoint] {
    let grouped = Dictionary(grouping: points, by: \.segment)
    let simplified: [QuotaHistoryPoint] = grouped.values.flatMap { series in
      series.enumerated().compactMap { index, point -> QuotaHistoryPoint? in
        if index > 0, index < series.count - 1,
          point.remainingPercent == series[index - 1].remainingPercent,
          point.remainingPercent == series[index + 1].remainingPercent
        {
          return nil
        }
        return point
      }
    }
    let byAgent = Dictionary(grouping: simplified, by: { $0.sample.agent })
    let bucketCount = max(1, maximumBuckets)
    let projected: [QuotaHistoryPoint] = byAgent.values.flatMap { values in
      guard values.count > bucketCount * 4,
        let start = values.map({ $0.sample.observedAt }).min(),
        let end = values.map({ $0.sample.observedAt }).max(), end > start
      else { return values }
      let width = end.timeIntervalSince(start) / Double(bucketCount)
      let buckets = Dictionary(grouping: values) { point in
        min(bucketCount - 1, Int(point.sample.observedAt.timeIntervalSince(start) / width))
      }
      var retained: [String: QuotaHistoryPoint] = [:]
      for bucket in buckets.values {
        let candidates = [
          bucket.min { $0.sample.observedAt < $1.sample.observedAt },
          bucket.max { $0.sample.observedAt < $1.sample.observedAt },
          bucket.min { $0.remainingPercent < $1.remainingPercent },
          bucket.max { $0.remainingPercent < $1.remainingPercent },
        ]
        for point in candidates.compactMap({ $0 }) { retained[point.id] = point }
        for point in bucket where point.beginsNewCycle { retained[point.id] = point }
      }
      return Array(retained.values)
    }
    return projected.sorted {
      $0.sample.observedAt == $1.sample.observedAt
        ? $0.id < $1.id : $0.sample.observedAt < $1.sample.observedAt
    }
  }
}

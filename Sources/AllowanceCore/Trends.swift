import Foundation

public struct QuotaHistoryPoint: Identifiable, Sendable {
  public enum Transition: Sendable {
    case gap, reset, correction
  }
  public var id: String { sample.id }
  public let sample: HistorySample
  public let segment: String
  public let beginsNewCycle: Bool
  public let transition: Transition?
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
      let ordered = series.filter {
        $0.usedPercent.isFinite && $0.usedPercent >= 0
          && $0.observedAt.timeIntervalSince1970.isFinite
      }.sorted { $0.observedAt < $1.observedAt }
      var points: [QuotaHistoryPoint] = []
      var previous: HistorySample?
      var segment = 0
      for current in ordered {
        var beginsNewCycle = false
        var transition: QuotaHistoryPoint.Transition?
        if let previous {
          let elapsed = current.observedAt.timeIntervalSince(previous.observedAt)
          // The marker is an observed new cycle, not an invented reading at 100%.
          if let cycle = current.cycleKey, let oldCycle = previous.cycleKey,
            cycle != oldCycle, current.plan == previous.plan,
            let oldDeadline = Double(oldCycle), oldDeadline.isFinite,
            oldDeadline > previous.observedAt.timeIntervalSince1970,
            oldDeadline <= current.observedAt.timeIntervalSince1970
          {
            beginsNewCycle = true
          }
          if current.plan != previous.plan || elapsed <= 0 {
            // No visual bridge between incompatible readings.
            segment += 1
          } else if beginsNewCycle {
            transition = .reset
            segment += 1
          } else if current.cycleKey != previous.cycleKey
            || current.usedPercent < previous.usedPercent
          {
            transition = .correction
            segment += 1
          } else if elapsed > maximumGap {
            transition = .gap
            segment += 1
          }
        }
        points.append(
          QuotaHistoryPoint(
            sample: current,
            segment:
              "\(current.agent.rawValue)/\(current.accountScope)/\(current.windowID)/\(segment)",
            beginsNewCycle: beginsNewCycle, transition: transition))
        previous = current
      }
      return points
    }.sorted {
      $0.sample.observedAt == $1.sample.observedAt
        ? $0.id < $1.id : $0.sample.observedAt < $1.sample.observedAt
    }
  }

  /// A less noisy display projection: one real observation near each time-bucket
  /// midpoint, plus every segment boundary. Never average across gaps or resets;
  /// the full observations remain the source for hover values and exports.
  public static func chartPoints(
    from points: [QuotaHistoryPoint], maximumBuckets: Int = 80
  ) -> [QuotaHistoryPoint] {
    guard let start = points.first?.sample.observedAt,
      let end = points.last?.sample.observedAt, end > start
    else { return points }
    let bucketCount = max(1, maximumBuckets)
    let width = end.timeIntervalSince(start) / Double(bucketCount)
    let grouped = Dictionary(grouping: points, by: \.segment)
    let projected: [QuotaHistoryPoint] = grouped.values.flatMap { series -> [QuotaHistoryPoint] in
      guard let first = series.first, let last = series.last else { return [] }
      let buckets = Dictionary(grouping: series) { point in
        min(bucketCount - 1, Int(point.sample.observedAt.timeIntervalSince(start) / width))
      }
      var retained: [String: QuotaHistoryPoint] = [first.id: first]
      retained[last.id] = last
      for (index, bucket) in buckets {
        let midpoint = start.addingTimeInterval((Double(index) + 0.5) * width)
        if let point = bucket.min(by: {
          abs($0.sample.observedAt.timeIntervalSince(midpoint))
            < abs($1.sample.observedAt.timeIntervalSince(midpoint))
        }) {
          retained[point.id] = point
        }
      }
      return Array(retained.values)
    }
    return projected.sorted {
      $0.sample.observedAt == $1.sample.observedAt
        ? $0.id < $1.id : $0.sample.observedAt < $1.sample.observedAt
    }
  }
}

import AllowanceCore
import Foundation

/// Deterministic, fictional activity. No account files, collectors or storage.
enum DemoHistory {
  static func make(now: Date) -> (snapshots: [AgentSnapshot], samples: [HistorySample]) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let midnight = calendar.startOfDay(for: now)
    let origin = midnight.addingTimeInterval(-120 * 86400)
    let today = now.timeIntervalSince(origin) / 86400
    let values:
      [(agent: AgentID, plan: String, session: Double, period: Double, untilReset: Double)] = [
        (.codex, "Pro", 32, 56, 2.5), (.claude, "Max", 18, 37, 4), (.cursor, "Pro", 45, 24, 13),
      ]
    var snapshots: [AgentSnapshot] = []
    var samples: [HistorySample] = []
    for (index, value) in values.enumerated() {
      let profile = ActivityProfile(seed: index, origin: origin, calendar: calendar)
      let cycleDays = value.agent == .cursor ? 30.0 : 7.0
      let currentStart = today + value.untilReset - cycleDays
      let spentToNow = profile.integral(today) - profile.integral(currentStart)
      let currentEnd = now.addingTimeInterval(value.untilReset * 86400)
      let scope = "demo-\(value.agent.rawValue)"
      let title = value.agent == .cursor ? "Other Models · 30d" : "7d"
      snapshots.append(
        AgentSnapshot(
          agent: value.agent, accountScope: scope, accountLabel: "Demo account", plan: value.plan,
          windows: [
            AllowanceWindow(
              id: "session", title: value.agent == .cursor ? "Cursor Models" : "5h",
              usedPercent: value.session, durationMinutes: 300,
              resetsAt: now.addingTimeInterval(9900), kind: .fixed),
            AllowanceWindow(
              id: "period", title: title, usedPercent: value.period,
              durationMinutes: Int(cycleDays * 1440), resetsAt: currentEnd, kind: .fixed),
          ], observedAt: now, state: .ready, source: "Demo",
          tokenUsage: tokens(agent: value.agent, profile: profile, now: now, midnight: midnight),
          quotaResets: value.agent == .codex ? QuotaResets(availableCount: 2) : nil))
      for tick in 0...(90 * 288) {
        let age = Double(90 * 288 - tick) * 300
        // A short collection pause demonstrates the explicitly dashed bridge.
        if value.agent == .claude, (2.35 * 86400...2.65 * 86400).contains(age) { continue }
        let date = now.addingTimeInterval(-age)
        let day = today - age / 86400
        let cycle = floor((day - currentStart) / cycleDays)
        let start = currentStart + cycle * cycleDays
        let end = start + cycleDays
        let activity = profile.integral(day) - profile.integral(start)
        let used: Double
        if cycle == 0 {
          used = value.period * activity / spentToNow
        } else {
          let fullActivity = profile.integral(end) - profile.integral(start)
          let cycleTotal = 68 + 23 * (0.5 + 0.5 * sin(cycle * 1.7 + Double(index)))
          used = cycleTotal * activity / fullActivity
        }
        samples.append(
          HistorySample(
            agent: value.agent, accountScope: scope, windowID: "period", windowTitle: title,
            cycleKey: String(Int64(origin.addingTimeInterval(end * 86400).timeIntervalSince1970)),
            plan: value.plan, observedAt: date, usedPercent: min(100, max(0, used))))
      }
    }
    return (snapshots, samples)
  }

  private static func tokens(
    agent: AgentID, profile: ActivityProfile, now: Date, midnight: Date
  ) -> TokenUsage? {
    guard agent != .claude else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    let days = (0..<90).compactMap { offset -> TokenDay? in
      // Missing and explicitly quiet days have deliberately different semantics.
      if agent == .cursor, offset == 78 { return nil }
      let date = midnight.addingTimeInterval(Double(offset - 89) * 86400)
      let start = date.timeIntervalSince(profile.origin) / 86400
      let end = min(start + 1, now.timeIntervalSince(profile.origin) / 86400)
      let activity = profile.integral(end) - profile.integral(start)
      let burst = 0.8 + 0.35 * (1 + sin(Double(offset) * 2.1 + Double(profile.seed)))
      let count = activity * burst * (agent == .codex ? 760_000 : 430_000)
      let quietDay = offset % 19 == (agent == .codex ? 4 : 9)
      return TokenDay(day: formatter.string(from: date), tokens: quietDay ? 0 : Int64(count))
    }
    return TokenUsage(
      state: .ready, observedAt: now,
      lifetimeTokens: agent == .codex ? TokenUsage.total(for: days).map { $0 + 18_460_200 } : nil,
      days: days, dayBoundary: agent == .cursor ? .utc : .provider)
  }

  private struct ActivityProfile {
    let seed: Int
    let origin: Date
    let weights: [Double]
    let cumulative: [Double]

    init(seed: Int, origin: Date, calendar: Calendar) {
      self.seed = seed
      self.origin = origin
      weights = (0..<160).map { day in
        let date = origin.addingTimeInterval(Double(day) * 86400)
        let weekend = calendar.isDateInWeekend(date)
        let variation =
          0.8 + 0.4 * sin(Double(day) * 1.71 + Double(seed) * 2.3)
          + 0.2 * cos(Double(day) * 0.63 + Double(seed))
        return max(0.12, variation) * (weekend ? 0.35 : 1)
      }
      var running = [0.0]
      for weight in weights { running.append(running.last! + weight) }
      cumulative = running
    }

    func integral(_ day: Double) -> Double {
      let index = min(weights.count - 1, max(0, Int(floor(day))))
      let fraction = min(1, max(0, day - Double(index)))
      let shift = Double(seed) * 0.025
      // Smooth bursts in the morning, afternoon and evening; quiet overnight.
      let progress =
        0.02 * fraction
        + 0.36 * smooth((fraction - 0.30 - shift) / 0.14)
        + 0.43 * smooth((fraction - 0.52 + shift) / 0.13)
        + 0.19 * smooth((fraction - 0.73 - shift) / 0.13)
      return cumulative[index] + weights[index] * progress
    }

    private func smooth(_ value: Double) -> Double {
      let x = min(1, max(0, value))
      return x * x * (3 - 2 * x)
    }
  }
}

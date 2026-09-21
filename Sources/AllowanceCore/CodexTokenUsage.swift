import Foundation

/// Account-wide activity reported by Codex, independent of subscription quota.
/// A missing day is unknown, not zero. Day IDs retain the provider's calendar labels.
public struct CodexTokenDay: Codable, Equatable, Identifiable, Sendable {
  public var id: String { day }
  public let day: String
  public let tokens: Int64

  public init(day: String, tokens: Int64) {
    self.day = day
    self.tokens = tokens
  }
}

public struct CodexTokenUsage: Codable, Equatable, Sendable {
  public enum State: String, Codable, Sendable {
    case ready, unsupported, unavailable
  }
  public let state: State
  public let observedAt: Date?
  public let lifetimeTokens: Int64?
  public let days: [CodexTokenDay]?

  public init(
    state: State, observedAt: Date? = nil, lifetimeTokens: Int64? = nil,
    days: [CodexTokenDay]? = nil
  ) {
    self.state = state
    self.observedAt = observedAt
    self.lifetimeTokens = lifetimeTokens
    self.days = days
  }

  public static func total(for days: [CodexTokenDay]) -> Int64? {
    guard !days.isEmpty else { return nil }
    var total: Int64 = 0
    for day in days {
      let next = total.addingReportingOverflow(day.tokens)
      guard day.tokens >= 0, !next.overflow else { return nil }
      total = next.partialValue
    }
    return total
  }
}

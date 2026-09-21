import Foundation

public enum AgentID: String, Codable, CaseIterable, Identifiable, Sendable {
  case codex, claude, cursor
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .codex: "Codex"
    case .claude: "Claude Code"
    case .cursor: "Cursor"
    }
  }
  public var symbol: String {
    switch self {
    case .codex: "curlybraces"
    case .claude: "asterisk"
    case .cursor: "cursorarrow"
    }
  }
}

public enum SourceState: String, Codable, Sendable {
  case ready, stale, needsSetup, signedOut, unavailable, unsupported
}

public enum WindowKind: String, Codable, Sendable {
  case fixed, rolling, unknown
}

/// Optional facts reported by a provider, never inferred from a marketing plan name.
public struct SubscriptionInfo: Codable, Equatable, Sendable {
  public var billingCycleStart: Date?
  public var billingCycleEnd: Date?
  public var planUsedUSD: Double?
  public var planLimitUSD: Double?
  public var onDemandUsedUSD: Double?
  public var onDemandLimitUSD: Double?
  public var isUnlimited: Bool?
  public var creditBalance: String?
  public init() {}
}

public struct AllowanceWindow: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let usedPercent: Double?
  public let durationMinutes: Int?
  public let resetsAt: Date?
  public let kind: WindowKind

  public init(
    id: String, title: String, usedPercent: Double?, durationMinutes: Int? = nil,
    resetsAt: Date? = nil, kind: WindowKind = .unknown
  ) {
    self.id = id
    self.title = title
    self.usedPercent = usedPercent.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    self.durationMinutes = durationMinutes
    self.resetsAt = resetsAt
    self.kind = kind
  }

  public var remainingPercent: Double? {
    guard let usedPercent, usedPercent.isFinite, usedPercent >= 0 else { return nil }
    return min(100, max(0, 100 - usedPercent))
  }

  public var cycleKey: String? {
    guard kind == .fixed, let resetsAt else { return nil }
    let value = resetsAt.timeIntervalSince1970
    guard value.isFinite, value > -9e15, value < 9e15 else { return nil }
    return String(Int64(value))
  }
}

public struct AgentSnapshot: Identifiable, Codable, Equatable, Sendable {
  public var id: AgentID { agent }
  public let agent: AgentID
  public let accountScope: String?
  public let accountLabel: String?
  public let plan: String?
  public let subscription: SubscriptionInfo?
  public var codexTokenUsage: CodexTokenUsage?
  public var windows: [AllowanceWindow]
  public let observedAt: Date?
  public var fetchedAt: Date
  public var state: SourceState
  public let source: String
  public var detail: String?

  public init(
    agent: AgentID, accountScope: String? = nil, accountLabel: String? = nil,
    plan: String? = nil, subscription: SubscriptionInfo? = nil, windows: [AllowanceWindow] = [],
    observedAt: Date? = nil,
    fetchedAt: Date = .now, state: SourceState = .needsSetup, source: String = "",
    detail: String? = nil, codexTokenUsage: CodexTokenUsage? = nil
  ) {
    self.agent = agent
    self.accountScope = accountScope
    self.accountLabel = accountLabel
    self.plan = plan
    self.subscription = subscription
    self.windows = windows
    self.observedAt = observedAt
    self.fetchedAt = fetchedAt
    self.state = state
    self.source = source
    self.detail = detail
    self.codexTokenUsage = codexTokenUsage
  }

  public func isFresh(at now: Date = .now, maxAge: TimeInterval = 600) -> Bool {
    guard state == .ready, let observedAt else { return false }
    return observedAt <= now.addingTimeInterval(60) && now.timeIntervalSince(observedAt) <= maxAge
  }

  public func windowIsFresh(_ window: AllowanceWindow, at now: Date = .now) -> Bool {
    isFresh(at: now) && (window.resetsAt.map { $0 > now } ?? true)
  }
}

public struct WindowSelection: Codable, Hashable, Sendable {
  public let agent: AgentID
  public let windowID: String
  public init(agent: AgentID, windowID: String) {
    self.agent = agent
    self.windowID = windowID
  }
}

public struct HistorySample: Codable, Sendable, Identifiable {
  public var id: String {
    "\(agent.rawValue)/\(accountScope)/\(windowID)/\(observedAt.timeIntervalSince1970)"
  }
  public let agent: AgentID
  public let accountScope: String
  public let windowID: String
  public let windowTitle: String
  public let cycleKey: String?
  public let plan: String?
  public let observedAt: Date
  public let usedPercent: Double

  public init(
    agent: AgentID, accountScope: String, windowID: String, windowTitle: String,
    cycleKey: String?, plan: String?, observedAt: Date, usedPercent: Double
  ) {
    self.agent = agent
    self.accountScope = accountScope
    self.windowID = windowID
    self.windowTitle = windowTitle
    self.cycleKey = cycleKey
    self.plan = plan
    self.observedAt = observedAt
    self.usedPercent = usedPercent
  }
}

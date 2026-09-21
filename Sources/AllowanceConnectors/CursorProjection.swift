import AllowanceCore
import CryptoKit
import Foundation

/// A deliberately small schema for Cursor's private dashboard endpoints.
/// No team totals, cookie extraction, or inferred averages are used.
public enum CursorProjection {
  private struct Payload: Decodable {
    let usage: Usage
    let identity: Identity
  }
  private struct Identity: Decodable {
    let sub: String?
    let email: String?
  }
  private struct Usage: Decodable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let membershipType: String?
    let isUnlimited: Bool?
    let individualUsage: Individual?
  }
  private struct Individual: Decodable {
    let plan: Plan?
    let onDemand: Spending?
    let overall: Spending?
  }
  private struct Plan: Decodable {
    let enabled: Bool?
    let used: Double?
    let limit: Double?
    let autoPercentUsed: Double?
    let apiPercentUsed: Double?
    let totalPercentUsed: Double?
  }
  private struct Spending: Decodable {
    let enabled: Bool?
    let used: Double?
    let limit: Double?
  }

  public static func snapshot(from data: Data, now: Date = .now) throws -> AgentSnapshot {
    guard data.count <= 65_536 else { throw ConnectorError.invalidResponse }
    let payload = try JSONDecoder().decode(Payload.self, from: data)
    return try project(payload, now: now, source: "Cursor Dashboard (experimental)")
  }

  /// Local credentials and server identity must refer to the same account.
  public static func snapshot(
    usage: Data, identity: Data, expectedSubject: String, source: String, now: Date = .now
  ) throws -> AgentSnapshot {
    guard usage.count <= 65_536, identity.count <= 65_536 else {
      throw CursorLocalConnectionIssue.invalidResponse
    }
    let payload: Payload
    do {
      payload = try Payload(
        usage: JSONDecoder().decode(Usage.self, from: usage),
        identity: JSONDecoder().decode(Identity.self, from: identity))
    } catch { throw CursorLocalConnectionIssue.invalidResponse }
    guard let subject = payload.identity.sub,
      CursorLocalSession.normalizedSubject(subject) == expectedSubject
    else { throw CursorLocalConnectionIssue.accountChanged }
    do { return try project(payload, now: now, source: source) } catch {
      throw CursorLocalConnectionIssue.invalidResponse
    }
  }

  private static func project(_ payload: Payload, now: Date, source: String) throws -> AgentSnapshot
  {
    let identity = [payload.identity.sub, payload.identity.email].compactMap { $0 }.first {
      !$0.isEmpty
    }
    guard let identity else { throw ConnectorError.signedOut }
    let scope = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    let usage = payload.usage
    let plan = usage.individualUsage?.plan
    let reset = date(usage.billingCycleEnd)
    let start = date(usage.billingCycleStart)
    let minutes = start.flatMap { start in
      reset.flatMap { end -> Int? in
        let duration = end.timeIntervalSince(start) / 60
        guard duration.isFinite, duration > 0, duration <= 525_600_000 else { return nil }
        return Int(duration)
      }
    }
    var windows: [AllowanceWindow] = []
    if plan?.enabled != false, usage.isUnlimited != true {
      let values = [
        ("cursor_models", "Cursor Models", plan?.autoPercentUsed),
        ("other_models", "Other Models", plan?.apiPercentUsed),
        (
          "plan_total", "Total",
          plan?.totalPercentUsed ?? percentage(used: plan?.used, limit: plan?.limit)
        ),
      ]
      windows = values.compactMap { id, title, used in
        guard let used, used.isFinite, used >= 0 else { return nil }
        return AllowanceWindow(
          id: id, title: title, usedPercent: used,
          durationMinutes: minutes, resetsAt: reset, kind: reset == nil ? .unknown : .fixed)
      }
    }
    if let cap = usage.individualUsage?.overall, cap.enabled == true,
      let used = percentage(used: cap.used, limit: cap.limit)
    {
      windows.append(
        AllowanceWindow(
          id: "personal_spending_cap", title: "Personal spending cap", usedPercent: used,
          durationMinutes: minutes, resetsAt: reset, kind: reset == nil ? .unknown : .fixed))
    }
    var info = SubscriptionInfo()
    info.billingCycleStart = start
    info.billingCycleEnd = reset
    info.isUnlimited = usage.isUnlimited
    info.planUsedUSD = dollars(plan?.used)
    info.planLimitUSD = dollars(plan?.limit)
    if usage.individualUsage?.onDemand?.enabled == true {
      info.onDemandUsedUSD = dollars(usage.individualUsage?.onDemand?.used)
      info.onDemandLimitUSD = dollars(usage.individualUsage?.onDemand?.limit)
    }
    return AgentSnapshot(
      agent: .cursor, accountScope: scope, accountLabel: payload.identity.email,
      plan: usage.membershipType, subscription: info, windows: windows, observedAt: now,
      state: windows.isEmpty && usage.isUnlimited != true ? .unsupported : .ready,
      source: source)
  }
  private static func percentage(used: Double?, limit: Double?) -> Double? {
    guard let used, let limit, used.isFinite, limit.isFinite, used >= 0, limit > 0 else {
      return nil
    }
    let percent = used / limit * 100
    return percent.isFinite ? percent : nil
  }
  private static func dollars(_ cents: Double?) -> Double? {
    cents.flatMap { $0.isFinite && $0 >= 0 ? $0 / 100 : nil }
  }
  private static func date(_ string: String?) -> Date? {
    guard let string else { return nil }
    let formatter = ISO8601DateFormatter()
    if let date = formatter.date(from: string) { return date }
    formatter.formatOptions.insert(.withFractionalSeconds)
    return formatter.date(from: string)
  }
}

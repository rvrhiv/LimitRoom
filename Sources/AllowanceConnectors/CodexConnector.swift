import AllowanceCore
import CryptoKit
import Darwin
import Foundation

public struct CodexConnector: AllowanceConnector {
  public let agent: AgentID = .codex
  public let executable: URL?
  public init(executable: URL?) { self.executable = executable }

  public func read() async throws -> AgentSnapshot {
    guard let executable else { throw ConnectorError.missingExecutable }
    // Pipe reads run off the cooperative executor; the process has a bounded lifetime.
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .utility).async {
        do { continuation.resume(returning: try Self.collect(executable: executable)) } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private static func collect(executable: URL) throws -> AgentSnapshot {
    let rpc = RPCProcess(executable: executable)
    try rpc.start()
    defer { rpc.stop() }
    _ = try rpc.request(
      "initialize", id: 1,
      params: ["clientInfo": ["name": "limitroom", "title": "LimitRoom", "version": "0.1.0"]])
    try rpc.notify("initialized")
    let accountReply = try rpc.request("account/read", id: 2, params: ["refreshToken": false])
    guard let account = accountReply["account"] as? [String: Any] else {
      throw ConnectorError.signedOut
    }
    let limitsReply = try rpc.request("account/rateLimits/read", id: 3, params: [:])
    let quotaObservedAt = Date.now
    let buckets: [(String, [String: Any])]
    if let byID = limitsReply["rateLimitsByLimitId"] as? [String: [String: Any]], !byID.isEmpty {
      buckets = byID.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    } else if let single = limitsReply["rateLimits"] as? [String: Any] {
      buckets = [(single["limitId"] as? String ?? "codex", single)]
    } else {
      throw ConnectorError.invalidResponse
    }

    let windows = buckets.flatMap { id, bucket in
      ["primary", "secondary"].compactMap { slot -> AllowanceWindow? in
        guard let raw = bucket[slot] as? [String: Any] else { return nil }
        let minutes = (raw["windowDurationMins"] as? NSNumber)?.intValue
        let duration =
          minutes.map { $0 == 10080 ? "7d" : ($0 % 60 == 0 ? "\($0 / 60)h" : "\($0)m") } ?? slot
        let label = bucket["limitName"] as? String
        let title = [label ?? (id == "codex" ? nil : id), duration].compactMap { $0 }.joined(
          separator: " · ")
        return AllowanceWindow(
          id: "\(id).\(slot)", title: title,
          usedPercent: (raw["usedPercent"] as? NSNumber)?.doubleValue,
          durationMinutes: minutes,
          resetsAt: (raw["resetsAt"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue)
          },
          kind: .fixed)
      }
    }
    let identity = account["id"] as? String ?? account["email"] as? String
    let scope = identity.map {
      SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    var subscription = SubscriptionInfo()
    if let credits = buckets.first?.1["credits"] as? [String: Any] {
      subscription.creditBalance = credits["balance"] as? String
      subscription.isUnlimited = credits["unlimited"] as? Bool
    }
    var tokenUsage = CodexTokenUsage(state: .unavailable)
    if identity != nil {
      do {
        let reply = try rpc.request("account/usage/read", id: 4, params: [:], timeout: 3)
        tokenUsage = try decodeTokenUsage(reply)
      } catch RPCError.server(let code) where code == -32601 {
        tokenUsage = CodexTokenUsage(state: .unsupported)
      } catch {
        // Optional statistics must never make a successful quota read fail.
        tokenUsage = CodexTokenUsage(state: .unavailable)
      }
      if tokenUsage.state == .ready {
        if let verifiedReply = try? rpc.request(
          "account/read", id: 5, params: ["refreshToken": false], timeout: 2)
        {
          guard let verified = verifiedReply["account"] as? [String: Any],
            (verified["id"] as? String ?? verified["email"] as? String) == identity
          else { throw ConnectorError.signedOut }
        } else {
          tokenUsage = CodexTokenUsage(state: .unavailable)
        }
      }
    }
    return AgentSnapshot(
      agent: .codex, accountScope: scope, accountLabel: account["email"] as? String,
      plan: account["planType"] as? String ?? buckets.first?.1["planType"] as? String,
      subscription: subscription, windows: windows, observedAt: quotaObservedAt,
      state: windows.isEmpty ? .unsupported : .ready, source: "Codex App Server",
      codexTokenUsage: tokenUsage)
  }

  private static func decodeTokenUsage(_ reply: [String: Any]) throws -> CodexTokenUsage {
    struct Reply: Decodable {
      struct Summary: Decodable { let lifetimeTokens: Int64? }
      struct Day: Decodable {
        let startDate: String
        let tokens: Int64
      }
      let summary: Summary
      let dailyUsageBuckets: [Day]?
    }
    let decoded = try JSONDecoder().decode(
      Reply.self, from: JSONSerialization.data(withJSONObject: reply))
    guard decoded.summary.lifetimeTokens.map({ $0 >= 0 }) ?? true,
      (decoded.dailyUsageBuckets?.count ?? 0) <= 3660
    else { throw ConnectorError.invalidResponse }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    var seen: Set<String> = []
    let days = try decoded.dailyUsageBuckets?.map { day -> CodexTokenDay in
      guard day.tokens >= 0, day.startDate.utf8.count == 10,
        day.startDate.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil,
        let date = formatter.date(from: day.startDate),
        formatter.string(from: date) == day.startDate,
        seen.insert(day.startDate).inserted
      else { throw ConnectorError.invalidResponse }
      return CodexTokenDay(day: day.startDate, tokens: day.tokens)
    }
    return CodexTokenUsage(
      state: .ready, observedAt: .now, lifetimeTokens: decoded.summary.lifetimeTokens,
      days: days?.sorted { $0.day < $1.day })
  }
}

private enum RPCError: Error { case server(Int) }

private final class RPCProcess: @unchecked Sendable {
  private let process = Process()
  private let input = Pipe()
  private let output = Pipe()
  private var buffer = Data()
  private var deadline: TimeInterval = 0
  private let executable: URL

  init(executable: URL) { self.executable = executable }
  func start() throws {
    process.executableURL = executable
    process.arguments = ["app-server"]
    process.standardInput = input
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    deadline = ProcessInfo.processInfo.systemUptime + 15
  }
  func stop() {
    try? input.fileHandleForWriting.close()
    if process.isRunning {
      process.terminate()
      // This is our short-lived child, not the user's running Codex session.
      let end = ProcessInfo.processInfo.systemUptime + 0.5
      while process.isRunning, ProcessInfo.processInfo.systemUptime < end {
        Thread.sleep(forTimeInterval: 0.02)
      }
      if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }
    try? output.fileHandleForReading.close()
  }
  func notify(_ method: String) throws { try send(["method": method, "params": [:]]) }
  func request(
    _ method: String, id: Int, params: [String: Any], timeout: TimeInterval = 15
  ) throws -> [String: Any] {
    let requestDeadline = min(deadline, ProcessInfo.processInfo.systemUptime + timeout)
    try send(["method": method, "id": id, "params": params])
    while true {
      let line = try nextLine(until: requestDeadline)
      guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
        continue
      }
      if let requestID = message["id"], message["method"] != nil {
        try send(["id": requestID, "error": ["code": -32601, "message": "Read-only client"]])
        continue
      }
      guard (message["id"] as? NSNumber)?.intValue == id else { continue }
      if let error = message["error"] as? [String: Any] {
        throw RPCError.server((error["code"] as? NSNumber)?.intValue ?? 0)
      }
      guard message["error"] == nil else { throw ConnectorError.invalidResponse }
      guard let result = message["result"] as? [String: Any] else {
        throw ConnectorError.invalidResponse
      }
      return result
    }
  }
  private func send(_ message: [String: Any]) throws {
    var data = try JSONSerialization.data(withJSONObject: message)
    data.append(10)
    try input.fileHandleForWriting.write(contentsOf: data)
  }
  private func nextLine(until requestDeadline: TimeInterval) throws -> Data {
    while true {
      let remaining = requestDeadline - ProcessInfo.processInfo.systemUptime
      guard remaining > 0 else { throw ConnectorError.timedOut }
      if let index = buffer.firstIndex(of: 10) {
        let line = buffer.prefix(upTo: index)
        buffer.removeSubrange(...index)
        if line.isEmpty { continue }
        return Data(line)
      }
      guard buffer.count < 1_048_576 else { throw ConnectorError.invalidResponse }
      var descriptor = pollfd(
        fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
      let ready = poll(&descriptor, 1, Int32(min(remaining * 1000, 1000)))
      if ready == 0 { continue }
      if ready < 0, errno == EINTR { continue }
      guard ready > 0 else { throw ConnectorError.unavailable }
      var bytes = [UInt8](repeating: 0, count: 8192)
      let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
      guard count > 0 else { throw ConnectorError.unavailable }
      buffer.append(contentsOf: bytes.prefix(count))
    }
  }
}

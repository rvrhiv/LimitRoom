import AllowanceCore
import Foundation

/// Last-known display data only. Never a substitute for a successful refresh.
public struct SnapshotCacheStore: Sendable {
  private let file: URL
  public init(directory: URL) { file = directory.appendingPathComponent("last-readings.json") }
  public func read() -> [AgentSnapshot] {
    guard let data = try? Data(contentsOf: file), data.count <= 262_144,
      let values = try? JSONDecoder().decode([AgentSnapshot].self, from: data)
    else { return [] }
    return values.filter {
      $0.observedAt.map { Date.now.timeIntervalSince($0) < 90 * 86400 } ?? false
    }
    .map { value in
      var snapshot = value
      snapshot.state = .stale
      snapshot.codexTokenUsage = nil
      return snapshot
    }
  }
  public func write(_ snapshots: [AgentSnapshot]) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    // Daily history comes from Codex; do not cache another account's token totals.
    let quotaOnly = snapshots.map { value in
      var snapshot = value
      snapshot.codexTokenUsage = nil
      return snapshot
    }
    try JSONEncoder().encode(quotaOnly).write(to: file, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
  }
}

public enum ClaudeConnectionStore {
  /// The atomically persisted marker is authoritative after a crash; UserDefaults
  /// may not yet have flushed the matching scope during a connection change.
  public static func read(directory: URL) -> String? {
    let file = directory.appendingPathComponent("claude-connection")
    guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
    defer { try? handle.close() }
    guard let data = try? handle.read(upToCount: 257), data.count <= 256,
      let scope = String(data: data, encoding: .utf8), UUID(uuidString: scope) != nil
    else { return nil }
    return scope
  }

  public static func write(scope: String, directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("claude-connection")
    try Data(scope.utf8).write(to: file, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
  }
}

import AllowanceCore
import CSQLite
import Foundation

public enum StorageError: Error {
  case database(String)
  case unsupportedVersion(Int32)
}

// Owned exclusively by HistoryStore. The wrapper closes the pointer on destruction.
private final class Database: @unchecked Sendable {
  let handle: OpaquePointer
  init(url: URL) throws {
    var pointer: OpaquePointer?
    let result = sqlite3_open_v2(
      url.path, &pointer, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
    guard result == SQLITE_OK, let pointer else {
      if let pointer { sqlite3_close(pointer) }
      throw StorageError.database("Cannot open history database")
    }
    handle = pointer
    sqlite3_busy_timeout(handle, 3000)
  }
  deinit { sqlite3_close(handle) }
}

public actor HistoryStore {
  private let database: Database
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    database = try Database(url: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    var statement: OpaquePointer?
    sqlite3_prepare_v2(database.handle, "PRAGMA user_version", -1, &statement, nil)
    let version = sqlite3_step(statement) == SQLITE_ROW ? sqlite3_column_int(statement, 0) : -1
    sqlite3_finalize(statement)
    guard version >= 0, version <= 1 else { throw StorageError.unsupportedVersion(version) }
    let schema = """
      PRAGMA journal_mode=WAL;
      PRAGMA secure_delete=ON;
      BEGIN IMMEDIATE;
      CREATE TABLE IF NOT EXISTS observations (
        id TEXT PRIMARY KEY, observed REAL NOT NULL, payload TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS observations_time ON observations(observed);
      PRAGMA user_version=1;
      COMMIT;
      """
    guard sqlite3_exec(database.handle, schema, nil, nil, nil) == SQLITE_OK else {
      throw StorageError.database("Cannot initialize history")
    }
  }

  public func record(_ snapshot: AgentSnapshot, now: Date = .now) throws {
    guard snapshot.isFresh(at: now), let account = snapshot.accountScope,
      let observed = snapshot.observedAt
    else { return }
    try execute("BEGIN IMMEDIATE")
    do {
      for window in snapshot.windows where snapshot.windowIsFresh(window, at: now) {
        guard let used = window.usedPercent, used.isFinite, used >= 0 else { continue }
        let sample = HistorySample(
          agent: snapshot.agent, accountScope: account, windowID: window.id,
          windowTitle: window.title, cycleKey: window.cycleKey, plan: snapshot.plan,
          observedAt: observed, usedPercent: used)
        let data = try encoder.encode(sample)
        let payload = String(decoding: data, as: UTF8.self)
        try withStatement(
          "INSERT OR IGNORE INTO observations(id, observed, payload) VALUES(?, ?, ?)"
        ) { statement in
          bind(sample.id, to: statement, index: 1)
          sqlite3_bind_double(statement, 2, observed.timeIntervalSince1970)
          bind(payload, to: statement, index: 3)
          guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.database("Cannot record observation")
          }
        }
      }
      try purge(before: now.addingTimeInterval(-90 * 86400))
      try execute("COMMIT")
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  public func samples(since date: Date = .distantPast) throws -> [HistorySample] {
    let cutoff = max(date, Date.now.addingTimeInterval(-90 * 86400))
    try purge(before: Date.now.addingTimeInterval(-90 * 86400))
    return try withStatement(
      "SELECT payload FROM observations WHERE observed >= ? ORDER BY observed"
    ) { statement in
      sqlite3_bind_double(statement, 1, cutoff.timeIntervalSince1970)
      var values: [HistorySample] = []
      var result = sqlite3_step(statement)
      while result == SQLITE_ROW {
        guard let text = sqlite3_column_text(statement, 0) else {
          throw StorageError.database("Missing observation")
        }
        values.append(
          try decoder.decode(HistorySample.self, from: Data(String(cString: text).utf8)))
        result = sqlite3_step(statement)
      }
      guard result == SQLITE_DONE else { throw StorageError.database("Cannot read history") }
      return values
    }
  }

  public func removeAll() throws {
    try execute("DELETE FROM observations")
    try execute("PRAGMA wal_checkpoint(TRUNCATE)")
  }
  public func exportJSON() throws -> Data {
    let output = JSONEncoder()
    output.outputFormatting = [.prettyPrinted, .sortedKeys]
    output.dateEncodingStrategy = .iso8601
    return try output.encode(samples())
  }
  public func exportCSV() throws -> Data {
    func escaped(_ text: String) -> String {
      // Neutralize spreadsheet formula prefixes even in quoted CSV fields.
      let first = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
      let safe = ["=", "+", "-", "@"].contains(first) ? "'" + text : text
      return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    let formatter = ISO8601DateFormatter()
    let lines = try samples().map { sample in
      [
        sample.agent.rawValue, sample.accountScope, sample.windowID,
        formatter.string(from: sample.observedAt),
        String(sample.usedPercent), sample.cycleKey ?? "",
      ].map(escaped).joined(separator: ",")
    }
    return Data(
      (["agent,account_scope,window,observed_at,used_percent,cycle"] + lines).joined(
        separator: "\n"
      ).utf8)
  }

  private func purge(before date: Date) throws {
    try withStatement("DELETE FROM observations WHERE observed < ?") { statement in
      sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
      guard sqlite3_step(statement) == SQLITE_DONE else {
        throw StorageError.database("Cannot expire history")
      }
    }
  }
  private func execute(_ sql: String) throws {
    guard sqlite3_exec(database.handle, sql, nil, nil, nil) == SQLITE_OK else {
      throw StorageError.database("History operation failed")
    }
  }
  private func withStatement<T>(_ sql: String, body: (OpaquePointer) throws -> T) throws -> T {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database.handle, sql, -1, &statement, nil) == SQLITE_OK, let statement
    else {
      throw StorageError.database("Cannot prepare history operation")
    }
    defer { sqlite3_finalize(statement) }
    return try body(statement)
  }
  private func bind(_ text: String, to statement: OpaquePointer, index: Int32) {
    text.withCString { ptr in
      _ = sqlite3_bind_text(
        statement, index, ptr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
  }
}

import CSQLite
import Foundation

/// Only sanitized categories cross the connector boundary. Never include SQLite,
/// HTTP bodies, URLs with credentials or token values in errors or diagnostics.
public enum CursorLocalConnectionIssue: Error, Equatable, Sendable {
  case noSession, storageUnavailable, invalidSession, expiredSession
  case signedOut, accountChanged, unavailable, invalidResponse
}

/// Ephemeral request material. Deliberately not Codable or exposed to the UI.
struct CursorLocalSession: Sendable, Equatable {
  private let token: String
  let subject: String
  let expiresAt: Date

  init(token: String, now: Date = .now) throws {
    let segments = token.split(separator: ".", omittingEmptySubsequences: false)
    let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.".utf8)
    guard (1...16_384).contains(token.utf8.count), token.utf8.allSatisfy(allowed.contains),
      segments.count == 3, segments.allSatisfy({ !$0.isEmpty })
    else { throw CursorLocalConnectionIssue.invalidSession }
    var encoded = String(segments[1]).replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
    struct Claims: Decodable {
      let sub: String
      let exp: Double
    }
    guard let data = Data(base64Encoded: encoded),
      let claims = try? JSONDecoder().decode(Claims.self, from: data),
      let subject = Self.normalizedSubject(claims.sub),
      claims.exp.isFinite, claims.exp < 253_402_300_800
    else { throw CursorLocalConnectionIssue.invalidSession }
    let expiry = Date(timeIntervalSince1970: claims.exp)
    guard expiry.timeIntervalSince(now) > 60 else {
      throw CursorLocalConnectionIssue.expiredSession
    }
    self.token = token
    self.subject = subject
    expiresAt = expiry
  }

  var cookieHeader: String { "WorkosCursorSessionToken=\(subject)%3A%3A\(token)" }

  static func normalizedSubject(_ raw: String) -> String? {
    guard let value = raw.split(separator: "|", omittingEmptySubsequences: false).last,
      !value.isEmpty, value.utf8.count <= 256
    else { return nil }
    let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-".utf8)
    return value.utf8.allSatisfy(allowed.contains) ? String(value) : nil
  }
}

struct CursorLocalSessionStore: Sendable {
  let databaseURL: URL

  init() {
    databaseURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Application Support/Cursor/User/globalStorage/state.vscdb")
  }

  func read() throws -> CursorLocalSession {
    // Pin the Unix VFS whose readonly_shm contract also protects WAL sidecars.
    // 3.31 additionally guarantees SQLITE_OPEN_NOFOLLOW is understood.
    guard sqlite3_libversion_number() >= 3_031_000, sqlite3_vfs_find("unix") != nil else {
      throw CursorLocalConnectionIssue.storageUnavailable
    }
    let manager = FileManager.default
    guard manager.fileExists(atPath: databaseURL.path) else {
      throw CursorLocalConnectionIssue.noSession
    }
    guard
      let values = try? databaseURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
      ),
      values.isRegularFile == true, values.isSymbolicLink != true
    else { throw CursorLocalConnectionIssue.storageUnavailable }
    let walExists = manager.fileExists(atPath: databaseURL.path + "-wal")
    let shmExists = manager.fileExists(atPath: databaseURL.path + "-shm")
    // Never ignore a live WAL, and never create missing sidecars in Cursor's directory.
    guard walExists == shmExists else { throw CursorLocalConnectionIssue.storageUnavailable }
    let immutable = !walExists && !shmExists
    // mode=ro alone still permits writes/creation of -shm. Never retry without
    // readonly_shm if SQLite cannot safely use the current sidecars.
    let uri =
      databaseURL.absoluteString + "?mode=ro&readonly_shm=1"
      + (immutable ? "&immutable=1" : "")
    var database: OpaquePointer?
    let result = sqlite3_open_v2(
      uri, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOFOLLOW, "unix")
    defer { sqlite3_close(database) }
    guard result == SQLITE_OK, let database, sqlite3_db_readonly(database, "main") == 1 else {
      throw CursorLocalConnectionIssue.storageUnavailable
    }
    sqlite3_busy_timeout(database, 250)
    sqlite3_limit(database, SQLITE_LIMIT_LENGTH, 32_768)
    guard sqlite3_exec(database, "PRAGMA query_only = ON", nil, nil, nil) == SQLITE_OK else {
      throw CursorLocalConnectionIssue.storageUnavailable
    }
    var statement: OpaquePointer?
    let query = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1"
    guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
      throw CursorLocalConnectionIssue.storageUnavailable
    }
    defer { sqlite3_finalize(statement) }
    let step = sqlite3_step(statement)
    guard step != SQLITE_DONE else { throw CursorLocalConnectionIssue.noSession }
    guard step == SQLITE_ROW else { throw CursorLocalConnectionIssue.storageUnavailable }
    let count = Int(sqlite3_column_bytes(statement, 0))
    let type = sqlite3_column_type(statement, 0)
    guard type == SQLITE_TEXT || type == SQLITE_BLOB, (1...32_768).contains(count),
      let bytes = sqlite3_column_blob(statement, 0)
    else { throw CursorLocalConnectionIssue.invalidSession }
    let data = Data(bytes: bytes, count: count)
    // ASCII UTF-16LE is also valid UTF-8 with interleaved NULs. Detect it first.
    let utf16 =
      type == SQLITE_BLOB && count.isMultiple(of: 2)
      && stride(from: 0, to: count, by: 2).allSatisfy {
        (1..<128).contains(data[$0]) && data[$0 + 1] == 0
      }
    guard let token = String(data: data, encoding: utf16 ? .utf16LittleEndian : .utf8) else {
      throw CursorLocalConnectionIssue.invalidSession
    }
    if immutable,
      manager.fileExists(atPath: databaseURL.path + "-wal")
        || manager.fileExists(atPath: databaseURL.path + "-shm")
    {
      throw CursorLocalConnectionIssue.storageUnavailable
    }
    return try CursorLocalSession(token: token)
  }
}

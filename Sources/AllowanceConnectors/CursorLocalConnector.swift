import AllowanceCore
import Foundation

/// Constructed without reading anything. AppModel may call read only after opt-in.
public actor CursorLocalConnector: AllowanceConnector {
  public nonisolated let agent = AgentID.cursor
  public private(set) var issue: CursorLocalConnectionIssue?
  private let store = CursorLocalSessionStore()
  private var lastGood: AgentSnapshot?
  private var lastSubject: String?
  private var generation = 0
  private var activeSession: URLSession?
  private let source = "Cursor.app → Cursor Dashboard"

  public init() {}

  public func reset() {
    generation += 1
    activeSession?.invalidateAndCancel()
    activeSession = nil
    lastGood = nil
    lastSubject = nil
    issue = nil
  }

  public func read() async -> AgentSnapshot {
    let requestGeneration = generation
    let auth: CursorLocalSession
    do {
      auth = try store.read()
    } catch {
      return failClosed(error as? CursorLocalConnectionIssue ?? .storageUnavailable)
    }
    if lastSubject != auth.subject { lastGood = nil }
    lastSubject = auth.subject
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.timeoutIntervalForRequest = 12
    configuration.timeoutIntervalForResource = 12
    let session = URLSession(configuration: configuration)
    activeSession = session
    defer {
      session.invalidateAndCancel()
      if requestGeneration == generation { activeSession = nil }
    }
    do {
      async let usage = Self.fetch(path: "/api/usage-summary", auth: auth, session: session)
      async let identity = Self.fetch(path: "/api/auth/me", auth: auth, session: session)
      let snapshot = try await CursorProjection.snapshot(
        usage: usage, identity: identity, expectedSubject: auth.subject, source: source)
      guard requestGeneration == generation else { return disconnected() }
      guard try store.read() == auth else { return failClosed(.accountChanged) }
      lastGood = snapshot
      issue = nil
      return snapshot
    } catch {
      guard requestGeneration == generation else { return disconnected() }
      let failure = error as? CursorLocalConnectionIssue ?? .unavailable
      // Only a still-identical, unexpired local session may retain its old reading.
      // Failed auth/schema/account validation must not borrow monitor/cache history.
      if failure == .unavailable, (try? store.read()) == auth, var old = lastGood {
        old.state = .stale
        issue = .unavailable
        return old
      }
      return failClosed(failure)
    }
  }

  private func disconnected() -> AgentSnapshot {
    AgentSnapshot(agent: .cursor, state: .needsSetup, source: source)
  }

  private func failClosed(_ issue: CursorLocalConnectionIssue) -> AgentSnapshot {
    self.issue = issue
    lastGood = nil
    lastSubject = nil
    // Empty unavailable snapshots can inherit another account in AllowanceMonitor.
    // needsSetup/signedOut explicitly clear the old account instead.
    let state: SourceState =
      switch issue {
      case .signedOut, .expiredSession, .invalidSession, .accountChanged: .signedOut
      default: .needsSetup
      }
    return AgentSnapshot(agent: .cursor, state: state, source: source)
  }

  private static func fetch(path: String, auth: CursorLocalSession, session: URLSession)
    async throws
    -> Data
  {
    guard path == "/api/usage-summary" || path == "/api/auth/me",
      let url = URL(string: "https://cursor.com" + path)
    else { throw CursorLocalConnectionIssue.invalidResponse }
    var request = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
    request.httpMethod = "GET"
    request.httpShouldHandleCookies = false
    request.setValue(auth.cookieHeader, forHTTPHeaderField: "Cookie")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (bytes, response) = try await session.bytes(for: request, delegate: CursorNoRedirects())
    guard let http = response as? HTTPURLResponse, http.url == url else {
      throw CursorLocalConnectionIssue.invalidResponse
    }
    if http.statusCode == 401 || http.statusCode == 403 {
      throw CursorLocalConnectionIssue.signedOut
    }
    guard http.statusCode == 200 else {
      throw (300..<400).contains(http.statusCode)
        ? CursorLocalConnectionIssue.signedOut : CursorLocalConnectionIssue.unavailable
    }
    guard response.expectedContentLength <= 65_536 else {
      throw CursorLocalConnectionIssue.invalidResponse
    }
    var data = Data()
    for try await byte in bytes {
      guard data.count < 65_536 else { throw CursorLocalConnectionIssue.invalidResponse }
      data.append(byte)
    }
    return data
  }
}

private final class CursorNoRedirects: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest
  ) async -> URLRequest? { nil }
}

import AllowanceCore
import CoreFoundation
import Foundation

/// A short-lived, memory-only result. It is reused for at most 15 minutes, then
/// refreshed on the next quota read because Cursor's current UTC day is still changing.
public struct CursorTokenHistoryCache: Sendable {
  fileprivate let subject: String
  fileprivate let usage: TokenUsage
  fileprivate let expiresAt: Date

  public func subject(at now: Date = .now) -> String? {
    expiresAt > now ? subject : nil
  }

  fileprivate func usage(for subject: String, at now: Date) -> TokenUsage? {
    self.subject == subject && expiresAt > now ? usage : nil
  }
}

public struct CursorTokenHistoryWebResult: Sendable {
  public let subject: String?
  public let usage: TokenUsage
  public let cache: CursorTokenHistoryCache?
}

/// Reads only Cursor's account-wide dashboard events. The API is private, so every
/// ambiguity fails closed instead of publishing a partial token total.
public enum CursorTokenHistory {
  private static let endpoint = URL(
    string: "https://cursor.com/api/dashboard/get-filtered-usage-events")!
  private static let pageSize = 1_000
  private static let maxPages = 20
  private static let maxEvents = pageSize * maxPages
  private static let maxResponseBytes = 4 * 1_024 * 1_024
  private static let totalDeadline: Duration = .seconds(20)
  private static let cacheLifetime: TimeInterval = 15 * 60

  private struct Window: Sendable {
    let startMS: Int64
    let endMS: Int64
  }

  private struct Event: Sendable {
    let canonical: Data
    let timestampMS: Int64
    let tokens: Int64
  }

  private struct Page: Sendable {
    let total: Int
    let events: [Event]
  }

  private struct RequestBody: Encodable {
    let page: Int
    let pageSize: Int
    let startDate: String
    let endDate: String
  }

  static func cachedUsage(
    _ cache: CursorTokenHistoryCache?, subject: String, now: Date
  ) -> TokenUsage? {
    cache?.usage(for: subject, at: now)
  }

  static func cache(subject: String, usage: TokenUsage, now: Date) -> CursorTokenHistoryCache {
    CursorTokenHistoryCache(
      subject: subject, usage: usage, expiresAt: now.addingTimeInterval(cacheLifetime))
  }

  static func fetch(
    auth: CursorLocalSession, session: URLSession, now: Date = .now
  ) async throws -> TokenUsage {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: totalDeadline)
    return try await withThrowingTaskGroup(of: TokenUsage.self) { group in
      group.addTask {
        try await fetchPages(
          auth: auth, session: session, now: now, clock: clock, deadline: deadline)
      }
      group.addTask {
        try await clock.sleep(until: deadline)
        try Task.checkCancellation()
        throw CursorLocalConnectionIssue.unavailable
      }
      defer { group.cancelAll() }
      guard let result = try await group.next() else {
        throw CursorLocalConnectionIssue.unavailable
      }
      return result
    }
  }

  private static func fetchPages(
    auth: CursorLocalSession, session: URLSession, now: Date, clock: ContinuousClock,
    deadline: ContinuousClock.Instant
  ) async throws -> TokenUsage {
    let window = try utcWindow(now: now)
    var pages: [[Event]] = []
    var expectedTotal: Int?
    var completed = false

    for pageNumber in 1...maxPages {
      try Task.checkCancellation()
      guard clock.now < deadline else { throw CursorLocalConnectionIssue.unavailable }
      let data = try await fetchPage(
        page: pageNumber, window: window, auth: auth, session: session, clock: clock,
        deadline: deadline)
      let page = try decodePage(data)
      if let expectedTotal, expectedTotal != page.total {
        throw CursorLocalConnectionIssue.invalidResponse
      }
      expectedTotal = page.total
      guard page.total <= maxEvents else { throw CursorLocalConnectionIssue.invalidResponse }
      if page.events.isEmpty {
        completed = true
        break
      }
      pages.append(page.events)
      if page.events.count < pageSize {
        completed = true
        break
      }
    }

    guard completed, let expectedTotal else { throw CursorLocalConnectionIssue.invalidResponse }
    let events = try reconciledEvents(pages: pages, expectedTotal: expectedTotal)
    let result = try usage(from: events, window: window, observedAt: .now)
    try Task.checkCancellation()
    guard clock.now < deadline else { throw CursorLocalConnectionIssue.unavailable }
    return result
  }

  private static func fetchPage(
    page: Int, window: Window, auth: CursorLocalSession, session: URLSession,
    clock: ContinuousClock, deadline: ContinuousClock.Instant
  ) async throws -> Data {
    guard clock.now < deadline else { throw CursorLocalConnectionIssue.unavailable }
    var request = URLRequest(
      url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 12)
    request.httpMethod = "POST"
    request.httpShouldHandleCookies = false
    request.setValue(auth.cookieHeader, forHTTPHeaderField: "Cookie")
    request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      RequestBody(
        page: page, pageSize: pageSize, startDate: String(window.startMS),
        endDate: String(window.endMS)))

    let (bytes, response) = try await session.bytes(
      for: request, delegate: CursorTokenHistoryNoRedirects())
    guard let http = response as? HTTPURLResponse, http.url == endpoint else {
      throw CursorLocalConnectionIssue.invalidResponse
    }
    if http.statusCode == 401 || http.statusCode == 403 {
      throw CursorLocalConnectionIssue.signedOut
    }
    guard http.statusCode == 200 else {
      throw (300..<400).contains(http.statusCode)
        ? CursorLocalConnectionIssue.signedOut : CursorLocalConnectionIssue.unavailable
    }
    guard response.expectedContentLength <= Int64(maxResponseBytes) else {
      throw CursorLocalConnectionIssue.invalidResponse
    }
    var data = Data()
    if response.expectedContentLength > 0 {
      data.reserveCapacity(Int(response.expectedContentLength))
    }
    for try await byte in bytes {
      try Task.checkCancellation()
      guard clock.now < deadline, data.count < maxResponseBytes else {
        throw CursorLocalConnectionIssue.invalidResponse
      }
      data.append(byte)
    }
    try Task.checkCancellation()
    guard clock.now < deadline else { throw CursorLocalConnectionIssue.unavailable }
    return data
  }

  private static func decodePage(_ data: Data) throws -> Page {
    guard !data.isEmpty, data.count <= maxResponseBytes,
      let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { throw CursorLocalConnectionIssue.invalidResponse }
    if object.isEmpty { return Page(total: 0, events: []) }
    let allowedKeys: Set<String> = ["totalUsageEventsCount", "usageEventsDisplay"]
    guard Set(object.keys).isSubset(of: allowedKeys),
      let totalValue = exactInt64(object["totalUsageEventsCount"]), totalValue >= 0,
      let total = Int(exactly: totalValue)
    else { throw CursorLocalConnectionIssue.invalidResponse }
    guard let eventObjects = object["usageEventsDisplay"] else {
      guard object.count == 1 else { throw CursorLocalConnectionIssue.invalidResponse }
      return Page(total: total, events: [])
    }
    guard let array = eventObjects as? [Any], array.count <= pageSize else {
      throw CursorLocalConnectionIssue.invalidResponse
    }
    let events = try array.map { value -> Event in
      guard let event = value as? [String: Any],
        let timestamp = exactInt64(event["timestamp"]), timestamp > 0,
        let tokenUsage = event["tokenUsage"] as? [String: Any]
      else { throw CursorLocalConnectionIssue.invalidResponse }
      var tokens: Int64 = 0
      for key in ["inputTokens", "outputTokens", "cacheWriteTokens", "cacheReadTokens"] {
        guard let count = exactInt64(tokenUsage[key]), count >= 0 else {
          throw CursorLocalConnectionIssue.invalidResponse
        }
        let next = tokens.addingReportingOverflow(count)
        guard !next.overflow else { throw CursorLocalConnectionIssue.invalidResponse }
        tokens = next.partialValue
      }
      let canonical = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
      return Event(canonical: canonical, timestampMS: timestamp, tokens: tokens)
    }
    return Page(total: total, events: events)
  }

  private static func exactInt64(_ value: Any?) -> Int64? {
    if let string = value as? String { return Int64(string) }
    guard let number = value as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID()
    else { return nil }
    return Int64(number.stringValue)
  }

  private static func reconciledEvents(
    pages: [[Event]], expectedTotal: Int
  ) throws -> [Event] {
    let rawCount = pages.reduce(0) { $0 + $1.count }
    guard rawCount >= expectedTotal else { throw CursorLocalConnectionIssue.invalidResponse }
    if rawCount == expectedTotal { return pages.flatMap(\.self) }

    var removalsRemaining = rawCount - expectedTotal
    var reconciled = pages.first ?? []
    for index in pages.indices.dropFirst() {
      let page = pages[index]
      let overlap = boundaryOverlap(previous: pages[index - 1], current: page)
      let removalCount = min(overlap, removalsRemaining)
      reconciled.append(contentsOf: page.dropFirst(removalCount))
      removalsRemaining -= removalCount
    }
    guard removalsRemaining == 0, reconciled.count == expectedTotal else {
      throw CursorLocalConnectionIssue.invalidResponse
    }
    return reconciled
  }

  private static func boundaryOverlap(previous: [Event], current: [Event]) -> Int {
    let limit = min(previous.count, current.count)
    guard limit > 0 else { return 0 }
    for count in stride(from: limit, through: 1, by: -1) {
      var matches = true
      for offset in 0..<count
      where previous[previous.count - count + offset].canonical != current[offset].canonical {
        matches = false
        break
      }
      if matches { return count }
    }
    return 0
  }

  private static func usage(
    from events: [Event], window: Window, observedAt: Date
  ) throws -> TokenUsage {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var totals: [String: Int64] = [:]
    for event in events {
      guard event.timestampMS >= window.startMS, event.timestampMS < window.endMS else {
        throw CursorLocalConnectionIssue.invalidResponse
      }
      let date = Date(timeIntervalSince1970: Double(event.timestampMS) / 1_000)
      let components = calendar.dateComponents([.year, .month, .day], from: date)
      guard let year = components.year, let month = components.month, let day = components.day
      else { throw CursorLocalConnectionIssue.invalidResponse }
      let key = String(format: "%04d-%02d-%02d", year, month, day)
      let next = (totals[key] ?? 0).addingReportingOverflow(event.tokens)
      guard !next.overflow else { throw CursorLocalConnectionIssue.invalidResponse }
      totals[key] = next.partialValue
    }
    let days = totals.keys.sorted().map { TokenDay(day: $0, tokens: totals[$0]!) }
    return TokenUsage(
      state: .ready, observedAt: observedAt, days: days, dayBoundary: .utc)
  }

  private static func utcWindow(now: Date) throws -> Window {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let today = calendar.startOfDay(for: now)
    guard let start = calendar.date(byAdding: .day, value: -89, to: today),
      let end = calendar.date(byAdding: .day, value: 1, to: today)
    else { throw CursorLocalConnectionIssue.invalidResponse }
    return Window(
      startMS: Int64((start.timeIntervalSince1970 * 1_000).rounded()),
      endMS: Int64((end.timeIntervalSince1970 * 1_000).rounded()))
  }

  public static func decodeWebResult(
    from data: Data, cached: CursorTokenHistoryCache?, now: Date = .now
  ) -> CursorTokenHistoryWebResult {
    struct Envelope: Decodable {
      struct Identity: Decodable { let sub: String? }
      struct History: Decodable {
        let state: String
        let days: [TokenDay]?
      }
      let identity: Identity
      let history: History?
    }
    guard data.count <= 131_072,
      let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
      let subject = envelope.identity.sub,
      !subject.isEmpty, subject.utf8.count <= 1_024
    else {
      return CursorTokenHistoryWebResult(
        subject: nil, usage: TokenUsage(state: .unavailable, dayBoundary: .utc), cache: nil)
    }

    let usage: TokenUsage
    let resultCache: CursorTokenHistoryCache?
    switch envelope.history?.state {
    case "cached":
      if let cachedUsage = cached?.usage(for: subject, at: now) {
        usage = cachedUsage
        resultCache = cached
      } else {
        usage = TokenUsage(state: .unavailable, dayBoundary: .utc)
        resultCache = nil
      }
    case "ready":
      if let days = validatedDays(envelope.history?.days, now: now) {
        usage = TokenUsage(state: .ready, observedAt: now, days: days, dayBoundary: .utc)
      } else {
        usage = TokenUsage(state: .unavailable, dayBoundary: .utc)
      }
      resultCache = cache(subject: subject, usage: usage, now: now)
    default:
      usage = TokenUsage(state: .unavailable, dayBoundary: .utc)
      resultCache = cache(subject: subject, usage: usage, now: now)
    }
    return CursorTokenHistoryWebResult(
      subject: subject, usage: usage, cache: resultCache)
  }

  private static func validatedDays(_ input: [TokenDay]?, now: Date) -> [TokenDay]? {
    guard let input, input.count <= 90, let window = try? utcWindow(now: now) else { return nil }
    var seen: Set<String> = []
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    for day in input {
      guard day.tokens >= 0, day.day.utf8.count == 10,
        day.day.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil,
        seen.insert(day.day).inserted
      else { return nil }
      let parts = day.day.split(separator: "-").compactMap { Int($0) }
      guard parts.count == 3,
        let date = calendar.date(
          from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
      else { return nil }
      let components = calendar.dateComponents([.year, .month, .day], from: date)
      guard components.year == parts[0], components.month == parts[1], components.day == parts[2]
      else { return nil }
      let milliseconds = Int64((date.timeIntervalSince1970 * 1_000).rounded())
      guard milliseconds >= window.startMS, milliseconds < window.endMS else { return nil }
    }
    return input.sorted { $0.day < $1.day }
  }

  /// Runs inside CursorSignIn's isolated WKWebView profile. Same-origin fetch adds
  /// the required Origin header without exposing the session cookie to Swift.
  public static let webKitScript = """
    if (location.origin !== 'https://cursor.com' || !location.pathname.startsWith('/dashboard')) return null;
    const MAX_BYTES = 4194304, PAGE_SIZE = 1000, MAX_PAGES = 20, MAX_EVENTS = 20000;
    const parseResponse = async (response, maxBytes) => {
      if (response.status === 401 || response.status === 403) throw new Error('signed_out');
      if (!response.ok) throw new Error('unavailable');
      const declared = response.headers.get('Content-Length');
      if (declared !== null && (!/^[0-9]+$/.test(declared)
        || !Number.isSafeInteger(Number(declared)) || Number(declared) > maxBytes))
        throw new Error('schema');
      if (!response.body) throw new Error('schema');
      const reader = response.body.getReader(), chunks = [];
      let total = 0;
      while (true) {
        const {done, value} = await reader.read();
        if (done) break;
        if (!(value instanceof Uint8Array) || total + value.byteLength > maxBytes) {
          await reader.cancel().catch(() => {});
          throw new Error('schema');
        }
        chunks.push(value);
        total += value.byteLength;
      }
      const bytes = new Uint8Array(total);
      let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
      return JSON.parse(new TextDecoder().decode(bytes));
    };
    const read = async (path, signal) => parseResponse(await fetch(path, {
      credentials:'same-origin', cache:'no-store', redirect:'error',
      headers:{Accept:'application/json'}, signal
    }), 65536);
    const readPage = async (page, startDate, endDate, signal) => {
      const response = await fetch('/api/dashboard/get-filtered-usage-events', {
        method:'POST', credentials:'same-origin', cache:'no-store', redirect:'error',
        headers:{Accept:'application/json','Content-Type':'application/json'}, signal,
        body:JSON.stringify({page, pageSize:PAGE_SIZE, startDate:String(startDate), endDate:String(endDate)})
      });
      return parseResponse(response, MAX_BYTES);
    };
    const stable = (value) => {
      if (Array.isArray(value)) return '[' + value.map(stable).join(',') + ']';
      if (value && typeof value === 'object') return '{' + Object.keys(value).sort()
        .map(key => JSON.stringify(key) + ':' + stable(value[key])).join(',') + '}';
      return JSON.stringify(value);
    };
    const checkedCount = (value) => {
      if (!Number.isSafeInteger(value) || value < 0) throw new Error('schema');
      return value;
    };
    const decodePage = (value) => {
      if (!value || Array.isArray(value) || typeof value !== 'object') throw new Error('schema');
      const keys = Object.keys(value);
      if (keys.length === 0) return {total:0, events:[]};
      if (keys.some(key => key !== 'totalUsageEventsCount' && key !== 'usageEventsDisplay'))
        throw new Error('schema');
      const total = checkedCount(value.totalUsageEventsCount);
      if (!Object.prototype.hasOwnProperty.call(value, 'usageEventsDisplay')) {
        if (keys.length !== 1) throw new Error('schema');
        return {total, events:[]};
      }
      if (!Array.isArray(value.usageEventsDisplay) || value.usageEventsDisplay.length > PAGE_SIZE)
        throw new Error('schema');
      const events = value.usageEventsDisplay.map(event => {
        if (!event || Array.isArray(event) || typeof event !== 'object') throw new Error('schema');
        if (typeof event.timestamp !== 'string' || !/^[0-9]+$/.test(event.timestamp))
          throw new Error('schema');
        const timestamp = Number(event.timestamp);
        if (!Number.isSafeInteger(timestamp) || timestamp <= 0) throw new Error('schema');
        const token = event.tokenUsage;
        if (!token || Array.isArray(token) || typeof token !== 'object') throw new Error('schema');
        let tokens = 0;
        for (const key of ['inputTokens','outputTokens','cacheWriteTokens','cacheReadTokens']) {
          tokens += checkedCount(token[key]);
          if (!Number.isSafeInteger(tokens)) throw new Error('schema');
        }
        return {key:stable(event), timestamp, tokens};
      });
      return {total, events};
    };
    const overlap = (previous, current) => {
      const limit = Math.min(previous.length, current.length);
      outer: for (let count = limit; count >= 1; count--) {
        for (let offset = 0; offset < count; offset++) {
          if (previous[previous.length - count + offset].key !== current[offset].key) continue outer;
        }
        return count;
      }
      return 0;
    };
    const fetchHistory = async (signal) => {
      const today = new Date();
      today.setUTCHours(0, 0, 0, 0);
      const startDate = today.getTime() - 89 * 86400000;
      const endDate = today.getTime() + 86400000;
      const pages = [];
      let expected = null, completed = false;
      for (let pageNumber = 1; pageNumber <= MAX_PAGES; pageNumber++) {
        const page = decodePage(await readPage(pageNumber, startDate, endDate, signal));
        if (expected !== null && expected !== page.total) throw new Error('schema');
        expected = page.total;
        if (expected > MAX_EVENTS) throw new Error('incomplete');
        if (page.events.length === 0) { completed = true; break; }
        pages.push(page.events);
        if (page.events.length < PAGE_SIZE) { completed = true; break; }
      }
      if (!completed || expected === null) throw new Error('incomplete');
      const rawCount = pages.reduce((sum, page) => sum + page.length, 0);
      if (rawCount < expected) throw new Error('incomplete');
      let remaining = rawCount - expected;
      const reconciled = pages.length ? [...pages[0]] : [];
      for (let index = 1; index < pages.length; index++) {
        const remove = Math.min(overlap(pages[index - 1], pages[index]), remaining);
        reconciled.push(...pages[index].slice(remove));
        remaining -= remove;
      }
      if (remaining !== 0 || reconciled.length !== expected) throw new Error('incomplete');
      const totals = new Map();
      for (const event of reconciled) {
        if (event.timestamp < startDate || event.timestamp >= endDate) throw new Error('schema');
        const day = new Date(event.timestamp).toISOString().slice(0, 10);
        const total = (totals.get(day) || 0) + event.tokens;
        if (!Number.isSafeInteger(total)) throw new Error('schema');
        totals.set(day, total);
      }
      const days = [...totals.entries()].sort(([left], [right]) => left.localeCompare(right))
        .map(([day, tokens]) => ({day, tokens}));
      return {state:'ready', days};
    };
    let quotaTimer = null, historyTimer = null, verificationTimer = null;
    try {
      const quotaController = new AbortController();
      quotaTimer = setTimeout(() => quotaController.abort(), 12000);
      const [usage, me] = await Promise.all([
        read('/api/usage-summary', quotaController.signal),
        read('/api/auth/me', quotaController.signal)
      ]);
      clearTimeout(quotaTimer);
      quotaTimer = null;
      const subject = typeof me.sub === 'string' && me.sub.length <= 1024 ? me.sub : null;
      let history = {state:'unavailable'};
      if (subject && cachedSubject === subject) {
        history = {state:'cached'};
      } else if (subject) {
        const historyController = new AbortController();
        historyTimer = setTimeout(() => historyController.abort(), 15000);
        try { history = await fetchHistory(historyController.signal); }
        catch (_) { history = {state:'unavailable'}; }
        clearTimeout(historyTimer);
        historyTimer = null;

        // History is optional, but the account check is not. Give it a fresh
        // budget even when paging timed out or failed schema validation.
        const verificationController = new AbortController();
        verificationTimer = setTimeout(() => verificationController.abort(), 5000);
        const verified = await read('/api/auth/me', verificationController.signal);
        if (verified.sub !== subject) throw new Error('account_changed');
        clearTimeout(verificationTimer);
        verificationTimer = null;
      }
      const plan = usage.individualUsage?.plan;
      const spend = usage.individualUsage?.onDemand;
      const overall = usage.individualUsage?.overall;
      return JSON.stringify({usage: {
        billingCycleStart:usage.billingCycleStart, billingCycleEnd:usage.billingCycleEnd,
        membershipType:usage.membershipType, isUnlimited:usage.isUnlimited,
        individualUsage: {
          plan: plan ? {enabled:plan.enabled, used:plan.used, limit:plan.limit,
            autoPercentUsed:plan.autoPercentUsed, apiPercentUsed:plan.apiPercentUsed,
            totalPercentUsed:plan.totalPercentUsed} : null,
          onDemand: spend ? {enabled:spend.enabled, used:spend.used, limit:spend.limit} : null,
          overall: overall ? {enabled:overall.enabled, used:overall.used, limit:overall.limit} : null
        }}, identity:{sub:me.sub, email:me.email}, history});
    } catch (error) {
      return error.message === 'signed_out' || error.message === 'account_changed'
        ? 'signed_out' : 'unavailable';
    } finally {
      if (quotaTimer !== null) clearTimeout(quotaTimer);
      if (historyTimer !== null) clearTimeout(historyTimer);
      if (verificationTimer !== null) clearTimeout(verificationTimer);
    }
    """
}

private final class CursorTokenHistoryNoRedirects: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest
  ) async -> URLRequest? { nil }
}

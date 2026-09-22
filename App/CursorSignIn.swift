import AllowanceConnectors
import AllowanceCore
import AppKit
import WebKit

@MainActor
final class CursorSignIn: NSObject, WKNavigationDelegate {
  private let webView: WKWebView
  private let window: NSWindow
  private var message: ((String) -> Void)?
  private var trustedDashboard: Bool {
    webView.url?.scheme == "https" && webView.url?.host == "cursor.com"
      && webView.url?.path.hasPrefix("/dashboard") == true
  }
  private var lastGood: AgentSnapshot?
  private var tokenCache: CursorTokenHistoryCache?
  var didConnect: (() -> Void)?

  init(message: @escaping (String) -> Void) {
    self.message = message
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = WKWebsiteDataStore(
      forIdentifier: UUID(uuidString: "7A30CE67-3C03-4C7D-BB98-109681C8E267")!)
    webView = WKWebView(frame: .zero, configuration: configuration)
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 980, height: 760),
      styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false
    )
    super.init()
    window.title = "Cursor — \(AppIdentity.name)"
    window.isReleasedWhenClosed = false
    window.contentView = webView
    webView.navigationDelegate = self
  }

  func show() {
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    if webView.url == nil {
      webView.load(URLRequest(url: URL(string: "https://cursor.com/dashboard")!))
    }
    message?(
      localized(
        "Завершите вход в открывшемся окне Cursor.", "Complete sign-in in the Cursor window."))
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if trustedDashboard { didConnect?() }
  }
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async
    -> WKNavigationActionPolicy
  {
    guard let url = navigationAction.request.url else { return .cancel }
    // Authentication redirects may use other HTTPS origins; they are never scraped.
    guard url.scheme == "https" || url.absoluteString == "about:blank" else { return .cancel }
    return .allow
  }
  func readSnapshot() async -> AgentSnapshot? {
    guard trustedDashboard else { return nil }
    // Executed in an isolated JS world. Cookies remain entirely inside this WebKit profile.
    let now = Date.now
    do {
      let result = try await webView.callAsyncJavaScript(
        CursorTokenHistory.webKitScript,
        arguments: ["cachedSubject": tokenCache?.subject(at: now) ?? ""], in: nil,
        contentWorld: .defaultClient)
      guard trustedDashboard, let json = result as? String else { return failed(.unavailable) }
      if json == "signed_out" {
        lastGood = nil
        tokenCache = nil
        return failed(.signedOut)
      }
      guard json != "unavailable" else { return failed(.unavailable) }
      let data = Data(json.utf8)
      var snapshot = try CursorProjection.snapshot(from: data)
      let history = CursorTokenHistory.decodeWebResult(from: data, cached: tokenCache, now: now)
      snapshot.tokenUsage = history.usage
      tokenCache = history.cache
      lastGood = snapshot
      message?(
        snapshot.state == .ready
          ? localized(
            "Личная квота подключена.",
            "Personal usage connected.")
          : localized(
            "Вход выполнен, но dashboard не вернул измеримую личную квоту.",
            "Signed in, but the dashboard returned no measurable personal allowance."))
      return snapshot
    } catch ConnectorError.signedOut {
      lastGood = nil
      tokenCache = nil
      return failed(.signedOut)
    } catch { return failed(.unavailable) }
  }
  func resume() {
    if webView.url == nil {
      webView.load(URLRequest(url: URL(string: "https://cursor.com/dashboard")!))
    }
  }
  func suspend() {
    // An awaited WebKit read can still finish after stopLoading(). It must not
    // overwrite the connection message of a newly selected source.
    message = nil
    didConnect = nil
    lastGood = nil
    tokenCache = nil
    webView.stopLoading()
    window.orderOut(nil)
  }
  func signOut() async {
    lastGood = nil
    tokenCache = nil
    webView.stopLoading()
    webView.loadHTMLString("", baseURL: nil)
    await webView.configuration.websiteDataStore.removeData(
      ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    window.orderOut(nil)
  }
  private func failed(_ state: SourceState) -> AgentSnapshot {
    message?(
      state == .signedOut
        ? localized("Нужно повторить вход в Cursor.", "Please sign in to Cursor again.")
        : localized(
          "Не удалось прочитать Cursor. Последнее значение не считается актуальным.",
          "Could not read Cursor. The previous value is not considered live."))
    if state != .signedOut, var previous = lastGood {
      previous.state = .stale
      return previous
    }
    if state == .signedOut { tokenCache = nil }
    return AgentSnapshot(agent: .cursor, state: state, source: "Cursor Dashboard")
  }
}

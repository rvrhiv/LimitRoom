import AllowanceConnectors
import AllowanceCore
import AllowanceRuntime
import AllowanceStorage
import AppKit
import Observation
import WidgetKit

@MainActor @Observable
final class AppModel {
  let isDemo: Bool
  let presentation: PresentationPreferences
  let updates: UpdateController
  var settingsPage = SettingsPage.appearance
  var settingsAgent = AgentID.codex
  var snapshots: [AgentSnapshot] = AgentID.allCases.map { AgentSnapshot(agent: $0) }
  var samples: [HistorySample] = []
  var selection: WindowSelection?
  var chartSelections: [AgentID: String] = [:]
  var isRefreshing = false
  var errorMessage: String?
  var codexPath: String
  var notificationsEnabled: Bool
  var onboardingComplete: Bool
  var wantsLoginItem = true
  var historyDays = 7
  var displayDate = Date.now
  var cursorSignIn: CursorSignIn?
  var cursorMessage: String?
  var cursorDisconnecting = false
  private(set) var cursorUsesLocalSession = false
  private(set) var cursorConnecting = false
  var claudeMessage: String?
  var claudeConnecting = false
  var claudeConfigured = false
  var claudeManaged = false

  @ObservationIgnored private let history: HistoryStore?
  @ObservationIgnored private let monitor: AllowanceMonitor
  @ObservationIgnored private let cacheStore: SnapshotCacheStore
  @ObservationIgnored private let defaults = UserDefaults.standard
  @ObservationIgnored private var loop: Task<Void, Never>?
  @ObservationIgnored private var wakeObserver: NSObjectProtocol?
  @ObservationIgnored private var lastRefresh = Date.distantPast
  @ObservationIgnored private var refreshAgain = false
  @ObservationIgnored private var configurationGeneration = 0
  @ObservationIgnored private var previousFresh: [String: Double] = [:]
  @ObservationIgnored private var notified: Set<String> = []
  @ObservationIgnored private let cursorLocal = CursorLocalConnector()
  let dataDirectory: URL
  var claudeScope: String

  init() {
    isDemo = CommandLine.arguments.contains("--demo")
    updates = UpdateController(isDemo: isDemo)
    presentation = PresentationPreferences(isDemo: isDemo)
    let preferences = UserDefaults.standard
    codexPath = preferences.string(forKey: "codexPath") ?? ""
    notificationsEnabled = preferences.bool(forKey: "notificationsEnabled")
    onboardingComplete = preferences.bool(forKey: "onboardingComplete")
    let storageDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Application Support/LimitRoom", isDirectory: true)
    let connectionScope =
      (isDemo ? nil : ClaudeConnectionStore.read(directory: storageDirectory))
      ?? preferences.string(forKey: "claudeScope") ?? UUID().uuidString
    claudeScope = connectionScope
    if !isDemo { preferences.set(connectionScope, forKey: "claudeScope") }
    dataDirectory = storageDirectory
    var storage: HistoryStore?
    var initialError: String?
    if !isDemo {
      do {
        storage = try HistoryStore(url: dataDirectory.appendingPathComponent("history.sqlite"))
        try ClaudeConnectionStore.write(scope: connectionScope, directory: dataDirectory)
      } catch {
        initialError = localized(
          "Не удалось открыть историю. Новые показания пока не сохраняются.",
          "History could not be opened. New readings are not being saved.")
      }
    }
    history = storage
    cacheStore = SnapshotCacheStore(directory: dataDirectory)
    // Cursor's current account is unknown until its explicitly selected source is
    // validated. Do not briefly show another account from yesterday's disk cache.
    let initial = isDemo ? [] : cacheStore.read().filter { $0.agent != .cursor }
    monitor = AllowanceMonitor(
      connectors: [
        CodexConnector(
          executable: ExecutableLocator.find(
            "codex", explicit: preferences.string(forKey: "codexPath"))),
        ClaudeConnector(
          file: dataDirectory.appendingPathComponent("claude-statusline.json"),
          expectedScope: connectionScope),
      ], history: storage, initial: initial)
    errorMessage = initialError
    if let data = preferences.data(forKey: "pinnedWindow") {
      selection = try? JSONDecoder().decode(WindowSelection.self, from: data)
    }
    if let data = preferences.data(forKey: "chartWindows"),
      let saved = try? JSONDecoder().decode([String: String].self, from: data)
    {
      chartSelections = Dictionary(
        uniqueKeysWithValues: saved.compactMap { key, value in
          AgentID(rawValue: key).map { ($0, value) }
        })
    }
    if isDemo {
      loadDemo()
      return
    }
    snapshots = AgentID.allCases.map { agent in
      initial.first { $0.agent == agent } ?? AgentSnapshot(agent: agent)
    }
    claudeConfigured = claudeSetup.isInstalled(scope: claudeScope)
    claudeManaged = claudeSetup.hasManagedSettings
    if claudeManaged && !claudeConfigured {
      claudeMessage = localized(
        "Подключение требует восстановления. Нажмите «Подключить» или завершите отключение в настройках.",
        "The connection needs recovery. Connect again or finish disconnecting in Settings.")
    }
    notified = Set(preferences.stringArray(forKey: "notifiedCrossings") ?? [])
    cursorUsesLocalSession = preferences.bool(forKey: "cursorLocalSessionEnabled")
    if !cursorUsesLocalSession, preferences.bool(forKey: "cursorConnected") {
      prepareCursor().resume()
    }
    loop = Task { [weak self] in
      await self?.refresh()
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(30)) } catch { break }
        guard let self else { break }
        self.displayDate = .now
        if Date.now.timeIntervalSince(self.lastRefresh) >= 300 { await self.refresh() }
      }
    }
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in await self?.refresh() }
    }
  }

  var pinned: (AgentSnapshot, AllowanceWindow)? {
    guard let selection, let snapshot = snapshots.first(where: { $0.agent == selection.agent }),
      let window = snapshot.windows.first(where: { $0.id == selection.windowID })
    else { return nil }
    return (snapshot, window)
  }
  var rates: [UsageRate] {
    let cutoff = Date.now.addingTimeInterval(-Double(historyDays) * 86400)
    let currentScopes = Dictionary(
      uniqueKeysWithValues: snapshots.compactMap { snapshot in
        snapshot.accountScope.map { (snapshot.agent, $0) }
      })
    return TrendCalculator.rates(
      from: samples.filter {
        $0.observedAt >= cutoff && $0.accountScope == currentScopes[$0.agent]
          && chartSelections[$0.agent] == $0.windowID
      })
  }

  func refresh() async {
    guard !isDemo, !isRefreshing, !cursorConnecting, !cursorDisconnecting,
      Date.now.timeIntervalSince(lastRefresh) >= 15
    else { return }
    isRefreshing = true
    let generation = configurationGeneration
    defer {
      isRefreshing = false
      if refreshAgain {
        refreshAgain = false
        lastRefresh = .distantPast
        Task { await refresh() }
      }
    }
    lastRefresh = .now
    var updated = await monitor.refresh()
    if cursorUsesLocalSession {
      let cursorSnapshot = await cursorLocal.read()
      let issue = await cursorLocal.issue
      guard generation == configurationGeneration, cursorUsesLocalSession else {
        refreshAgain = true
        return
      }
      cursorMessage = cursorConnectionMessage(snapshot: cursorSnapshot, issue: issue)
      await monitor.accept(cursorSnapshot)
      updated = await monitor.current()
    } else if let signIn = cursorSignIn, let cursorSnapshot = await signIn.readSnapshot(),
      cursorSignIn === signIn, generation == configurationGeneration
    {
      await monitor.accept(cursorSnapshot)
      updated = await monitor.current()
    }
    guard generation == configurationGeneration else {
      refreshAgain = true
      return
    }
    snapshots = AgentID.allCases.compactMap { agent in updated.first { $0.agent == agent } }
    chooseInitialWindows()
    do {
      let readings = try await history?.samples() ?? []
      guard generation == configurationGeneration else {
        refreshAgain = true
        return
      }
      samples = readings
    } catch { errorMessage = localized("Не удалось прочитать историю.", "Could not read history.") }
    let storageFailed = await monitor.storageFailed
    guard generation == configurationGeneration else {
      refreshAgain = true
      return
    }
    if storageFailed {
      errorMessage = localized(
        "Не все показания удалось сохранить.", "Some readings could not be saved.")
    }
    await notifyThresholds(generation: generation)
    guard generation == configurationGeneration else {
      refreshAgain = true
      return
    }
    do { try cacheStore.write(snapshots) } catch {
      errorMessage = localized(
        "Не удалось сохранить последние показания.", "Could not cache the latest readings.")
    }
    publishWidget()
  }

  func pin(agent: AgentID, window: AllowanceWindow) {
    selection = WindowSelection(agent: agent, windowID: window.id)
    if !isDemo { defaults.set(try? JSONEncoder().encode(selection), forKey: "pinnedWindow") }
    publishWidget()
  }
  func setChartWindow(_ id: String, agent: AgentID) {
    chartSelections[agent] = id
    if !isDemo {
      let serialized = Dictionary(
        uniqueKeysWithValues: chartSelections.map { ($0.key.rawValue, $0.value) })
      defaults.set(try? JSONEncoder().encode(serialized), forKey: "chartWindows")
    }
  }
  func applyCodexPath() async {
    guard !isDemo else { return }
    configurationGeneration += 1
    defaults.set(codexPath, forKey: "codexPath")
    await monitor.replaceConnectors([
      CodexConnector(executable: ExecutableLocator.find("codex", explicit: codexPath)),
      ClaudeConnector(
        file: dataDirectory.appendingPathComponent("claude-statusline.json"),
        expectedScope: claudeScope),
    ])
    lastRefresh = .distantPast
    if isRefreshing {
      refreshAgain = true
      return
    }
    await refresh()
  }
  func connectLocalCursor() async {
    guard !isDemo, !cursorDisconnecting, !cursorConnecting else { return }
    cursorConnecting = true
    configurationGeneration += 1
    cursorUsesLocalSession = true
    defaults.set(true, forKey: "cursorLocalSessionEnabled")
    defaults.set(false, forKey: "cursorConnected")
    cursorSignIn?.suspend()
    cursorSignIn = nil
    await clearCursorReading()
    cursorMessage = localized(
      "Подключаем аккаунт Cursor.app…", "Connecting the Cursor.app account…")
    cursorConnecting = false
    await requestCursorRefresh()
  }

  func connectCursor() async {
    guard !isDemo, !cursorDisconnecting, !cursorConnecting else { return }
    cursorConnecting = true
    configurationGeneration += 1
    cursorUsesLocalSession = false
    defaults.set(false, forKey: "cursorLocalSessionEnabled")
    defaults.set(true, forKey: "cursorConnected")
    await clearCursorReading()
    cursorConnecting = false
    prepareCursor().show()
  }
  private func prepareCursor() -> CursorSignIn {
    if let cursorSignIn { return cursorSignIn }
    let signIn = CursorSignIn { [weak self] message in self?.cursorMessage = message }
    signIn.didConnect = { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.lastRefresh = .distantPast
        if self.isRefreshing {
          self.refreshAgain = true
          return
        }
        await self.refresh()
      }
    }
    cursorSignIn = signIn
    return signIn
  }
  func disconnectCursor() async {
    guard !isDemo, !cursorDisconnecting, !cursorConnecting else { return }
    configurationGeneration += 1
    cursorDisconnecting = true
    defer { cursorDisconnecting = false }
    cursorUsesLocalSession = false
    defaults.set(false, forKey: "cursorLocalSessionEnabled")
    defaults.set(false, forKey: "cursorConnected")
    let signIn = cursorSignIn
    signIn?.suspend()
    cursorSignIn = nil
    await signIn?.signOut()
    await clearCursorReading()
    cursorMessage = localized(
      "Cursor отключён от LimitRoom. Вход в Cursor.app и история сохранены.",
      "Cursor disconnected from LimitRoom. Cursor.app sign-in and history are unchanged.")
  }

  private func clearCursorReading() async {
    await cursorLocal.reset()
    await monitor.forget(.cursor)
    snapshots.removeAll { $0.agent == .cursor }
    snapshots.append(AgentSnapshot(agent: .cursor))
    try? cacheStore.write(snapshots)
    publishWidget()
  }

  private func requestCursorRefresh() async {
    lastRefresh = .distantPast
    if isRefreshing { refreshAgain = true } else { await refresh() }
  }

  private func cursorConnectionMessage(
    snapshot: AgentSnapshot, issue: CursorLocalConnectionIssue?
  ) -> String {
    switch issue {
    case .noSession:
      localized(
        "Сначала войдите в установленный Cursor, затем повторите подключение.",
        "Sign in to the installed Cursor app, then connect again.")
    case .storageUnavailable:
      localized(
        "Не удалось прочитать вход Cursor.app. Проверьте, что приложение установлено, и повторите подключение.",
        "Could not read Cursor.app sign-in. Check that the app is installed and connect again.")
    case .expiredSession, .invalidSession, .signedOut:
      localized(
        "Вход Cursor.app истёк или отклонён. Обновите вход в самом Cursor, затем повторите подключение.",
        "Cursor.app sign-in expired or was rejected. Sign in again within Cursor, then reconnect.")
    case .accountChanged:
      localized(
        "Аккаунт Cursor изменился во время обновления. Старые показания скрыты; повторите подключение.",
        "Cursor account changed during refresh. Previous readings are hidden; connect again.")
    case .invalidResponse:
      localized(
        "Cursor вернул неизвестный формат данных. Источник экспериментальный; проверьте личную квоту на dashboard.",
        "Cursor returned an unknown data format. This source is experimental; check your personal dashboard."
      )
    case .unavailable:
      localized(
        "Не удалось обновить Cursor. Последнее показание, если оно есть, помечено устаревшим.",
        "Could not refresh Cursor. Any previous reading is marked stale.")
    case nil:
      snapshot.state == .unsupported
        ? localized(
          "Вход Cursor.app подтверждён, но сервер не вернул измеримую личную квоту.",
          "Cursor.app sign-in confirmed, but the server returned no measurable personal allowance.")
        : localized(
          "Подключён аккаунт Cursor.app. Квота и подписка получены от Cursor; источник экспериментальный.",
          "Cursor.app account connected. Usage and subscription come from Cursor; this source is experimental."
        )
    }
  }
  func reconnectClaude() async {
    guard !isDemo, !claudeConnecting else { return }
    claudeConnecting = true
    defer { claudeConnecting = false }
    let reinstall = claudeManaged
    do {
      try await rotateClaudeScope()
      if reinstall {
        try await installClaudeBridge()
      } else {
        claudeMessage = localized(
          "Аккаунт отделён. Подключите Claude или обновите ручную команду statusLine, затем перезапустите Claude Code.",
          "Account history separated. Connect Claude or update the manual statusLine command, then restart Claude Code."
        )
      }
    } catch { reconcileClaudeSetupFailure(error) }
  }

  private func rotateClaudeScope() async throws {
    let scope = UUID().uuidString
    try ClaudeConnectionStore.write(scope: scope, directory: dataDirectory)
    configurationGeneration += 1
    claudeScope = scope
    claudeConfigured = false
    defaults.set(claudeScope, forKey: "claudeScope")
    await monitor.forget(.claude)
    await applyCodexPath()
  }

  var claudeSettingsURL: URL {
    let configured = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
    let directory =
      configured.flatMap { path -> URL? in
        guard path.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
      }
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
        ".claude", isDirectory: true)
    return directory.appendingPathComponent("settings.json")
  }

  private var claudeSetup: ClaudeSetup {
    ClaudeSetup(
      settingsURL: claudeSettingsURL, directory: dataDirectory,
      helperURL: Bundle.main.bundleURL.appendingPathComponent(
        "Contents/Helpers/limitroom-claude-bridge"))
  }

  func connectClaude() async {
    guard !isDemo, !claudeConnecting else { return }
    claudeConnecting = true
    defer { claudeConnecting = false }
    do {
      try await installClaudeBridge()
    } catch { reconcileClaudeSetupFailure(error) }
  }

  /// Caller owns claudeConnecting across the entire operation, including refresh.
  private func installClaudeBridge() async throws {
    let setup = claudeSetup
    let scope = claudeScope
    try await Task.detached(priority: .utility) { try setup.install(scope: scope) }.value
    claudeConfigured = true
    claudeManaged = true
    claudeMessage = localized(
      "Настроено. Перезапустите Claude Code, дождитесь ответа агента и обновите показания. Существующая строка статуса сохранена.",
      "Configured. Restart Claude Code, wait for an agent response, then refresh readings. Your existing status line is preserved."
    )
    lastRefresh = .distantPast
    if isRefreshing { refreshAgain = true } else { await refresh() }
  }

  func disconnectClaude() async {
    guard !isDemo, !claudeConnecting else { return }
    claudeConnecting = true
    defer { claudeConnecting = false }
    do {
      let setup = claudeSetup
      // Invalidate producers FIRST. If this fails, settings are still managed and
      // retryable. If removal fails afterward, old terminals are already blocked;
      // hasManagedSettings keeps Disconnect available, including after a restart.
      try await rotateClaudeScope()
      try await Task.detached(priority: .utility) { try setup.uninstall() }.value
      claudeConfigured = false
      claudeManaged = false
      claudeMessage = localized(
        "Отключено. Предыдущая строка статуса восстановлена, история и резервные копии сохранены.",
        "Disconnected. The previous status line is restored; history and backups are retained.")
    } catch { reconcileClaudeSetupFailure(error) }
  }

  private func reconcileClaudeSetupFailure(_ error: Error) {
    claudeConfigured = claudeSetup.isInstalled(scope: claudeScope)
    claudeManaged = claudeSetup.hasManagedSettings
    claudeMessage = claudeSetupMessage(error)
    if claudeManaged && !claudeConfigured {
      claudeMessage =
        localized(
          "Квоты старого подключения остановлены. Восстановите подключение или повторите отключение. ",
          "Readings from the old connection are stopped. Reconnect or retry disconnecting. ")
        + (claudeMessage ?? "")
    }
  }

  private func claudeSetupMessage(_ error: Error) -> String {
    switch error as? ClaudeSetupError {
    case .helperMissing:
      localized(
        "Запустите собранное приложение LimitRoom.app: в нём есть модуль подключения.",
        "Run the built LimitRoom.app, which includes the connection helper.")
    case .invalidSettings:
      localized(
        "Настройки Claude содержат некорректный JSON. Файл не изменён.",
        "Claude settings contain invalid JSON. The file was not changed.")
    case .unsupportedStatusLine, .unmanagedBridge:
      localized(
        "Обнаружена нестандартная или ручная настройка statusLine. Используйте ручное подключение; существующая команда не заменена.",
        "A custom or manual statusLine integration was found. Use manual setup; the existing command was not replaced."
      )
    case .changedElsewhere, .otherConfiguration, .notInstalled:
      localized(
        "Настройки изменены вне LimitRoom или относятся к другой папке Claude. Автозамена остановлена; проверьте подключение.",
        "Settings were changed outside LimitRoom or belong to another Claude directory. Automatic replacement stopped; check the connection."
      )
    case .unsafeFile:
      localized(
        "Автонастройка не поддерживает ссылки и файлы больше 4 МБ. Проверьте путь и права доступа.",
        "Automatic setup does not support symlinks or files over 4 MB. Check the path and access permissions."
      )
    case nil:
      localized(
        "Не удалось настроить Claude. Проверьте права на settings.json. Резервные копии находятся в папке данных LimitRoom.",
        "Could not configure Claude. Check settings.json permissions. Backups are in LimitRoom's data folder."
      )
    }
  }
  func finishOnboarding() {
    onboardingComplete = true
    guard !isDemo else { return }
    defaults.set(true, forKey: "onboardingComplete")
    if wantsLoginItem {
      do { try PlatformSettings.setLaunchAtLogin(true) } catch {
        errorMessage = localized(
          "Автозапуск нужно подтвердить в настройках macOS.",
          "Confirm launch at login in macOS Settings.")
      }
    }
  }
  func setNotifications(_ enabled: Bool) async {
    guard !isDemo else { return }
    let allowed = enabled ? await PlatformSettings.requestNotifications() : false
    notificationsEnabled = allowed
    defaults.set(allowed, forKey: "notificationsEnabled")
    if enabled && !allowed {
      errorMessage = localized(
        "Разрешите уведомления LimitRoom в настройках macOS.",
        "Allow LimitRoom notifications in macOS Settings.")
    }
  }
  func clearHistory() async {
    guard !isDemo else { return }
    do {
      try await history?.removeAll()
      samples = []
    } catch { errorMessage = localized("Не удалось удалить историю.", "Could not clear history.") }
  }
  func export(to url: URL, csv: Bool) async {
    guard !isDemo, let history else { return }
    do {
      let data: Data
      if csv { data = try await history.exportCSV() } else { data = try await history.exportJSON() }
      try data.write(to: url, options: .atomic)
    } catch {
      errorMessage = localized("Не удалось экспортировать историю.", "Could not export history.")
    }
  }

  private func chooseInitialWindows() {
    // Never silently switch an existing pin when a source temporarily omits its window.
    for snapshot in snapshots where chartSelections[snapshot.agent] == nil {
      if let window = snapshot.windows.max(by: {
        ($0.durationMinutes ?? 0) < ($1.durationMinutes ?? 0)
      }) {
        setChartWindow(window.id, agent: snapshot.agent)
      }
    }
    if selection == nil, let codex = snapshots.first(where: { $0.agent == .codex }),
      let window = codex.windows.max(by: { ($0.durationMinutes ?? 0) < ($1.durationMinutes ?? 0) })
    {
      pin(agent: .codex, window: window)
    }
  }
  private func publishWidget() {
    guard !isDemo,
      let group = Bundle.main.object(forInfoDictionaryKey: "LimitRoomAppGroup") as? String,
      !group.isEmpty, !group.hasPrefix("."), !group.contains("$("),
      let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    else { return }
    do {
      try WidgetSnapshotStore(container: container).write(
        WidgetSnapshot(snapshots: snapshots, pinned: selection))
      WidgetCenter.shared.reloadAllTimelines()
    } catch {
      errorMessage = localized(
        "Не удалось обновить данные виджета.", "Could not update widget data.")
    }
  }
  private func notifyThresholds(generation: Int) async {
    for snapshot in snapshots {
      guard generation == configurationGeneration else { return }
      guard let scope = snapshot.accountScope else { continue }
      for window in snapshot.windows {
        guard generation == configurationGeneration else { return }
        guard snapshot.windowIsFresh(window), let remaining = window.remainingPercent,
          let cycle = window.cycleKey
        else { continue }
        let key =
          "\(snapshot.agent.rawValue)/\(scope)/\(window.id)/\(snapshot.plan ?? "unknown")/\(cycle)"
        let previous = previousFresh[key]
        previousFresh[key] = remaining
        guard notificationsEnabled, let previous else { continue }
        for threshold in [10.0, 20.0] {
          let event = "\(key)/\(threshold)"
          if previous > threshold, remaining <= threshold, !notified.contains(event) {
            notified.insert(event)
            await PlatformSettings.notify(
              id: event, title: snapshot.agent.title,
              body: localized("Осталось ", "Remaining: ") + "\(Int(remaining))% · \(window.title). "
                + resetLabel(window.resetsAt))
            guard generation == configurationGeneration else { return }
            // One notification for a large crossing, not one for every skipped threshold.
            for crossed in [10.0, 20.0] where remaining <= crossed {
              notified.insert("\(key)/\(crossed)")
            }
            defaults.set(Array(notified.suffix(512)), forKey: "notifiedCrossings")
            break
          }
        }
      }
    }
  }
  private func loadDemo() {
    let now = Date.now
    let values: [(AgentID, String, Double, Double)] = [
      (.codex, "Pro", 32, 56), (.claude, "Max", 18, 37), (.cursor, "Pro", 45, 24),
    ]
    snapshots = values.map { agent, plan, session, period in
      AgentSnapshot(
        agent: agent, accountScope: "demo-\(agent.rawValue)", accountLabel: "Demo account",
        plan: plan,
        windows: [
          AllowanceWindow(
            id: "session", title: agent == .cursor ? "Cursor Models" : "5h", usedPercent: session,
            durationMinutes: 300, resetsAt: now.addingTimeInterval(9900), kind: .fixed),
          AllowanceWindow(
            id: "period", title: agent == .cursor ? "Other Models · 30d" : "7d",
            usedPercent: period,
            durationMinutes: agent == .cursor ? 43200 : 10080,
            resetsAt: now.addingTimeInterval(250000), kind: .fixed),
        ],
        observedAt: now, state: .ready, source: "Demo")
    }
    selection = WindowSelection(agent: .codex, windowID: "period")
    for snapshot in snapshots {
      chartSelections[snapshot.agent] = "period"
      guard let window = snapshot.windows.last else { continue }
      for tick in 0...144 {
        samples.append(
          HistorySample(
            agent: snapshot.agent, accountScope: snapshot.accountScope!, windowID: window.id,
            windowTitle: window.title, cycleKey: window.cycleKey, plan: snapshot.plan,
            observedAt: now.addingTimeInterval(Double(tick - 144) * 300),
            usedPercent: max(
              0,
              (window.usedPercent ?? 0) - Double(144 - tick)
                * (snapshot.agent == .codex ? 0.09 : 0.05))))
      }
    }
  }
}

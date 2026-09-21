import Foundation
import Observation
import Sparkle

enum UpdatePhase {
  case disabled, idle, checking, available, downloading, extracting, installing, current, failed
}

/// Owns update policy; Sparkle alone downloads, verifies and replaces the app.
@MainActor @Observable
final class UpdateController: NSObject, SPUUpdaterDelegate {
  static let feed = "https://github.com/rvrhiv/LimitRoom/releases/latest/download/appcast.xml"
  static let releases = URL(string: "https://github.com/rvrhiv/LimitRoom/releases")!

  private(set) var phase = UpdatePhase.disabled
  private(set) var availableVersion: String?
  private(set) var progress: Double?
  private(set) var message: String?
  private(set) var lastChecked: Date?
  private(set) var automaticChecks = false
  private(set) var canCheck = false
  private(set) var canCancel = false
  let isDemo: Bool

  @ObservationIgnored private var updater: SPUUpdater?
  @ObservationIgnored private var driver: UpdateUserDriver?
  @ObservationIgnored private var observations: [NSKeyValueObservation] = []
  @ObservationIgnored private var offerID: String?
  @ObservationIgnored private var approvedID: String?
  @ObservationIgnored private var acceptedID: String?
  @ObservationIgnored private var cancellation: (() -> Void)?
  @ObservationIgnored private var wasCancelled = false

  init(isDemo: Bool) {
    self.isDemo = isDemo
    super.init()
    // Synthetic states only for the existing own-view renderer; never an updater session.
    if isDemo, CommandLine.arguments.contains("--render-preview"),
      let index = CommandLine.arguments.firstIndex(of: "--update-state"),
      CommandLine.arguments.indices.contains(index + 1)
    {
      switch CommandLine.arguments[index + 1] {
      case "available":
        phase = .available
        availableVersion = "0.6.0"
      case "downloading":
        phase = .downloading
        availableVersion = "0.6.0"
        progress = 0.42
      case "failed":
        phase = .failed
        message = localized(
          "Не удалось проверить подпись. Текущая версия сохранена.",
          "Signature verification failed. The current version is unchanged.")
      default: break
      }
    }
  }

  var isBusy: Bool { [.checking, .downloading, .extracting, .installing].contains(phase) }
  var canInstall: Bool { phase == .available && offerID != nil && canCheck && !isDemo }
  var status: String {
    switch phase {
    case .disabled: localized("Канал обновлений не подключён", "Update channel is not configured")
    case .idle: localized("Готово к проверке", "Ready to check")
    case .checking: localized("Проверяем обновления…", "Checking for updates…")
    case .available: localized("Доступно обновление", "Update available")
    case .downloading: localized("Загружаем обновление…", "Downloading update…")
    case .extracting: localized("Проверяем и подготавливаем…", "Verifying and preparing…")
    case .installing: localized("Устанавливаем и перезапускаем…", "Installing and relaunching…")
    case .current: localized("Новых обновлений нет", "No new updates")
    case .failed: localized("Обновление не выполнено", "Update did not complete")
    }
  }

  func start() {
    guard !isDemo, updater == nil else { return }
    let bundle = Bundle.main
    guard bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String == Self.feed,
      let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
      Data(base64Encoded: key)?.count == 32,
      bundle.object(forInfoDictionaryKey: "SURequireSignedFeed") as? Bool == true,
      bundle.object(forInfoDictionaryKey: "SUVerifyUpdateBeforeExtraction") as? Bool == true,
      bundle.object(forInfoDictionaryKey: "SUAllowsAutomaticUpdates") as? Bool == false
    else { return }
    let driver = UpdateUserDriver(controller: self)
    let updater = SPUUpdater(
      hostBundle: bundle, applicationBundle: bundle, userDriver: driver, delegate: self)
    self.driver = driver
    self.updater = updater
    do {
      try updater.start()
      phase = .idle
      automaticChecks = updater.automaticallyChecksForUpdates
      lastChecked = updater.lastUpdateCheckDate
      observations = [
        updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
          let allowed = change.newValue ?? false
          Task { @MainActor in self?.canCheck = allowed }
        }
      ]
    } catch { fail(error) }
  }

  func setAutomaticChecks(_ enabled: Bool) {
    guard let updater, !isDemo, phase != .disabled else { return }
    updater.automaticallyChecksForUpdates = enabled
    automaticChecks = updater.automaticallyChecksForUpdates
  }

  func check() {
    guard let updater, updater.canCheckForUpdates, !updater.sessionInProgress, !isBusy, !isDemo
    else { return }
    clearAuthorization()
    wasCancelled = false
    phase = .checking
    message = nil
    updater.checkForUpdateInformation()
  }

  func install() {
    guard canInstall, let updater, updater.canCheckForUpdates, !updater.sessionInProgress else {
      return
    }
    approvedID = offerID
    acceptedID = nil
    wasCancelled = false
    phase = .checking
    message = nil
    updater.checkForUpdates()
  }

  func cancel() {
    guard let cancellation else { return }
    wasCancelled = true
    clearAuthorization()
    phase = offerID == nil ? .idle : .available
    progress = nil
    cancellation()
  }

  func begin(_ phase: UpdatePhase, cancellation: (() -> Void)? = nil) {
    self.phase = phase
    self.cancellation = cancellation
    canCancel = cancellation != nil
    progress = nil
  }
  func setProgress(_ value: Double?) {
    progress = value.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil }
  }

  func found(_ item: SUAppcastItem, state: SPUUserUpdateState) -> SPUUserUpdateChoice {
    record(item)
    if state.userInitiated, let approvedID, approvedID == identity(item), eligible(item),
      !wasCancelled
    {
      acceptedID = approvedID
      return .install
    }
    clearAuthorization()
    // Dismiss would still install on quit if a previous session reached installation.
    return state.stage == .installing ? .skip : .dismiss
  }

  func ready() -> SPUUserUpdateChoice {
    guard let acceptedID, approvedID == acceptedID, !wasCancelled else { return .skip }
    begin(.installing)
    return .install
  }

  func finish() {
    clearAuthorization()
    progress = nil
    if isBusy { phase = offerID == nil ? .idle : .available }
  }

  func noUpdate(_ error: Error) {
    clearAuthorization()
    availableVersion = nil
    offerID = nil
    phase = .current
    let nsError = error as NSError
    let reason = (nsError.userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber)?.intValue
    if reason != Int(SPUNoUpdateFoundReason.onLatestVersion.rawValue)
      && reason != Int(SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue)
    {
      message = error.localizedDescription
    }
  }

  func fail(_ error: Error) {
    clearAuthorization()
    if wasCancelled { return }
    phase = .failed
    progress = nil
    message = error.localizedDescription
  }

  private func clearAuthorization() {
    approvedID = nil
    acceptedID = nil
    cancellation = nil
    canCancel = false
  }
  private func identity(_ item: SUAppcastItem) -> String {
    item.versionString + "|" + (item.fileURL?.absoluteString ?? "")
  }
  private func eligible(_ item: SUAppcastItem) -> Bool {
    guard item.signingValidationStatus == .succeeded,
      !item.isInformationOnlyUpdate, !item.isMajorUpgrade, item.installationType == "application",
      let url = item.fileURL, url.scheme == "https", url.host == "github.com",
      url.user == nil, url.password == nil, url.port == nil, url.query == nil, url.fragment == nil,
      url.path.hasPrefix("/rvrhiv/LimitRoom/releases/download/")
    else { return false }
    return true
  }
  private func record(_ item: SUAppcastItem) {
    availableVersion = String(item.displayVersionString.prefix(40))
    offerID = eligible(item) ? identity(item) : nil
    phase = .available
    message =
      offerID == nil
      ? localized("Подробности доступны на странице релизов.", "See the releases page for details.")
      : nil
  }

  func feedURLString(for updater: SPUUpdater) -> String? { Self.feed }
  func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }
  func updater(_ updater: SPUUpdater, shouldDownloadReleaseNotesForUpdate updateItem: SUAppcastItem)
    -> Bool
  { false }
  func updater(
    _ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem,
    updateCheck: SPUUpdateCheck
  ) throws {
    // Do not accept Sparkle's expired-signature fallback for this channel.
    guard updateItem.signingValidationStatus == .succeeded else {
      throw NSError(
        domain: "LimitRoom.Updates", code: 1,
        userInfo: [
          NSLocalizedDescriptionKey: localized(
            "Не удалось подтвердить подпись обновления.",
            "The update signature could not be verified.")
        ])
    }
  }
  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) { record(item) }
  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) { noUpdate(error) }
  func updater(
    _ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?
  ) {
    // The user driver can dismiss its UI before the cycle's final error arrives.
    // Suppress that cancelled cycle only, not subsequent scheduled checks.
    defer { wasCancelled = false }
    lastChecked = updater.lastUpdateCheckDate
    if let error, (error as NSError).code != Int(SUError.noUpdateError.rawValue) { fail(error) }
    finish()
  }
}

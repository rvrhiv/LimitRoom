import Darwin
import Foundation

public enum ClaudeSetupError: Error, Sendable {
  case helperMissing, unsafeFile, invalidSettings, unsupportedStatusLine
  case changedElsewhere, unmanagedBridge, notInstalled, otherConfiguration
}

/// Explicit user-initiated configuration, separate from read-only ClaudeConnector.
/// No credentials, project settings, shell profiles or transcripts are accessed.
public struct ClaudeSetup: Sendable {
  public let settingsURL: URL
  private let directory: URL
  private let helperURL: URL
  private let maximumSize = 4_194_304
  private var receiptURL: URL { directory.appendingPathComponent("receipt.json") }

  public init(settingsURL: URL, directory: URL, helperURL: URL) {
    self.settingsURL = settingsURL.standardizedFileURL
    self.directory = directory.appendingPathComponent("ClaudeSetup", isDirectory: true)
    self.helperURL = helperURL
  }

  public func isInstalled(scope: String) -> Bool {
    guard let receipt = try? receipt(), receipt.settingsPath == settingsURL.path,
      receipt.scope == scope,
      let data = try? read(settingsURL), let settings = try? object(data),
      command(in: settings) == receipt.command,
      FileManager.default.isExecutableFile(atPath: receipt.helperPath)
    else { return false }
    return true
  }

  /// Scope-independent ownership: a partially disconnected integration can still
  /// be removed or repaired even though its old scope no longer accepts readings.
  public var hasManagedSettings: Bool {
    guard let receipt = try? receipt(), receipt.settingsPath == settingsURL.path,
      let data = try? read(settingsURL), let settings = try? object(data)
    else { return false }
    return receipt.manages(command(in: settings))
  }

  public func install(scope: String) throws {
    guard UUID(uuidString: scope) != nil,
      FileManager.default.isExecutableFile(atPath: helperURL.path)
    else { throw ClaudeSetupError.helperMissing }
    try ensureDirectory(directory)
    let lock = try acquireLock()
    defer {
      flock(lock, LOCK_UN)
      close(lock)
    }
    try ensureDirectory(settingsURL.deletingLastPathComponent())
    let before = try read(settingsURL)
    var settings = try object(before)
    let prior = try receipt()
    if let prior, prior.settingsPath != settingsURL.path {
      throw ClaudeSetupError.otherConfiguration
    }
    let managed = prior.map { $0.manages(command(in: settings)) } ?? false
    // An old hand-written integration must not become its own upstream command.
    if !managed, command(in: settings)?.contains("limitroom-claude-bridge") == true {
      throw ClaudeSetupError.unmanagedBridge
    }
    let original: Data?
    if managed {
      original = prior?.originalStatusLine
    } else {
      original = try settings["statusLine"].map {
        try JSONSerialization.data(withJSONObject: $0, options: [.fragmentsAllowed, .sortedKeys])
      }
    }
    let status = try validateStatusLine(original)
    let token = UUID().uuidString
    let backup = directory.appendingPathComponent("settings-before-\(token).json")
    try privateWrite(before ?? Data("{}".utf8), to: backup)
    let originalBackup = managed ? prior!.originalBackup : backup.path
    if status != nil {
      // Refuse to silently discard the previous display if its backup was removed.
      guard let saved = try read(URL(fileURLWithPath: originalBackup)),
        let savedStatus = try object(saved)["statusLine"] as? [String: Any],
        savedStatus["command"] as? String == status?["command"] as? String
      else { throw ClaudeSetupError.changedElsewhere }
    }
    let helper = directory.appendingPathComponent("limitroom-claude-bridge-\(token)")
    try FileManager.default.copyItem(at: helperURL, to: helper)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
    var invocation = Self.quote(helper.path) + " --scope " + Self.quote(scope)
    if status != nil { invocation += " --previous-settings " + Self.quote(originalBackup) }
    var replacement = status ?? [:]
    replacement["type"] = "command"
    replacement["command"] = invocation
    settings["statusLine"] = replacement
    // Validate final serialization BEFORE publishing the receipt or settings.
    let replacementBytes = try encodeSettings(settings)
    let next = Receipt(
      settingsPath: settingsURL.path, scope: scope, command: invocation,
      previousCommand: managed ? command(in: try object(before)) : nil, helperPath: helper.path,
      originalBackup: originalBackup, originalStatusLine: original)
    // Receipt first, with the previously managed command retained for recovery
    // after a crash before the settings replacement. Never identify by a substring.
    let previousReceipt = try read(receiptURL)
    try privateReplace(try JSONEncoder().encode(next), at: receiptURL)
    do {
      try replaceSettings(replacementBytes, expected: before)
    } catch {
      if let previousReceipt { try? privateReplace(previousReceipt, at: receiptURL) }
      throw error
    }
  }

  public func uninstall() throws {
    try ensureDirectory(directory)
    let lock = try acquireLock()
    defer {
      flock(lock, LOCK_UN)
      close(lock)
    }
    guard let receipt = try receipt(), receipt.settingsPath == settingsURL.path else {
      throw ClaudeSetupError.notInstalled
    }
    let before = try read(settingsURL)
    var settings = try object(before)
    guard receipt.manages(command(in: settings)) else { throw ClaudeSetupError.changedElsewhere }
    if let original = receipt.originalStatusLine {
      settings["statusLine"] = try JSONSerialization.jsonObject(
        with: original, options: .fragmentsAllowed)
    } else {
      settings.removeValue(forKey: "statusLine")
    }
    let replacementBytes = try encodeSettings(settings)
    let backup = directory.appendingPathComponent(
      "settings-before-disconnect-\(UUID().uuidString).json")
    try privateWrite(before ?? Data("{}".utf8), to: backup)
    try replaceSettings(replacementBytes, expected: before)
    // Keep backups, receipt and immutable helpers recoverable. No recursive removal.
  }

  private struct Receipt: Codable {
    var settingsPath: String
    var scope: String
    var command: String
    var previousCommand: String?
    var helperPath: String
    var originalBackup: String
    var originalStatusLine: Data?

    func manages(_ value: String?) -> Bool {
      guard let value else { return false }
      return value == command || value == previousCommand
    }
  }

  private func receipt() throws -> Receipt? {
    guard let bytes = try read(receiptURL) else { return nil }
    guard let value = try? JSONDecoder().decode(Receipt.self, from: bytes) else {
      throw ClaudeSetupError.invalidSettings
    }
    return value
  }

  private func command(in settings: [String: Any]) -> String? {
    (settings["statusLine"] as? [String: Any])?["command"] as? String
  }

  private func validateStatusLine(_ data: Data?) throws -> [String: Any]? {
    guard let data else { return nil }
    guard data.count <= 65_536 else { throw ClaudeSetupError.unsupportedStatusLine }
    let value = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    if value is NSNull { return nil }
    guard let status = value as? [String: Any], status["type"] as? String == "command",
      let command = status["command"] as? String,
      !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      command.utf8.count <= 16_384, !command.contains("\0")
    else { throw ClaudeSetupError.unsupportedStatusLine }
    return status
  }

  private func object(_ data: Data?) throws -> [String: Any] {
    guard let data else { return [:] }
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ClaudeSetupError.invalidSettings
    }
    return object
  }

  private func read(_ url: URL) throws -> Data? {
    let attributes: [FileAttributeKey: Any]
    do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) } catch {
      if (error as NSError).code == NSFileNoSuchFileError { return nil }
      throw error
    }
    guard attributes[.type] as? FileAttributeType == .typeRegular,
      (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= maximumSize
    else { throw ClaudeSetupError.unsafeFile }
    let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
    guard descriptor >= 0 else { throw ClaudeSetupError.unsafeFile }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    let data = try handle.read(upToCount: maximumSize + 1) ?? Data()
    guard data.count <= maximumSize else { throw ClaudeSetupError.unsafeFile }
    return data
  }

  private func ensureDirectory(_ url: URL) throws {
    if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
      guard attributes[.type] as? FileAttributeType == .typeDirectory else {
        throw ClaudeSetupError.unsafeFile
      }
    } else {
      try FileManager.default.createDirectory(
        at: url, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
    }
  }

  private func privateWrite(_ data: Data, to url: URL) throws {
    let descriptor = open(url.path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, 0o600)
    guard descriptor >= 0 else { throw ClaudeSetupError.unsafeFile }
    let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    try file.write(contentsOf: data)
    try file.synchronize()
  }

  private func acquireLock() throws -> Int32 {
    let descriptor = open(
      directory.appendingPathComponent("setup.lock").path,
      O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
    guard descriptor >= 0 else { throw ClaudeSetupError.unsafeFile }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      close(descriptor)
      throw ClaudeSetupError.changedElsewhere
    }
    return descriptor
  }

  private func privateReplace(_ data: Data, at url: URL, beforeCommit: () throws -> Void = {})
    throws
  {
    let staging = url.deletingLastPathComponent().appendingPathComponent(
      ".limitroom-\(UUID().uuidString).tmp")
    defer { try? FileManager.default.removeItem(at: staging) }
    try privateWrite(data, to: staging)
    try beforeCommit()
    guard rename(staging.path, url.path) == 0 else { throw ClaudeSetupError.unsafeFile }
  }

  private func encodeSettings(_ settings: [String: Any]) throws -> Data {
    var bytes = try JSONSerialization.data(
      withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    if bytes.count > maximumSize {
      bytes = try JSONSerialization.data(
        withJSONObject: settings, options: [.sortedKeys, .withoutEscapingSlashes])
    }
    guard bytes.count <= maximumSize else { throw ClaudeSetupError.unsafeFile }
    return bytes
  }

  private func replaceSettings(_ bytes: Data, expected: Data?) throws {
    // Most Claude writers are not file-coordinated. Compare immediately before the
    // atomic replacement; arbitrary external writes after this check cannot be locked.
    try privateReplace(bytes, at: settingsURL) {
      guard try read(settingsURL) == expected else { throw ClaudeSetupError.changedElsewhere }
    }
  }

  private static func quote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}

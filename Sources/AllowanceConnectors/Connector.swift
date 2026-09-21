import AllowanceCore
import Foundation

public protocol AllowanceConnector: Sendable {
  var agent: AgentID { get }
  func read() async throws -> AgentSnapshot
}

public enum ConnectorError: Error, Sendable {
  case missingExecutable, signedOut, unavailable, invalidResponse, timedOut
}

public struct PendingConnector: AllowanceConnector {
  public let agent: AgentID
  public init(agent: AgentID) { self.agent = agent }
  public func read() async throws -> AgentSnapshot {
    AgentSnapshot(agent: agent, state: .needsSetup, source: "Cursor Dashboard")
  }
}

public enum ExecutableLocator {
  public static func find(_ name: String, explicit: String? = nil) -> URL? {
    let home = FileManager.default.homeDirectoryForCurrentUser
    if let explicit, !explicit.isEmpty {
      return explicit.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: explicit)
        ? URL(fileURLWithPath: explicit) : nil
    }
    let paths = [
      "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)",
      home.appendingPathComponent(".local/bin/\(name)").path,
      "/Applications/Codex.app/Contents/Resources/\(name)",
      "/Applications/ChatGPT.app/Contents/Resources/\(name)",
      home.appendingPathComponent("Applications/Codex.app/Contents/Resources/\(name)").path,
    ]
    return paths.first { $0.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: $0) }
      .map(URL.init(fileURLWithPath:))
  }
}

import AllowanceCore
import Foundation

public struct ClaudeConnector: AllowanceConnector {
  public let agent: AgentID = .claude
  public let file: URL
  public let expectedScope: String
  public init(file: URL, expectedScope: String) {
    self.file = file
    self.expectedScope = expectedScope
  }
  public func read() async throws -> AgentSnapshot {
    guard FileManager.default.fileExists(atPath: file.path) else {
      throw ConnectorError.missingExecutable
    }
    let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size < 65_536 else { throw ConnectorError.invalidResponse }
    var snapshot = try JSONDecoder().decode(AgentSnapshot.self, from: Data(contentsOf: file))
    guard snapshot.agent == .claude, snapshot.windows.count <= 10 else {
      throw ConnectorError.invalidResponse
    }
    guard snapshot.accountScope == expectedScope else { throw ConnectorError.signedOut }
    snapshot.fetchedAt = .now
    if !snapshot.isFresh() { snapshot.state = .stale }
    return snapshot
  }
}

import AllowanceConnectors
import AllowanceCore
import AllowanceStorage
import Foundation

public actor AllowanceMonitor {
  private var connectors: [any AllowanceConnector]
  private let history: HistoryStore?
  private var cache: [AgentID: AgentSnapshot] = [:]
  private var isReading = false
  private var generation = 0
  public private(set) var storageFailed = false

  public init(
    connectors: [any AllowanceConnector], history: HistoryStore?, initial: [AgentSnapshot] = []
  ) {
    self.connectors = connectors
    self.history = history
    for snapshot in initial { cache[snapshot.agent] = snapshot }
  }
  public func replaceConnectors(_ connectors: [any AllowanceConnector]) {
    generation += 1
    self.connectors = connectors
  }
  public func refresh() async -> [AgentSnapshot] {
    guard !isReading else { return current() }
    isReading = true
    storageFailed = false
    let requestGeneration = generation
    defer { isReading = false }
    await withTaskGroup(of: (AgentID, AgentSnapshot?, SourceState).self) { group in
      for connector in connectors {
        group.addTask {
          do { return (connector.agent, try await connector.read(), .ready) } catch ConnectorError
            .missingExecutable
          { return (connector.agent, nil, .needsSetup) } catch ConnectorError.signedOut {
            return (connector.agent, nil, .signedOut)
          } catch { return (connector.agent, nil, .unavailable) }
        }
      }
      for await (agent, snapshot, failure) in group {
        guard requestGeneration == generation else { continue }
        if let snapshot {
          await accept(snapshot)
        } else if failure == .signedOut {
          // Account identity is no longer valid. Do not carry another account's values forward.
          cache[agent] = AgentSnapshot(agent: agent, state: .signedOut)
        } else if var old = cache[agent], !old.windows.isEmpty {
          old.state = .stale
          cache[agent] = old
        } else {
          cache[agent] = AgentSnapshot(agent: agent, state: failure)
        }
      }
    }
    return current()
  }
  public func accept(_ snapshot: AgentSnapshot) async {
    if snapshot.state == .unavailable || (snapshot.state == .stale && snapshot.windows.isEmpty),
      var old = cache[snapshot.agent], !old.windows.isEmpty,
      snapshot.accountScope == nil || snapshot.accountScope == old.accountScope
    {
      old.state = .stale
      cache[snapshot.agent] = old
      return
    }
    cache[snapshot.agent] = snapshot
    do { try await history?.record(snapshot) } catch { storageFailed = true }
  }
  public func forget(_ agent: AgentID) {
    generation += 1
    cache[agent] = nil
  }
  public func current() -> [AgentSnapshot] {
    AgentID.allCases.map { cache[$0] ?? AgentSnapshot(agent: $0) }
  }
}

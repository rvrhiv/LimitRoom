import AllowanceCore
import Foundation

public struct WidgetSnapshotStore: Sendable {
  public let file: URL
  public init(container: URL) {
    file = container.appendingPathComponent("limitroom-widget-v1.json")
  }
  public func write(_ snapshot: WidgetSnapshot) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(snapshot).write(to: file, options: .atomic)
  }
  public func read() throws -> WidgetSnapshot {
    let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: file))
    guard snapshot.version == 1 else {
      throw StorageError.unsupportedVersion(Int32(snapshot.version))
    }
    return snapshot
  }
}

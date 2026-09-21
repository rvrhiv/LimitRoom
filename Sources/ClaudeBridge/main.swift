import AllowanceCore
import Darwin
import Foundation

// Only quota fields are persisted. An existing user-configured statusLine may
// receive the same in-memory input; no transcript is opened or input logged.
guard ProcessInfo.processInfo.environment["LIMITROOM_STATUSLINE_FORWARDING"] != "1" else { exit(0) }
do {
  var data = Data()
  while let chunk = try FileHandle.standardInput.read(upToCount: 8192), !chunk.isEmpty {
    data.append(chunk)
    guard data.count < 1_048_576 else { exit(0) }
  }
  let display = try? collectQuota(data)
  if let command = previousCommand() {
    forward(input: data, command: command)
  } else if let display {
    print(display)
  }
} catch {
  // A status-line integration must not expose input or interrupt Claude.
  exit(0)
}

func argument(_ flag: String) -> String? {
  guard let index = CommandLine.arguments.firstIndex(of: flag),
    CommandLine.arguments.indices.contains(index + 1)
  else { return nil }
  return CommandLine.arguments[index + 1]
}

func previousCommand() -> String? {
  guard let path = argument("--previous-settings"),
    let attributes = try? FileManager.default.attributesOfItem(atPath: path),
    attributes[.type] as? FileAttributeType == .typeRegular,
    let size = attributes[.size] as? NSNumber, size.intValue <= 4_194_304
  else { return nil }
  let descriptor = open(path, O_RDONLY | O_NOFOLLOW)
  guard descriptor >= 0 else { return nil }
  let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
  guard let data = try? file.read(upToCount: 4_194_305), data.count <= 4_194_304,
    let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let status = root["statusLine"] as? [String: Any], status["type"] as? String == "command",
    let command = status["command"] as? String, !command.isEmpty,
    !command.contains("limitroom-claude-bridge")
  else { return nil }
  return command
}

func forward(input: Data, command: String) {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/bin/sh")
  process.arguments = ["-c", command]
  var environment = ProcessInfo.processInfo.environment
  environment["LIMITROOM_STATUSLINE_FORWARDING"] = "1"
  process.environment = environment
  let pipe = Pipe()
  process.standardInput = pipe
  process.standardOutput = FileHandle.standardOutput
  process.standardError = FileHandle.standardError
  do { try process.run() } catch { return }
  // An early-exiting command may not read stdin. Avoid SIGPIPE and write off the
  // waiting thread; stdout is inherited directly, so large output cannot deadlock.
  signal(SIGPIPE, SIG_IGN)
  DispatchQueue.global(qos: .utility).async {
    try? pipe.fileHandleForWriting.write(contentsOf: input)
    try? pipe.fileHandleForWriting.close()
  }
  process.waitUntilExit()
}

func collectQuota(_ data: Data) throws -> String? {
  guard data.count < 1_048_576,
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
  else { return nil }
  let limits = root["rate_limits"] as? [String: Any] ?? [:]
  let windows: [AllowanceWindow] = [("five_hour", "5h", 300), ("seven_day", "7d", 10080)].compactMap
  { key, title, minutes in
    guard let raw = limits[key] as? [String: Any] else { return nil }
    return AllowanceWindow(
      id: key, title: title,
      usedPercent: (raw["used_percentage"] as? NSNumber)?.doubleValue,
      durationMinutes: minutes,
      resetsAt: (raw["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) },
      kind: .fixed)
  }
  let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
    "Library/Application Support/LimitRoom", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let lock = open(
    directory.appendingPathComponent("claude-bridge.lock").path, O_CREAT | O_RDWR, 0o600)
  guard lock >= 0 else { return nil }
  defer {
    flock(lock, LOCK_UN)
    close(lock)
  }
  guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { return nil }
  let file = directory.appendingPathComponent("claude-statusline.json")
  let scope = argument("--scope")
  // Only the connection explicitly selected by the app may publish readings.
  // A still-running terminal with an old --scope cannot overwrite the new account.
  guard let scope, scope.utf8.count <= 256,
    let active = try? String(
      contentsOf: directory.appendingPathComponent("claude-connection"), encoding: .utf8),
    active == scope
  else { return nil }
  let now = Date.now
  var snapshot = AgentSnapshot(
    agent: .claude, accountScope: scope, windows: windows, observedAt: now,
    state: windows.isEmpty ? .unavailable : .ready, source: "Claude Code statusLine")
  // Re-running statusLine is not proof of a new upstream reading. Do not renew unchanged data.
  if let oldData = try? Data(contentsOf: file),
    let old = try? JSONDecoder().decode(AgentSnapshot.self, from: oldData),
    old.accountScope == scope
  {
    let regresses = old.windows.contains { prior in
      guard let current = windows.first(where: { $0.id == prior.id }) else { return true }
      if let priorReset = prior.resetsAt {
        guard let currentReset = current.resetsAt, currentReset >= priorReset else { return true }
      }
      // Incomplete payloads must not erase the high-water baseline.
      if prior.usedPercent != nil && current.usedPercent == nil { return true }
      guard let cycle = prior.cycleKey, cycle == current.cycleKey,
        let before = prior.usedPercent, let after = current.usedPercent
      else { return false }
      return after < before
    }
    if regresses {
      // Without an upstream observation version, a same-cycle decrease may be a
      // late statusLine producer. Retain the high-water baseline, visibly stale.
      snapshot = old
      snapshot.state = .stale
    } else if old.windows == windows {
      snapshot = old
    }
  }
  try JSONEncoder().encode(snapshot).write(to: file, options: .atomic)
  try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
  let parts = snapshot.windows.compactMap { window in
    window.remainingPercent.map { "\(window.title) \(Int($0))%" }
  }
  return (snapshot.state == .stale ? "~ " : "") + parts.joined(separator: " · ")
}

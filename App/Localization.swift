import AllowanceCore
import Foundation

func localized(_ russian: String, _ english: String) -> String {
  Locale.preferredLanguages.first?.hasPrefix("ru") == true ? russian : english
}

extension AgentSnapshot {
  /// Presentation only: history keeps the exact provider code as its plan boundary.
  var planLabel: String? {
    guard let raw = plan?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
      raw.lowercased() != "unknown"
    else { return nil }
    switch raw.lowercased() {
    case "free": return "Free"
    case "go": return "Go"
    case "plus": return "Plus"
    case "pro": return "Pro"
    case "team": return "Team"
    case "business": return "Business"
    case "enterprise": return "Enterprise"
    case "edu": return "Edu"
    case "prolite" where agent == .codex: return "Pro · Lite"
    default: return raw
    }
  }

  var planDetailNote: String? {
    guard agent == .codex,
      let code = plan?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
      ["pro", "prolite"].contains(code)
    else { return nil }
    return localized(
      "Codex сообщает тип плана, но не множитель лимитов Pro. Точный уровень смотрите в подписке ChatGPT.",
      "Codex reports the plan type, but not the Pro usage multiplier. Check ChatGPT for your exact subscription tier."
    )
  }
}

extension SourceState {
  var label: String {
    switch self {
    case .ready: localized("Обновлено", "Up to date")
    case .stale: localized("Устарело", "Stale")
    case .needsSetup: localized("Подключить", "Connect")
    case .signedOut: localized("Нужен вход", "Sign in required")
    case .unavailable: localized("Недоступно", "Unavailable")
    case .unsupported: localized("Нет источника", "No source")
    }
  }
}

func resetLabel(_ date: Date?) -> String {
  guard let date else { return localized("Время сброса неизвестно", "Reset time unavailable") }
  guard date > .now else {
    return localized("Ожидаем обновление после сброса", "Waiting for a new reading")
  }
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = date.timeIntervalSinceNow > 86400 ? [.day, .hour] : [.hour, .minute]
  formatter.maximumUnitCount = 2
  formatter.unitsStyle = .abbreviated
  let interval = formatter.string(from: max(0, date.timeIntervalSinceNow)) ?? "—"
  return localized("Сброс через ", "Resets in ") + interval
}

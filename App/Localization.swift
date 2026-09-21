import AllowanceCore
import Foundation

func localized(_ russian: String, _ english: String) -> String {
  Locale.preferredLanguages.first?.hasPrefix("ru") == true ? russian : english
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

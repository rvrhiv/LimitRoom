import Foundation

enum QuotaRefreshInterval: Int, CaseIterable, Identifiable {
  case oneMinute = 60
  case fiveMinutes = 300
  case thirtyMinutes = 1800
  case oneHour = 3600

  var id: Int { rawValue }
  var duration: TimeInterval { TimeInterval(rawValue) }
  var title: String {
    switch self {
    case .oneMinute: localized("1 минута", "1 minute")
    case .fiveMinutes: localized("5 минут", "5 minutes")
    case .thirtyMinutes: localized("30 минут", "30 minutes")
    case .oneHour: localized("1 час", "1 hour")
    }
  }
}

import Foundation
import Observation

enum PresentationMode: String, CaseIterable, Identifiable {
  case menuBar, notch
  var id: String { rawValue }
  var title: String {
    switch self {
    case .menuBar: localized("Строка меню", "Menu bar")
    case .notch: localized("Возле камеры", "Near the camera")
    }
  }
}

enum NotchSlotContent: String, CaseIterable, Identifiable {
  case quota, reset, window, hidden
  var id: String { rawValue }
  var title: String {
    switch self {
    case .quota: localized("Остаток квоты", "Quota remaining")
    case .reset: localized("Сброс квоты", "Quota reset")
    case .window: localized("Название окна", "Window name")
    case .hidden: localized("Ничего", "Nothing")
    }
  }
}

enum ResetDisplayStyle: String, CaseIterable, Identifiable {
  case relative, dateTime, hidden
  var id: String { rawValue }
  var title: String {
    switch self {
    case .relative: localized("Осталось времени", "Time remaining")
    case .dateTime: localized("Дата и время", "Date and time")
    case .hidden: localized("Не показывать", "Hide")
    }
  }
}

struct IndicatorComponents: Codable, Equatable {
  var icon = true
  var ring = true
  var percentage = true
  var isEmpty: Bool { !icon && !ring && !percentage }
  var visibleCount: Int { [icon, ring, percentage].filter { $0 }.count }
  var preferredWidth: Double {
    (icon ? 15 : 0) + (ring ? 16 : 0) + (percentage ? 33 : 0)
      + Double(max(0, visibleCount - 1)) * 4 + 10
  }
}

@MainActor @Observable
final class PresentationPreferences {
  var mode: PresentationMode {
    didSet {
      guard mode != oldValue else { return }
      save(mode.rawValue, key: "presentationMode")
      onModeChange?()
    }
  }
  var menuComponents: IndicatorComponents {
    didSet { saveComponents(menuComponents, key: "menuIndicatorComponents") }
  }
  var leftComponents: IndicatorComponents {
    didSet {
      saveComponents(leftComponents, key: "notchLeftComponents")
      onLayoutChange?()
    }
  }
  var rightComponents: IndicatorComponents {
    didSet {
      saveComponents(rightComponents, key: "notchRightComponents")
      onLayoutChange?()
    }
  }
  var resolvedMenuComponents: IndicatorComponents {
    menuComponents.isEmpty
      ? IndicatorComponents(icon: false, ring: true, percentage: false)
      : menuComponents
  }
  var showPercentage: Bool {
    get { menuComponents.percentage }
    set { menuComponents.percentage = newValue }
  }
  var hapticsEnabled: Bool {
    didSet { save(hapticsEnabled, key: "notchHapticsEnabled") }
  }
  var leftContent: NotchSlotContent {
    didSet {
      save(leftContent.rawValue, key: "notchLeftContent")
      onLayoutChange?()
    }
  }
  var rightContent: NotchSlotContent {
    didSet {
      save(rightContent.rawValue, key: "notchRightContent")
      onLayoutChange?()
    }
  }
  var resetStyle: ResetDisplayStyle {
    didSet {
      save(resetStyle.rawValue, key: "notchResetStyle")
      onLayoutChange?()
    }
  }
  var sideWidth: Double {
    didSet {
      save(resolvedSideWidth, key: "notchSideWidth")
      onLayoutChange?()
    }
  }
  var resolvedSideWidth: Double { Self.sanitizeWidth(sideWidth) }
  var widthRange: ClosedRange<Double> { 56...max(120, resolvedSideWidth) }
  var leftWidth: Double { width(for: leftContent, components: leftComponents) }
  var rightWidth: Double { width(for: rightContent, components: rightComponents) }
  var fallbackMessage: String?

  @ObservationIgnored var onModeChange: (() -> Void)?
  @ObservationIgnored var onLayoutChange: (() -> Void)?
  @ObservationIgnored private let isDemo: Bool
  @ObservationIgnored private let defaults: UserDefaults

  init(isDemo: Bool, defaults: UserDefaults = .standard) {
    self.isDemo = isDemo
    self.defaults = defaults
    mode =
      isDemo
      ? .menuBar
      : PresentationMode(
        rawValue: defaults.string(forKey: "presentationMode") ?? "") ?? .menuBar
    let legacyPercentage = defaults.object(forKey: "showRemainingPercentage") as? Bool ?? true
    func components(_ key: String) -> IndicatorComponents {
      guard !isDemo else { return IndicatorComponents() }
      return defaults.data(forKey: key).flatMap {
        try? JSONDecoder().decode(IndicatorComponents.self, from: $0)
      } ?? IndicatorComponents(percentage: legacyPercentage)
    }
    menuComponents = components("menuIndicatorComponents")
    leftComponents = components("notchLeftComponents")
    rightComponents = components("notchRightComponents")
    hapticsEnabled = isDemo ? true : defaults.object(forKey: "notchHapticsEnabled") as? Bool ?? true
    leftContent =
      isDemo
      ? .quota
      : NotchSlotContent(rawValue: defaults.string(forKey: "notchLeftContent") ?? "") ?? .quota
    rightContent =
      isDemo
      ? .reset
      : NotchSlotContent(rawValue: defaults.string(forKey: "notchRightContent") ?? "") ?? .reset
    resetStyle =
      isDemo
      ? .relative
      : ResetDisplayStyle(rawValue: defaults.string(forKey: "notchResetStyle") ?? "") ?? .relative
    sideWidth = Self.sanitizeWidth(
      isDemo ? 88 : defaults.object(forKey: "notchSideWidth") as? Double ?? 88)
  }

  private func width(for content: NotchSlotContent, components: IndicatorComponents) -> Double {
    content == .hidden || (content == .reset && resetStyle == .hidden)
      || (content == .quota && components.isEmpty) ? 0 : resolvedSideWidth
  }

  private static func sanitizeWidth(_ width: Double) -> Double {
    width.isFinite ? min(160, max(56, width)) : 88
  }

  private func saveComponents(_ value: IndicatorComponents, key: String) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    save(data, key: key)
  }

  private func save(_ value: Any, key: String) {
    guard !isDemo else { return }
    defaults.set(value, forKey: key)
  }
}

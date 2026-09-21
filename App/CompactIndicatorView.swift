import AllowanceCore
import AppKit
import SwiftUI

struct CompactIndicatorView: View {
  var model: AppModel
  var showsWindowTitle = false
  var showsDemoLabel = true
  var components: IndicatorComponents?
  var scale: CGFloat = 1

  private var visible: IndicatorComponents {
    components ?? model.presentation.resolvedMenuComponents
  }

  var body: some View {
    CompactIndicatorContent(
      reading: IndicatorReading(model: model), components: visible,
      showsWindowTitle: showsWindowTitle, showsDemoLabel: showsDemoLabel, scale: scale)
  }
}

/// Resolve observation before rendering: ImageRenderer must not own a live model.
struct IndicatorReading {
  let agent: AgentID?
  let remaining: Double?
  let windowTitle: String?
  let stale: Bool
  let missing: Bool
  let demo: Bool

  @MainActor init(model: AppModel) {
    let pinned = model.pinned
    agent = model.selection?.agent
    remaining = pinned?.1.remainingPercent
    windowTitle = pinned?.1.title
    stale = pinned.map { !$0.0.windowIsFresh($0.1, at: model.displayDate) } ?? false
    missing = model.selection != nil && pinned == nil
    demo = model.isDemo
  }

  var accessibilityDescription: String {
    let identity = [agent?.title, windowTitle].compactMap { $0 }.joined(separator: ", ")
    let value =
      remaining.map {
        remainingPercentLabel($0, compact: false) + " " + localized("осталось", "remaining")
      }
      ?? localized("Нет показаний выбранного окна", "No reading for the selected window")
    return (demo ? "DEMO. " : "") + identity + ". " + value
      + (stale ? ". " + localized("Устаревшие данные", "Stale reading") : "")
  }
}

/// MenuBarExtra extracts an image/title; arbitrary Shape labels are discarded.
/// Use this same image in Settings so its preview matches the native status item.
struct MenuBarIndicatorImage: View {
  let model: AppModel
  var showsDemoLabel = true

  var body: some View {
    let reading = IndicatorReading(model: model)
    Image(
      nsImage: Self.render(
        reading: reading, components: model.presentation.resolvedMenuComponents,
        showsDemoLabel: showsDemoLabel)
    )
    .accessibilityLabel(reading.accessibilityDescription)
    .help(reading.accessibilityDescription)
  }

  @MainActor private static func render(
    reading: IndicatorReading, components: IndicatorComponents, showsDemoLabel: Bool
  ) -> NSImage {
    let renderer = ImageRenderer(
      content: CompactIndicatorContent(
        reading: reading, components: components, showsDemoLabel: showsDemoLabel
      )
      .foregroundStyle(.black).environment(\.colorScheme, .light)
      .fixedSize().frame(height: 18))
    renderer.scale = 2
    let image =
      renderer.nsImage
      ?? NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "LimitRoom")
      ?? NSImage(size: NSSize(width: 18, height: 18))
    image.isTemplate = true
    return image
  }
}

private struct CompactIndicatorContent: View {
  let reading: IndicatorReading
  let components: IndicatorComponents
  var showsWindowTitle = false
  var showsDemoLabel = true
  var scale: CGFloat = 1

  var body: some View {
    HStack(spacing: 4 * scale) {
      if reading.demo && showsDemoLabel { Text("DEMO").font(.system(size: 7, weight: .semibold)) }
      if components.icon {
        AgentIcon(agent: reading.agent, size: 15 * scale).opacity(reading.stale ? 0.55 : 1)
      }
      if components.ring {
        CircularGauge(value: reading.remaining, lineWidth: 2.2 * scale)
          .frame(width: 16 * scale, height: 16 * scale).opacity(reading.stale ? 0.55 : 1)
      }
      if components.percentage {
        Text(remainingPercentLabel(reading.remaining, compact: true))
          .font(.system(size: 12 * scale, weight: .semibold)).monospacedDigit()
          .lineLimit(1).minimumScaleFactor(0.8)
      }
      if reading.stale {
        Image(systemName: "clock").font(.system(size: 8 * scale))
      } else if reading.missing {
        Image(systemName: "questionmark").font(.system(size: 8 * scale))
      }
      if showsWindowTitle, let title = reading.windowTitle {
        Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 11).padding(.horizontal, 2)
        Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
          .lineLimit(1).truncationMode(.tail)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(reading.accessibilityDescription)
    .help(reading.accessibilityDescription)
  }
}

func shortWindowTitle(_ window: AllowanceWindow) -> String {
  window.title
}

func remainingPercentLabel(_ value: Double?, compact: Bool) -> String {
  guard let value, value.isFinite else { return "—" }
  let clamped = min(100, max(0, value))
  if compact { return "\(Int(clamped))%" }
  return clamped.formatted(.number.precision(.fractionLength(0...6))) + "%"
}

struct CircularGauge: View {
  var value: Double?
  var lineWidth: CGFloat = 2.4
  var body: some View {
    ZStack {
      Circle().stroke(
        .primary.opacity(0.22), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
      if let value, value.isFinite {
        Circle().trim(from: 0, to: min(1, max(0, value / 100)))
          .stroke(.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
          .rotationEffect(.degrees(-90))
      }
    }.padding(lineWidth / 2).accessibilityHidden(true)
  }
}

import AllowanceCore
import SwiftUI

/// Shared by the native panel and settings. The middle is deliberately empty:
/// its size/offset matches the physical camera, including during frame animation.
struct NotchHeaderView: View {
  var model: AppModel
  var cameraWidth: CGFloat
  var cameraLeading: CGFloat
  var height: CGFloat
  var open: (() -> Void)?

  var body: some View {
    GeometryReader { proxy in
      HStack(spacing: 0) {
        slot(
          model.presentation.leftContent, components: model.presentation.leftComponents,
          width: max(0, cameraLeading), alignment: .trailing)
        Color.clear.frame(width: cameraWidth, height: height).accessibilityHidden(true)
        slot(
          model.presentation.rightContent,
          components: model.presentation.rightComponents,
          width: max(0, proxy.size.width - cameraLeading - cameraWidth), alignment: .leading)
      }
    }.frame(height: height).foregroundStyle(.white).preferredColorScheme(.dark)
  }

  private func slot(
    _ content: NotchSlotContent, components: IndicatorComponents, width: CGFloat,
    alignment: Alignment
  ) -> some View {
    let visible =
      width > 0 && content != .hidden
      && !(content == .reset && model.presentation.resetStyle == .hidden)
      && !(content == .quota && components.isEmpty)
    return Group {
      if let open {
        Button(action: open) {
          slotContent(content, components: components, width: width).contentShape(Rectangle())
        }.buttonStyle(.plain)
          .accessibilityHint(
            localized("Открыть квоты всех агентов", "Open allowances for all agents"))
      } else {
        slotContent(content, components: components, width: width)
      }
    }
    .clipped()
    .frame(width: width, height: height, alignment: alignment)
    .opacity(visible ? 1 : 0)
    .allowsHitTesting(visible)
    .accessibilityHidden(!visible)
  }

  private func slotContent(
    _ content: NotchSlotContent, components: IndicatorComponents, width: CGFloat
  ) -> some View {
    VStack(spacing: 0) {
      NotchSlotView(model: model, content: content, components: components)
      // Keep synthetic values visibly identified even with only a reset/name wing.
      // Never put this label in the physically obscured camera region.
      if model.isDemo {
        Text("DEMO").font(.system(size: 6, weight: .semibold)).foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 9)
    .frame(width: min(width, model.presentation.resolvedSideWidth), height: height)
  }
}

private struct NotchSlotView: View {
  var model: AppModel
  var content: NotchSlotContent
  var components: IndicatorComponents

  private var stale: Bool {
    guard let pinned = model.pinned else { return false }
    return !pinned.0.windowIsFresh(pinned.1, at: model.displayDate)
  }
  private var reset: ResetLabel {
    ResetLabel(
      date: model.pinned?.1.resetsAt, now: model.displayDate, style: model.presentation.resetStyle)
  }

  var body: some View {
    Group {
      switch content {
      case .quota:
        CompactIndicatorView(
          model: model, showsDemoLabel: false, components: components,
          scale: min(1, (model.presentation.resolvedSideWidth - 18) / components.preferredWidth))
      case .reset where model.presentation.resetStyle != .hidden:
        VStack(spacing: 1) {
          Text(reset.primary).font(.system(size: 10, weight: .medium))
          if let secondary = reset.secondary {
            Text(secondary).font(.system(size: 9)).foregroundStyle(.secondary)
          }
        }.monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
          .opacity(stale ? 0.6 : 1)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(resetAccessibility)
          .help(resetAccessibility)
      case .window:
        HStack(spacing: 4) {
          if stale { Image(systemName: "clock").font(.system(size: 8)) }
          Text(model.pinned.map { shortWindowTitle($0.1) } ?? "—")
            .font(.system(size: 10, weight: .medium)).lineLimit(1).truncationMode(.tail)
        }.opacity(stale ? 0.6 : 1)
          .help(
            [
              model.selection?.agent.title, model.pinned?.1.title,
              stale ? localized("Устаревшие данные", "Stale reading") : nil,
            ].compactMap { $0 }.joined(separator: ". "))
      default:
        Color.clear.accessibilityHidden(true)
      }
    }
  }

  private var resetAccessibility: String {
    [
      model.selection?.agent.title, model.pinned?.1.title, reset.detail,
      stale ? localized("Устаревшие данные", "Stale reading") : nil,
    ]
    .compactMap { $0 }.joined(separator: ". ")
  }
}

private struct ResetLabel {
  let primary: String
  let secondary: String?
  let detail: String

  init(date: Date?, now: Date, style: ResetDisplayStyle) {
    guard let date, date.timeIntervalSince1970.isFinite else {
      primary = "—"
      secondary = nil
      detail = localized("Время сброса неизвестно", "Reset time is unknown")
      return
    }
    let fullDate = date.formatted(date: .abbreviated, time: .shortened)
    let remaining = date.timeIntervalSince(now)
    detail =
      localized("Сброс: ", "Reset: ") + fullDate
      + (remaining <= 0 ? localized(". Ожидаем новые данные", ". Awaiting a fresh reading") : "")
    if style == .dateTime {
      primary = date.formatted(.dateTime.day().month(.abbreviated))
      secondary = date.formatted(date: .omitted, time: .shortened)
    } else if remaining <= 0 {
      primary = localized("Ожидаем…", "Awaiting…")
      secondary = nil
    } else if remaining < 60 {
      primary = localized("< 1 мин", "< 1 min")
      secondary = nil
    } else {
      // Keep provider dates out of integer conversion unless the range is safe.
      let minutes = Int(min(remaining / 60, 525_600_000))
      if minutes >= 1440 {
        primary =
          "\(minutes / 1440) " + localized("д ", "d ") + "\((minutes % 1440) / 60) "
          + localized("ч", "h")
      } else if minutes >= 60 {
        primary =
          "\(minutes / 60) " + localized("ч ", "h ") + "\(minutes % 60) " + localized("м", "m")
      } else {
        primary = "\(minutes) " + localized("мин", "min")
      }
      secondary = nil
    }
  }
}

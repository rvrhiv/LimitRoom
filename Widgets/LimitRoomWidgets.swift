import AllowanceCore
import SwiftUI
import WidgetKit

private func text(_ ru: String, _ en: String) -> String {
  Locale.preferredLanguages.first?.hasPrefix("ru") == true ? ru : en
}

struct QuotaEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot?
  var setupRequired = false
}

struct QuotaTimeline: TimelineProvider {
  func placeholder(in context: Context) -> QuotaEntry { QuotaEntry(date: .now, snapshot: nil) }
  func getSnapshot(in context: Context, completion: @escaping (QuotaEntry) -> Void) {
    completion(QuotaEntry(date: .now, snapshot: read(), setupRequired: container() == nil))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaEntry>) -> Void) {
    let now = Date.now
    let snapshot = read()
    let boundaries = (snapshot?.readings ?? []).flatMap { reading -> [Date] in
      [reading.observedAt?.addingTimeInterval(600), reading.resetsAt].compactMap { $0 }
        .filter { $0 > now && $0 < now.addingTimeInterval(3600) }
    }
    let dates = Set([now] + boundaries).sorted()
    completion(
      Timeline(
        entries: dates.map {
          QuotaEntry(date: $0, snapshot: snapshot, setupRequired: container() == nil)
        },
        policy: .after(now.addingTimeInterval(1800))))
  }
  private func container() -> URL? {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "LimitRoomAppGroup") as? String,
      !group.isEmpty, !group.hasPrefix("."), !group.contains("$(")
    else { return nil }
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
  }
  private func read() -> WidgetSnapshot? {
    guard let container = container(),
      let data = try? Data(
        contentsOf: container.appendingPathComponent("limitroom-widget-v1.json")),
      data.count <= 262_144,
      let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
      snapshot.version == 1
    else { return nil }
    return snapshot
  }
}

struct QuotaWidgetView: View {
  let entry: QuotaEntry
  @Environment(\.widgetFamily) private var family

  private var pinned: WidgetReading? {
    guard let selection = entry.snapshot?.pinned else { return nil }
    return entry.snapshot?.readings.first {
      $0.agent == selection.agent && $0.windowID == selection.windowID
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
        Text("LimitRoom").font(.caption.weight(.semibold))
        Spacer()
      }.foregroundStyle(.secondary)
      if entry.setupRequired {
        Label(text("Завершите настройку виджета", "Finish widget setup"), systemImage: "gearshape")
          .font(.callout)
        Text(
          text(
            "Нужны подпись и общий контейнер App Group.",
            "Signing and a shared App Group container are required.")
        )
        .font(.caption).foregroundStyle(.secondary)
      } else if family == .systemSmall {
        if let reading = pinned {
          Gauge(value: reading.remainingPercent ?? 0, in: 0...100) {
            Text(reading.agent.title)
          } currentValueLabel: {
            Text(percent(reading)).monospacedDigit()
          }.gaugeStyle(.accessoryCircularCapacity)
          Text(reading.agent.title + " · " + reading.title).font(.caption).lineLimit(1)
          freshness(reading)
        } else {
          Text("—").font(.largeTitle)
          Text(text("Закрепите окно в LimitRoom", "Pin a window in LimitRoom")).font(.caption)
            .foregroundStyle(.secondary)
        }
      } else {
        HStack(alignment: .top, spacing: 16) {
          ForEach(AgentID.allCases) { agent in
            let reading =
              pinned?.agent == agent ? pinned : entry.snapshot?.readings.first { $0.agent == agent }
            VStack(alignment: .leading, spacing: 6) {
              Text(agent == .claude ? "Claude" : agent.title).font(.caption.weight(.semibold))
              Text(reading.map(percent) ?? "—").font(
                .system(size: 25, weight: .semibold, design: .rounded)
              ).monospacedDigit()
              if let reading {
                ProgressView(value: reading.remainingPercent ?? 0, total: 100).tint(.primary)
                Text(reading.title).font(.caption2).lineLimit(1)
                freshness(reading)
              } else {
                Text(text("Не подключён", "Not connected")).font(.caption2).foregroundStyle(
                  .secondary)
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }
    .containerBackground(.background, for: .widget)
    .widgetURL(URL(string: "limitroom://history"))
  }
  private func percent(_ reading: WidgetReading) -> String {
    guard let value = reading.remainingPercent, value.isFinite, (0...100).contains(value) else {
      return "—"
    }
    return "\(Int(value))%"
  }
  @ViewBuilder private func freshness(_ reading: WidgetReading) -> some View {
    if let observed = reading.observedAt {
      let fresh =
        reading.state == .ready && entry.date.timeIntervalSince(observed) < 600
        && observed <= entry.date.addingTimeInterval(60)
        && (reading.resetsAt.map { $0 > entry.date } ?? true)
      HStack(spacing: 3) {
        if !fresh { Image(systemName: "clock") }
        Text(observed, style: .time)
      }.font(.caption2).foregroundStyle(fresh ? Color.secondary : .orange)
        .accessibilityLabel(text("Время показания", "Observed at") + " " + observed.formatted())
    } else {
      Text(text("Нет данных", "No reading")).font(.caption2).foregroundStyle(.secondary)
    }
  }
}

@main
struct LimitRoomWidgets: Widget {
  let kind = "LimitRoomQuota"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: QuotaTimeline()) { entry in
      QuotaWidgetView(entry: entry)
    }
    .configurationDisplayName("LimitRoom")
    .description(
      text(
        "Остаток квот Codex, Claude Code и Cursor",
        "Remaining allowances for Codex, Claude Code and Cursor")
    )
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

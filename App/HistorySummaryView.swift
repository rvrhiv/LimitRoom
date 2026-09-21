import AllowanceCore
import SwiftUI

struct HistorySummaryView: View {
  @Bindable var model: AppModel
  let openHistory: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(localized("Статистика", "Statistics")).font(
          .system(size: 13, weight: .semibold))
        Spacer()
        StatisticsPeriodPicker(model: model)
      }
      StatisticsContentView(model: model, compact: true)
      Button(localized("Открыть полную историю…", "Open full history…"), action: openHistory)
        .buttonStyle(.bordered).controlSize(.small)
    }.padding(.vertical, 3)
  }
}

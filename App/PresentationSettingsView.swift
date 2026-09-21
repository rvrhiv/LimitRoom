import AllowanceCore
import AppKit
import SwiftUI

struct DisplayPreferencesControls: View {
  var model: AppModel
  @Bindable var preferences: PresentationPreferences
  @State private var editingLeft = true

  init(model: AppModel) {
    self.model = model
    preferences = model.presentation
  }

  private var sideContent: Binding<NotchSlotContent> {
    editingLeft ? $preferences.leftContent : $preferences.rightContent
  }
  private var sideComponents: Binding<IndicatorComponents> {
    editingLeft ? $preferences.leftComponents : $preferences.rightComponents
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      DisplayPreviewView(model: model)
      VStack(alignment: .leading, spacing: 10) {
        Text(localized("Где показывать квоту", "Where to show allowance")).font(.headline)
        Picker(localized("Режим", "Presentation"), selection: $preferences.mode) {
          ForEach(PresentationMode.allCases) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented).labelsHidden()
      }
      if preferences.mode == .menuBar {
        GroupBox(localized("Состав индикатора", "Indicator content")) {
          IndicatorComponentControls(
            title: localized("Строка меню", "Menu bar"),
            components: $preferences.menuComponents, requiresVisibleComponent: true
          )
          .padding(12)
        }
        Text(
          localized(
            "Выбери квоту в карточке агента на вкладке «Квоты». Этот выбор используется во всех индикаторах.",
            "Choose an allowance in its agent card on the Allowances tab. All indicators use that selection."
          )
        )
        .font(.callout).foregroundStyle(.secondary)
      } else {
        GroupBox {
          VStack(alignment: .leading, spacing: 14) {
            Text(localized("По сторонам камеры", "Beside the camera")).font(.headline)
            Picker(localized("Сторона", "Side"), selection: $editingLeft) {
              Text(localized("Слева", "Left")).tag(true)
              Text(localized("Справа", "Right")).tag(false)
            }.pickerStyle(.segmented).labelsHidden()
            Picker(localized("Содержимое", "Content"), selection: sideContent) {
              Text(localized("Квота", "Allowance")).tag(NotchSlotContent.quota)
              Text(localized("Сброс", "Reset")).tag(NotchSlotContent.reset)
              Text(localized("Окно", "Window")).tag(NotchSlotContent.window)
              Text(localized("Скрыто", "Hidden")).tag(NotchSlotContent.hidden)
            }.pickerStyle(.segmented).labelsHidden()
            if sideContent.wrappedValue == .quota {
              IndicatorComponentControls(
                title: editingLeft ? localized("Слева", "Left") : localized("Справа", "Right"),
                components: sideComponents)
            } else if sideContent.wrappedValue == .reset {
              Picker(localized("Формат сброса", "Reset format"), selection: $preferences.resetStyle)
              {
                ForEach(ResetDisplayStyle.allCases) { Text($0.title).tag($0) }
              }.pickerStyle(.segmented).labelsHidden()
            }
            Text(
              localized(
                "Обе стороны показывают одну выбранную квоту.",
                "Both sides show the same selected allowance.")
            )
            .font(.caption).foregroundStyle(.secondary)
          }.padding(10)
        }
        GroupBox {
          VStack(spacing: 10) {
            HStack {
              Text(localized("Ширина каждой стороны", "Width per side"))
              Spacer()
              Text("\(Int(preferences.resolvedSideWidth)) pt").monospacedDigit().foregroundStyle(
                .secondary)
            }
            Slider(value: $preferences.sideWidth, in: preferences.widthRange, step: 8) {
              Text(localized("Ширина каждой стороны", "Width per side"))
            }.labelsHidden()
            HStack {
              Text("56 pt").foregroundStyle(.secondary)
              Spacer()
              Button(localized("Вернуть 88 pt", "Reset to 88 pt")) { preferences.sideWidth = 88 }
                .buttonStyle(.borderless)
              Spacer()
              Text("\(Int(preferences.widthRange.upperBound)) pt").foregroundStyle(.secondary)
            }.font(.caption)
          }.padding(10)
        }
        HStack {
          Toggle(
            localized("Тактильный отклик при открытии", "Haptic feedback on opening"),
            isOn: $preferences.hapticsEnabled)
          Spacer()
          Button(localized("Попробовать", "Try it")) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
          }.disabled(!preferences.hapticsEnabled || model.isDemo)
        }
        Text(
          localized(
            "Нужен поддерживаемый трекпад. Боковые блоки могут перекрывать значки строки меню; при необходимости уменьши ширину.",
            "Requires a supported trackpad. The wings can cover menu-bar items; reduce their width if needed."
          )
        )
        .font(.caption).foregroundStyle(.secondary)
      }
      if let message = preferences.fallbackMessage {
        Text(message).font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

private struct IndicatorComponentControls: View {
  var title: String
  @Binding var components: IndicatorComponents
  var requiresVisibleComponent = false

  var body: some View {
    HStack(spacing: 12) {
      component(localized("Иконка", "Icon"), keyPath: \.icon)
      component(localized("Кольцо", "Ring"), keyPath: \.ring)
      component("%", keyPath: \.percentage)
      Spacer(minLength: 0)
    }.toggleStyle(.checkbox).controlSize(.small)
  }

  private func component(_ label: String, keyPath: WritableKeyPath<IndicatorComponents, Bool>)
    -> some View
  {
    Toggle(
      label,
      isOn: Binding(
        get: { components[keyPath: keyPath] },
        set: { components[keyPath: keyPath] = $0 }
      )
    )
    .disabled(
      requiresVisibleComponent && components.visibleCount == 1 && components[keyPath: keyPath]
    )
    .accessibilityLabel(title + ", " + label)
  }
}

struct DisplayPreviewView: View {
  var model: AppModel
  private let cameraWidth: CGFloat = 185
  private let cameraHeight: CGFloat = 32

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text(localized("Предпросмотр", "Live preview")).font(.system(size: 11, weight: .medium))
        Spacer()
        if model.isDemo { Text("DEMO").font(.system(size: 8, weight: .medium)) }
      }.foregroundStyle(.secondary)
      HStack {
        Text(localized("Строка меню", "Menu bar")).font(.system(size: 10)).foregroundStyle(
          .secondary)
        Spacer()
        MenuBarIndicatorImage(model: model, showsDemoLabel: false)
      }.padding(.horizontal, 12).frame(height: 34)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
      GeometryReader { proxy in
        let width = cameraWidth + model.presentation.leftWidth + model.presentation.rightWidth
        let scale = min(1, (proxy.size.width - 16) / width)
        VStack(spacing: 7) {
          NotchHeaderView(
            model: model, cameraWidth: cameraWidth,
            cameraLeading: model.presentation.leftWidth, height: cameraHeight
          )
          .frame(width: width, height: cameraHeight)
          .background(.black, in: NotchSilhouette())
          .scaleEffect(scale, anchor: .top)
          .frame(width: proxy.size.width, height: cameraHeight * scale, alignment: .top)
          Text(localized("У камеры · в уменьшенном масштабе", "Near the camera · scaled preview"))
            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.7))
        }.frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
      }.frame(height: 58)
        .background(
          Color(red: 0.25, green: 0.29, blue: 0.33), in: RoundedRectangle(cornerRadius: 8)
        )
        .clipped()
    }
  }
}

struct PresentationSettingsView: View {
  var model: AppModel
  let openSettings: () -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      DisplayPreviewView(model: model)
      Picker(
        localized("Расположение", "Location"),
        selection: Binding(
          get: { model.presentation.mode }, set: { model.presentation.mode = $0 })
      ) {
        ForEach(PresentationMode.allCases) { Text($0.title).tag($0) }
      }.pickerStyle(.segmented).labelsHidden()
      Text(
        localized(
          "Индикатор, подключение агентов и обновления — в одном окне настроек.",
          "Indicator, agent connections and updates — in one settings window.")
      )
      .font(.callout).foregroundStyle(.secondary)
      Button(action: openSettings) {
        Label(localized("Открыть настройки…", "Open settings…"), systemImage: "slider.horizontal.3")
          .frame(maxWidth: .infinity).padding(.vertical, 7).contentShape(Rectangle())
      }.buttonStyle(.borderedProminent)
      Divider()
      ForEach(AgentID.allCases) { agent in
        HStack {
          AgentIcon(agent: agent, size: 16)
          Text(agent.title)
          Spacer()
          Text(
            model.snapshots.first { $0.agent == agent }?.state.label ?? SourceState.needsSetup.label
          )
          .foregroundStyle(.secondary)
        }.font(.system(size: 11))
      }
    }.padding(14)
      .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
  }
}

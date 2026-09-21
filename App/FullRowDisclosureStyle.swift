import AppKit
import SwiftUI

/// The label, chevron and empty trailing area form one keyboard-accessible target.
struct FullRowDisclosureStyle: DisclosureGroupStyle {
  func makeBody(configuration: Configuration) -> some View {
    FullRowDisclosureBody(configuration: configuration)
  }
}

private struct FullRowDisclosureBody: View {
  let configuration: DisclosureGroupStyleConfiguration
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hovering = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
          configuration.isExpanded.toggle()
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
            .accessibilityHidden(true)
          configuration.label
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 4).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(hovering ? 0.065 : 0), in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityValue(
        configuration.isExpanded
          ? localized("Развёрнуто", "Expanded") : localized("Свёрнуто", "Collapsed")
      )
      .onContinuousHover { phase in
        switch phase {
        case .active:
          hovering = true
          NSCursor.pointingHand.set()
        case .ended:
          hovering = false
          NSCursor.arrow.set()
        }
      }
      .onDisappear { if hovering { NSCursor.arrow.set() } }
      if configuration.isExpanded { configuration.content }
    }
  }
}

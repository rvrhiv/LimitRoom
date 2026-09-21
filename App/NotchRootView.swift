import Observation
import SwiftUI

@MainActor @Observable
final class NotchPanelState {
  var isExpanded = false
  var isHeld = false
  var cameraWidth: CGFloat = 200
  var cameraHeight: CGFloat = 32
  var cameraLeading: CGFloat = 88
  var expandedHeight: CGFloat = 686
}

struct NotchRootView: View {
  var model: AppModel
  var state: NotchPanelState
  let open: () -> Void
  let toggleHold: () -> Void
  let close: () -> Void
  let openHistory: () -> Void
  let openSettings: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .top) {
        silhouette.fill(Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1))
        // The fixed-width dashboard must not widen the header before the native
        // panel expands. Each layer receives the panel's actual current width.
        NotchHeaderView(
          model: model, cameraWidth: state.cameraWidth, cameraLeading: state.cameraLeading,
          height: state.cameraHeight, open: open
        )
        .frame(width: geometry.size.width, height: state.cameraHeight)
        .transaction { transaction in
          transaction.animation = nil
          transaction.disablesAnimations = true
        }
        if state.isExpanded {
          DashboardView(
            model: model, style: .notch, isHeld: state.isHeld,
            toggleHold: toggleHold, close: close,
            openHistory: openHistory, openSettings: openSettings
          )
          .frame(
            width: NotchGeometry.expandedWidth, height: state.expandedHeight - state.cameraHeight
          )
          .padding(.top, state.cameraHeight)
          .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -8)))
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
      .clipShape(silhouette)
      .animation(
        reduceMotion ? .linear(duration: 0.1) : .easeOut(duration: 0.18), value: state.isExpanded)
    }
    .preferredColorScheme(.dark)
  }

  private var silhouette: NotchSilhouette {
    NotchSilhouette(bottomRadius: state.isExpanded ? 22 : 12, topRadius: state.isExpanded ? 12 : 6)
  }
}

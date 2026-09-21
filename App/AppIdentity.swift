import SwiftUI

enum AppIdentity {
  static var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Dev"
  }
  static var build: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
  }
  static var versionLabel: String { version == "Dev" ? version : "v\(version)" }
  static var versionDescription: String {
    "LimitRoom \(version) · " + localized("сборка ", "build ") + build
  }
}

/// The approved A / «Запас» vector, shared by headers and the native icon renderer.
struct AppIconView: View {
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 120, y: size.height / 120)
      let background = Path(
        roundedRect: CGRect(x: 4, y: 3, width: 112, height: 112), cornerRadius: 27)
      context.fill(
        background,
        with: .linearGradient(
          Gradient(colors: [
            Color(red: 48 / 255, green: 75 / 255, blue: 76 / 255),
            Color(red: 16 / 255, green: 27 / 255, blue: 34 / 255),
          ]),
          startPoint: CGPoint(x: 4, y: 3), endPoint: CGPoint(x: 116, y: 115)))
      context.stroke(
        Path(roundedRect: CGRect(x: 5, y: 4, width: 110, height: 110), cornerRadius: 26),
        with: .linearGradient(
          Gradient(colors: [.white.opacity(0.6), .white.opacity(0.05)]),
          startPoint: CGPoint(x: 0, y: 4), endPoint: CGPoint(x: 0, y: 114)),
        lineWidth: 1)
      context.stroke(
        Path(ellipseIn: CGRect(x: 29, y: 28, width: 62, height: 62)),
        with: .color(.white.opacity(0.09)), lineWidth: 11)
      var ring = Path()
      ring.addArc(
        center: CGPoint(x: 60, y: 59), radius: 31,
        startAngle: .degrees(45), endAngle: .degrees(135), clockwise: true)
      context.stroke(
        ring,
        with: .linearGradient(
          Gradient(colors: [
            Color(red: 228 / 255, green: 1, blue: 246 / 255),
            Color(red: 120 / 255, green: 204 / 255, blue: 176 / 255),
          ]),
          startPoint: CGPoint(x: 29, y: 28), endPoint: CGPoint(x: 91, y: 90)),
        style: StrokeStyle(lineWidth: 11, lineCap: .round))
      context.fill(
        Path(ellipseIn: CGRect(x: 57, y: 56, width: 6, height: 6)),
        with: .color(Color(red: 185 / 255, green: 230 / 255, blue: 215 / 255).opacity(0.85)))
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityLabel("LimitRoom")
  }
}

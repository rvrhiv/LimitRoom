import SwiftUI

/// A top-edge cutout: concave shoulders meet the menu bar, with round lower corners.
/// The physical camera lives inside this same silhouette, not above a second window.
struct NotchSilhouette: Shape {
  var bottomRadius: CGFloat = 12
  var topRadius: CGFloat = 6
  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(bottomRadius, topRadius) }
    set {
      bottomRadius = newValue.first
      topRadius = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    guard w > 0, h > 0 else { return Path() }
    let shoulder = min(topRadius, min(w / 4, h / 4))
    let bottom = min(bottomRadius, min((w - 2 * shoulder) / 2, h / 2))
    var p = Path()
    p.move(to: .zero)
    p.addLine(to: CGPoint(x: w, y: 0))
    p.addArc(
      center: CGPoint(x: w, y: shoulder), radius: shoulder,
      startAngle: .degrees(-90), endAngle: .degrees(-180), clockwise: true)
    p.addLine(to: CGPoint(x: w - shoulder, y: h - bottom))
    p.addQuadCurve(
      to: CGPoint(x: w - shoulder - bottom, y: h), control: CGPoint(x: w - shoulder, y: h))
    p.addLine(to: CGPoint(x: shoulder + bottom, y: h))
    p.addQuadCurve(to: CGPoint(x: shoulder, y: h - bottom), control: CGPoint(x: shoulder, y: h))
    p.addLine(to: CGPoint(x: shoulder, y: shoulder))
    p.addArc(
      center: CGPoint(x: 0, y: shoulder), radius: shoulder,
      startAngle: .degrees(0), endAngle: .degrees(-90), clockwise: true)
    p.closeSubpath()
    return p
  }
}

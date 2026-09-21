// Deterministically rasterize the approved vector, not an image-generation step.
// Run: swift Scripts/generate-icon.swift build/LimitRoom.iconset
import AppKit

guard CommandLine.arguments.count == 2 else { fatalError("Pass the iconset output directory") }
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
  CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}
func gradient(_ colors: [CGColor]) -> CGGradient {
  CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
    locations: [0, 1])!
}
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = size * scale
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: CGFloat(pixels) / 120, y: -CGFloat(pixels) / 120)
    context.setFillColor(color(21, 36, 44, 0.15))
    context.addPath(
      CGPath(
        roundedRect: CGRect(x: 4, y: 5, width: 112, height: 112),
        cornerWidth: 27, cornerHeight: 27, transform: nil))
    context.fillPath()
    context.saveGState()
    context.addPath(
      CGPath(
        roundedRect: CGRect(x: 4, y: 3, width: 112, height: 112),
        cornerWidth: 27, cornerHeight: 27, transform: nil))
    context.clip()
    context.drawLinearGradient(
      gradient([color(48, 75, 76), color(16, 27, 34)]),
      start: CGPoint(x: 4, y: 3), end: CGPoint(x: 116, y: 115), options: [])
    context.restoreGState()
    context.saveGState()
    context.addPath(
      CGPath(
        roundedRect: CGRect(x: 5, y: 4, width: 110, height: 110),
        cornerWidth: 26, cornerHeight: 26, transform: nil))
    context.setLineWidth(1)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
      gradient([color(255, 255, 255, 0.6), color(255, 255, 255, 0.05)]),
      start: CGPoint(x: 0, y: 4), end: CGPoint(x: 0, y: 114),
      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
    context.setStrokeColor(color(246, 255, 255, 0.09))
    context.setLineWidth(11)
    context.strokeEllipse(in: CGRect(x: 29, y: 28, width: 62, height: 62))
    context.saveGState()
    context.addArc(
      center: CGPoint(x: 60, y: 59), radius: 31,
      startAngle: .pi / 4, endAngle: 3 * .pi / 4, clockwise: true)
    context.setLineCap(.round)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
      gradient([color(228, 255, 246), color(120, 204, 176)]),
      start: CGPoint(x: 29, y: 28), end: CGPoint(x: 91, y: 90),
      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
    context.setFillColor(color(185, 230, 215, 0.85))
    context.fillEllipse(in: CGRect(x: 57, y: 56, width: 6, height: 6))
    let suffix = scale == 2 ? "@2x" : ""
    let file = output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: file)
  }
}
print("Rendered approved LimitRoom icon into \(output.path)")

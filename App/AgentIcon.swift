import AllowanceCore
import SwiftUI

/// Third-party agent identification, never LimitRoom's own application branding.
struct AgentIcon: View {
  var agent: AgentID?
  var size: CGFloat = 16

  var body: some View {
    Group {
      if agent == .codex {
        ChatGPTMark().fill(.primary).padding(size * 0.04)
      } else if agent == .claude {
        ClaudeMark().fill(.primary)
      } else if agent == .cursor {
        CursorMark().fill(.primary)
      } else {
        Image(systemName: agent?.symbol ?? "circle.dotted")
          .font(.system(size: size, weight: .medium))
      }
    }.frame(width: size, height: size).accessibilityHidden(true)
  }
}

/// Official Claude Spark, unchanged geometry from Claude Spark - Clay.svg.
/// Monochrome agent identification only; see THIRD_PARTY_NOTICES.md.
private struct ClaudeMark: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 18.7657, y: 62.4437))
    path.addLine(to: CGPoint(x: 37.1822, y: 52.1167))
    path.addLine(to: CGPoint(x: 37.4857, y: 51.2122))
    path.addLine(to: CGPoint(x: 37.1822, y: 50.7085))
    path.addLine(to: CGPoint(x: 36.2715, y: 50.7085))
    path.addLine(to: CGPoint(x: 33.1852, y: 50.5208))
    path.addLine(to: CGPoint(x: 22.6615, y: 50.2391))
    path.addLine(to: CGPoint(x: 13.5545, y: 49.8636))
    path.addLine(to: CGPoint(x: 4.70044, y: 49.3942))
    path.addLine(to: CGPoint(x: 2.47428, y: 48.9248))
    path.addLine(to: CGPoint(x: 0.399902, y: 46.1553))
    path.addLine(to: CGPoint(x: 0.602281, y: 44.794))
    path.addLine(to: CGPoint(x: 2.47428, y: 43.5266))
    path.addLine(to: CGPoint(x: 5.15579, y: 43.7613))
    path.addLine(to: CGPoint(x: 11.0754, y: 44.1837))
    path.addLine(to: CGPoint(x: 19.98, y: 44.794))
    path.addLine(to: CGPoint(x: 26.4055, y: 45.1695))
    path.addLine(to: CGPoint(x: 35.9679, y: 46.1553))
    path.addLine(to: CGPoint(x: 37.4857, y: 46.1553))
    path.addLine(to: CGPoint(x: 37.6881, y: 45.545))
    path.addLine(to: CGPoint(x: 37.1822, y: 45.1695))
    path.addLine(to: CGPoint(x: 36.7774, y: 44.794))
    path.addLine(to: CGPoint(x: 27.5692, y: 38.5508))
    path.addLine(to: CGPoint(x: 17.6021, y: 31.9791))
    path.addLine(to: CGPoint(x: 12.3908, y: 28.1769))
    path.addLine(to: CGPoint(x: 9.60812, y: 26.2524))
    path.addLine(to: CGPoint(x: 8.19147, y: 24.4686))
    path.addLine(to: CGPoint(x: 7.58433, y: 20.5256))
    path.addLine(to: CGPoint(x: 10.1141, y: 17.7091))
    path.addLine(to: CGPoint(x: 13.5545, y: 17.9438))
    path.addLine(to: CGPoint(x: 14.4146, y: 18.1785))
    path.addLine(to: CGPoint(x: 17.9056, y: 20.8542))
    path.addLine(to: CGPoint(x: 25.343, y: 26.6279))
    path.addLine(to: CGPoint(x: 35.0572, y: 33.7629))
    path.addLine(to: CGPoint(x: 36.4739, y: 34.9364))
    path.addLine(to: CGPoint(x: 37.0443, y: 34.5514))
    path.addLine(to: CGPoint(x: 37.1316, y: 34.2792))
    path.addLine(to: CGPoint(x: 36.4739, y: 33.1996))
    path.addLine(to: CGPoint(x: 31.212, y: 23.6706))
    path.addLine(to: CGPoint(x: 25.596, y: 13.9539))
    path.addLine(to: CGPoint(x: 23.0663, y: 9.91695))
    path.addLine(to: CGPoint(x: 22.4086, y: 7.52296))
    path.addCurve(
      to: CGPoint(x: 22.0038, y: 4.65957), control1: CGPoint(x: 22.1538, y: 6.51831),
      control2: CGPoint(x: 22.0038, y: 5.68714))
    path.addLine(to: CGPoint(x: 24.8877, y: 0.716544))
    path.addLine(to: CGPoint(x: 26.5067, y: 0.200195))
    path.addLine(to: CGPoint(x: 30.4025, y: 0.716544))
    path.addLine(to: CGPoint(x: 32.0215, y: 2.12477))
    path.addLine(to: CGPoint(x: 34.4501, y: 7.66379))
    path.addLine(to: CGPoint(x: 38.3458, y: 16.3478))
    path.addLine(to: CGPoint(x: 44.4172, y: 28.1769))
    path.addLine(to: CGPoint(x: 46.188, y: 31.6975))
    path.addLine(to: CGPoint(x: 47.1493, y: 34.9364))
    path.addLine(to: CGPoint(x: 47.5035, y: 35.9222))
    path.addLine(to: CGPoint(x: 48.1106, y: 35.9222))
    path.addLine(to: CGPoint(x: 48.1106, y: 35.3589))
    path.addLine(to: CGPoint(x: 48.6166, y: 28.6933))
    path.addLine(to: CGPoint(x: 49.5273, y: 20.5256))
    path.addLine(to: CGPoint(x: 50.438, y: 10.0108))
    path.addLine(to: CGPoint(x: 50.7415, y: 7.05356))
    path.addLine(to: CGPoint(x: 52.2088, y: 3.48605))
    path.addLine(to: CGPoint(x: 55.1433, y: 1.56148))
    path.addLine(to: CGPoint(x: 57.42, y: 2.64112))
    path.addLine(to: CGPoint(x: 59.292, y: 5.31674))
    path.addLine(to: CGPoint(x: 59.039, y: 7.05356))
    path.addLine(to: CGPoint(x: 57.926, y: 14.2824))
    path.addLine(to: CGPoint(x: 55.7504, y: 25.5952))
    path.addLine(to: CGPoint(x: 54.3337, y: 33.1996))
    path.addLine(to: CGPoint(x: 55.1433, y: 33.1996))
    path.addLine(to: CGPoint(x: 56.1046, y: 32.2138))
    path.addLine(to: CGPoint(x: 59.9497, y: 27.1442))
    path.addLine(to: CGPoint(x: 66.3752, y: 19.0704))
    path.addLine(to: CGPoint(x: 69.2085, y: 15.8784))
    path.addLine(to: CGPoint(x: 72.5478, y: 12.3579))
    path.addLine(to: CGPoint(x: 74.6728, y: 10.668))
    path.addLine(to: CGPoint(x: 78.7203, y: 10.668))
    path.addLine(to: CGPoint(x: 81.6548, y: 15.0804))
    path.addLine(to: CGPoint(x: 80.3394, y: 19.6337))
    path.addLine(to: CGPoint(x: 76.1906, y: 24.8911))
    path.addLine(to: CGPoint(x: 72.7502, y: 29.3504))
    path.addLine(to: CGPoint(x: 67.8172, y: 35.9595))
    path.addLine(to: CGPoint(x: 64.7562, y: 41.2734))
    path.addLine(to: CGPoint(x: 65.0307, y: 41.7118))
    path.addLine(to: CGPoint(x: 65.7681, y: 41.6489))
    path.addLine(to: CGPoint(x: 76.8989, y: 39.255))
    path.addLine(to: CGPoint(x: 82.9197, y: 38.1753))
    path.addLine(to: CGPoint(x: 90.1041, y: 36.9549))
    path.addLine(to: CGPoint(x: 93.3422, y: 38.457))
    path.addLine(to: CGPoint(x: 93.6963, y: 40.006))
    path.addLine(to: CGPoint(x: 92.4315, y: 43.151))
    path.addLine(to: CGPoint(x: 84.7411, y: 45.0287))
    path.addLine(to: CGPoint(x: 75.7353, y: 46.8594))
    path.addLine(to: CGPoint(x: 62.3244, y: 50.0164))
    path.addLine(to: CGPoint(x: 62.1759, y: 50.1358))
    path.addLine(to: CGPoint(x: 62.3512, y: 50.3958))
    path.addLine(to: CGPoint(x: 68.399, y: 50.9432))
    path.addLine(to: CGPoint(x: 70.9794, y: 51.084))
    path.addLine(to: CGPoint(x: 77.3037, y: 51.084))
    path.addLine(to: CGPoint(x: 89.0922, y: 51.9759))
    path.addLine(to: CGPoint(x: 92.1785, y: 53.9944))
    path.addLine(to: CGPoint(x: 93.9999, y: 56.4822))
    path.addLine(to: CGPoint(x: 93.6963, y: 58.4068))
    path.addLine(to: CGPoint(x: 88.9404, y: 60.8008))
    path.addLine(to: CGPoint(x: 82.5655, y: 59.2987))
    path.addLine(to: CGPoint(x: 67.6401, y: 55.7312))
    path.addLine(to: CGPoint(x: 62.5301, y: 54.4638))
    path.addLine(to: CGPoint(x: 61.8217, y: 54.4638))
    path.addLine(to: CGPoint(x: 61.8217, y: 54.8862))
    path.addLine(to: CGPoint(x: 66.0717, y: 59.064))
    path.addLine(to: CGPoint(x: 73.9139, y: 66.1051))
    path.addLine(to: CGPoint(x: 83.6786, y: 75.2116))
    path.addLine(to: CGPoint(x: 84.1845, y: 77.4648))
    path.addLine(to: CGPoint(x: 82.9197, y: 79.2485))
    path.addLine(to: CGPoint(x: 81.6042, y: 79.0608))
    path.addLine(to: CGPoint(x: 73.0032, y: 72.5829))
    path.addLine(to: CGPoint(x: 69.6639, y: 69.6726))
    path.addLine(to: CGPoint(x: 62.1759, y: 63.3356))
    path.addLine(to: CGPoint(x: 61.67, y: 63.3356))
    path.addLine(to: CGPoint(x: 61.67, y: 63.9928))
    path.addLine(to: CGPoint(x: 63.3902, y: 66.5276))
    path.addLine(to: CGPoint(x: 72.5478, y: 80.2812))
    path.addLine(to: CGPoint(x: 73.0032, y: 84.5059))
    path.addLine(to: CGPoint(x: 72.3454, y: 85.8672))
    path.addLine(to: CGPoint(x: 69.9675, y: 86.7121))
    path.addLine(to: CGPoint(x: 67.3871, y: 86.2427))
    path.addLine(to: CGPoint(x: 61.9735, y: 78.6852))
    path.addLine(to: CGPoint(x: 56.4587, y: 70.2359))
    path.addLine(to: CGPoint(x: 52.0064, y: 62.6315))
    path.addLine(to: CGPoint(x: 51.4687, y: 62.971))
    path.addLine(to: CGPoint(x: 48.8189, y: 91.2654))
    path.addLine(to: CGPoint(x: 47.6047, y: 92.7206))
    path.addLine(to: CGPoint(x: 44.7714, y: 93.8002))
    path.addLine(to: CGPoint(x: 42.3934, y: 92.0164))
    path.addLine(to: CGPoint(x: 41.1286, y: 89.1061))
    path.addLine(to: CGPoint(x: 42.3934, y: 83.3324))
    path.addLine(to: CGPoint(x: 43.9113, y: 75.8219))
    path.addLine(to: CGPoint(x: 45.1255, y: 69.8604))
    path.addLine(to: CGPoint(x: 46.2386, y: 62.4437))
    path.addLine(to: CGPoint(x: 46.9184, y: 59.9661))
    path.addLine(to: CGPoint(x: 46.8583, y: 59.8003))
    path.addLine(to: CGPoint(x: 46.3153, y: 59.8916))
    path.addLine(to: CGPoint(x: 40.7238, y: 67.5603))
    path.addLine(to: CGPoint(x: 32.2239, y: 79.0608))
    path.addLine(to: CGPoint(x: 25.4948, y: 86.2427))
    path.addLine(to: CGPoint(x: 23.8758, y: 86.8999))
    path.addLine(to: CGPoint(x: 21.0931, y: 85.4447))
    path.addLine(to: CGPoint(x: 21.3461, y: 82.863))
    path.addLine(to: CGPoint(x: 22.9145, y: 80.5629))
    path.addLine(to: CGPoint(x: 32.2239, y: 68.7338))
    path.addLine(to: CGPoint(x: 37.8399, y: 61.3641))
    path.addLine(to: CGPoint(x: 41.4594, y: 57.1337))
    path.addLine(to: CGPoint(x: 41.4242, y: 56.5218))
    path.addLine(to: CGPoint(x: 41.2244, y: 56.5048))
    path.addLine(to: CGPoint(x: 16.489, y: 72.6299))
    path.addLine(to: CGPoint(x: 12.0873, y: 73.1932))
    path.addLine(to: CGPoint(x: 10.1647, y: 71.4094))
    path.addLine(to: CGPoint(x: 10.4176, y: 68.4991))
    path.addLine(to: CGPoint(x: 11.3283, y: 67.5603))
    path.addLine(to: CGPoint(x: 18.7657, y: 62.4437))
    path.closeSubpath()
    let scale = min(rect.width, rect.height) / 94
    return path.applying(
      CGAffineTransform(
        a: scale, b: 0, c: 0, d: scale,
        tx: rect.midX - 47 * scale, ty: rect.midY - 47 * scale))
  }
}

/// Official Cursor 2D cube, unchanged geometry from CUBE_2D_DARK.svg.
/// Monochrome agent identification only; see THIRD_PARTY_NOTICES.md.
private struct CursorMark: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 457.43, y: 125.94))
    path.addLine(to: CGPoint(x: 244.42, y: 2.96))
    path.addCurve(
      to: CGPoint(x: 222.3, y: 2.96), control1: CGPoint(x: 237.58, y: -0.99),
      control2: CGPoint(x: 229.14, y: -0.99))
    path.addLine(to: CGPoint(x: 9.3, y: 125.94))
    path.addCurve(
      to: CGPoint(x: 0, y: 142.05), control1: CGPoint(x: 3.55, y: 129.26),
      control2: CGPoint(x: 0, y: 135.4))
    path.addLine(to: CGPoint(x: 0, y: 390.04))
    path.addCurve(
      to: CGPoint(x: 9.3, y: 406.15), control1: CGPoint(x: 0, y: 396.69),
      control2: CGPoint(x: 3.55, y: 402.83))
    path.addLine(to: CGPoint(x: 222.31, y: 529.13))
    path.addCurve(
      to: CGPoint(x: 244.43, y: 529.13), control1: CGPoint(x: 229.15, y: 533.08),
      control2: CGPoint(x: 237.59, y: 533.08))
    path.addLine(to: CGPoint(x: 457.44, y: 406.15))
    path.addCurve(
      to: CGPoint(x: 466.74, y: 390.04), control1: CGPoint(x: 463.19, y: 402.83),
      control2: CGPoint(x: 466.74, y: 396.69))
    path.addLine(to: CGPoint(x: 466.74, y: 142.05))
    path.addCurve(
      to: CGPoint(x: 457.44, y: 125.94), control1: CGPoint(x: 466.74, y: 135.4),
      control2: CGPoint(x: 463.19, y: 129.26))
    path.addLine(to: CGPoint(x: 457.43, y: 125.94))
    path.closeSubpath()
    path.move(to: CGPoint(x: 444.05, y: 151.99))
    path.addLine(to: CGPoint(x: 238.42, y: 508.15))
    path.addCurve(
      to: CGPoint(x: 233.36, y: 506.79), control1: CGPoint(x: 237.03, y: 510.55),
      control2: CGPoint(x: 233.36, y: 509.57))
    path.addLine(to: CGPoint(x: 233.36, y: 273.58))
    path.addCurve(
      to: CGPoint(x: 226.83, y: 262.27), control1: CGPoint(x: 233.36, y: 268.92),
      control2: CGPoint(x: 230.87, y: 264.61))
    path.addLine(to: CGPoint(x: 24.87, y: 145.67))
    path.addCurve(
      to: CGPoint(x: 26.23, y: 140.61), control1: CGPoint(x: 22.47, y: 144.28),
      control2: CGPoint(x: 23.45, y: 140.61))
    path.addLine(to: CGPoint(x: 437.49, y: 140.61))
    path.addCurve(
      to: CGPoint(x: 444.06, y: 152), control1: CGPoint(x: 443.33, y: 140.61),
      control2: CGPoint(x: 446.98, y: 146.94))
    path.addLine(to: CGPoint(x: 444.05, y: 152))
    path.closeSubpath()
    let scale = min(rect.width / 466.73, rect.height / 532.09)
    return path.applying(
      CGAffineTransform(
        a: scale, b: 0, c: 0, d: scale,
        tx: rect.midX - 233.365 * scale, ty: rect.midY - 266.045 * scale))
  }
}

/// OpenAI Blossom: unchanged filled path from the official brand guideline SVG.
/// Only its illustration's construction guides are omitted. See THIRD_PARTY_NOTICES.md.
private struct ChatGPTMark: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 249.176, y: 323.434))
    path.addLine(to: CGPoint(x: 249.176, y: 298.276))
    path.addCurve(
      to: CGPoint(x: 251.825, y: 293.509), control1: CGPoint(x: 249.176, y: 296.158),
      control2: CGPoint(x: 249.971, y: 294.569))
    path.addLine(to: CGPoint(x: 302.406, y: 264.381))
    path.addCurve(
      to: CGPoint(x: 325.973, y: 258.555), control1: CGPoint(x: 309.29, y: 260.409),
      control2: CGPoint(x: 317.5, y: 258.555))
    path.addCurve(
      to: CGPoint(x: 377.877, y: 309.399), control1: CGPoint(x: 357.75, y: 258.555),
      control2: CGPoint(x: 377.877, y: 283.185))
    path.addCurve(
      to: CGPoint(x: 377.611, y: 315.49), control1: CGPoint(x: 377.877, y: 311.253),
      control2: CGPoint(x: 377.877, y: 313.371))
    path.addLine(to: CGPoint(x: 325.178, y: 284.771))
    path.addCurve(
      to: CGPoint(x: 315.645, y: 284.771), control1: CGPoint(x: 322.001, y: 282.919),
      control2: CGPoint(x: 318.822, y: 282.919))
    path.addLine(to: CGPoint(x: 249.176, y: 323.434))
    path.closeSubpath()
    path.move(to: CGPoint(x: 367.283, y: 421.415))
    path.addLine(to: CGPoint(x: 367.283, y: 361.301))
    path.addCurve(
      to: CGPoint(x: 362.516, y: 353.092), control1: CGPoint(x: 367.283, y: 357.592),
      control2: CGPoint(x: 365.694, y: 354.945))
    path.addLine(to: CGPoint(x: 296.048, y: 314.43))
    path.addLine(to: CGPoint(x: 317.763, y: 301.982))
    path.addCurve(
      to: CGPoint(x: 323.058, y: 301.982), control1: CGPoint(x: 319.617, y: 300.925),
      control2: CGPoint(x: 321.206, y: 300.925))
    path.addLine(to: CGPoint(x: 373.639, y: 331.112))
    path.addCurve(
      to: CGPoint(x: 398.003, y: 375.069), control1: CGPoint(x: 388.205, y: 339.586),
      control2: CGPoint(x: 398.003, y: 357.592))
    path.addCurve(
      to: CGPoint(x: 367.283, y: 421.412), control1: CGPoint(x: 398.003, y: 395.195),
      control2: CGPoint(x: 386.087, y: 413.733))
    path.addLine(to: CGPoint(x: 367.283, y: 421.415))
    path.closeSubpath()
    path.move(to: CGPoint(x: 233.553, y: 368.452))
    path.addLine(to: CGPoint(x: 211.838, y: 355.742))
    path.addCurve(
      to: CGPoint(x: 209.19, y: 350.975), control1: CGPoint(x: 209.986, y: 354.684),
      control2: CGPoint(x: 209.19, y: 353.095))
    path.addLine(to: CGPoint(x: 209.19, y: 292.718))
    path.addCurve(
      to: CGPoint(x: 260.301, y: 242.932), control1: CGPoint(x: 209.19, y: 264.383),
      control2: CGPoint(x: 230.905, y: 242.932))
    path.addCurve(
      to: CGPoint(x: 290.49, y: 253.26), control1: CGPoint(x: 271.423, y: 242.932),
      control2: CGPoint(x: 281.748, y: 246.641))
    path.addLine(to: CGPoint(x: 238.321, y: 283.449))
    path.addCurve(
      to: CGPoint(x: 233.555, y: 291.659), control1: CGPoint(x: 235.146, y: 285.303),
      control2: CGPoint(x: 233.555, y: 287.951))
    path.addLine(to: CGPoint(x: 233.555, y: 368.455))
    path.addLine(to: CGPoint(x: 233.553, y: 368.452))
    path.closeSubpath()
    path.move(to: CGPoint(x: 280.292, y: 395.462))
    path.addLine(to: CGPoint(x: 249.176, y: 377.985))
    path.addLine(to: CGPoint(x: 249.176, y: 340.913))
    path.addLine(to: CGPoint(x: 280.292, y: 323.436))
    path.addLine(to: CGPoint(x: 311.407, y: 340.913))
    path.addLine(to: CGPoint(x: 311.407, y: 377.985))
    path.addLine(to: CGPoint(x: 280.292, y: 395.462))
    path.closeSubpath()
    path.move(to: CGPoint(x: 300.286, y: 475.968))
    path.addCurve(
      to: CGPoint(x: 270.097, y: 465.64), control1: CGPoint(x: 289.163, y: 475.968),
      control2: CGPoint(x: 278.837, y: 472.259))
    path.addLine(to: CGPoint(x: 322.264, y: 435.449))
    path.addCurve(
      to: CGPoint(x: 327.03, y: 427.239), control1: CGPoint(x: 325.441, y: 433.597),
      control2: CGPoint(x: 327.03, y: 430.949))
    path.addLine(to: CGPoint(x: 327.03, y: 350.445))
    path.addLine(to: CGPoint(x: 349.011, y: 363.155))
    path.addCurve(
      to: CGPoint(x: 351.66, y: 367.922), control1: CGPoint(x: 350.865, y: 364.213),
      control2: CGPoint(x: 351.66, y: 365.802))
    path.addLine(to: CGPoint(x: 351.66, y: 426.179))
    path.addCurve(
      to: CGPoint(x: 300.286, y: 475.965), control1: CGPoint(x: 351.66, y: 454.514),
      control2: CGPoint(x: 329.679, y: 475.965))
    path.addLine(to: CGPoint(x: 300.286, y: 475.968))
    path.closeSubpath()
    path.move(to: CGPoint(x: 237.525, y: 416.915))
    path.addLine(to: CGPoint(x: 186.944, y: 387.785))
    path.addCurve(
      to: CGPoint(x: 162.582, y: 343.827), control1: CGPoint(x: 172.378, y: 379.31),
      control2: CGPoint(x: 162.582, y: 361.305))
    path.addCurve(
      to: CGPoint(x: 193.563, y: 297.485), control1: CGPoint(x: 162.582, y: 323.436),
      control2: CGPoint(x: 174.763, y: 305.164))
    path.addLine(to: CGPoint(x: 193.563, y: 357.861))
    path.addCurve(
      to: CGPoint(x: 198.33, y: 366.071), control1: CGPoint(x: 193.563, y: 361.571),
      control2: CGPoint(x: 195.154, y: 364.217))
    path.addLine(to: CGPoint(x: 264.535, y: 404.467))
    path.addLine(to: CGPoint(x: 242.82, y: 416.915))
    path.addCurve(
      to: CGPoint(x: 237.525, y: 416.915), control1: CGPoint(x: 240.967, y: 417.972),
      control2: CGPoint(x: 239.377, y: 417.972))
    path.closeSubpath()
    path.move(to: CGPoint(x: 234.614, y: 460.343))
    path.addCurve(
      to: CGPoint(x: 182.71, y: 410.028), control1: CGPoint(x: 204.689, y: 460.343),
      control2: CGPoint(x: 182.71, y: 437.833))
    path.addCurve(
      to: CGPoint(x: 183.238, y: 403.672), control1: CGPoint(x: 182.71, y: 407.91),
      control2: CGPoint(x: 182.976, y: 405.792))
    path.addLine(to: CGPoint(x: 235.405, y: 433.863))
    path.addCurve(
      to: CGPoint(x: 244.938, y: 433.863), control1: CGPoint(x: 238.582, y: 435.715),
      control2: CGPoint(x: 241.763, y: 435.715))
    path.addLine(to: CGPoint(x: 311.407, y: 395.466))
    path.addLine(to: CGPoint(x: 311.407, y: 420.622))
    path.addCurve(
      to: CGPoint(x: 308.758, y: 425.389), control1: CGPoint(x: 311.407, y: 422.742),
      control2: CGPoint(x: 310.612, y: 424.331))
    path.addLine(to: CGPoint(x: 258.179, y: 454.519))
    path.addCurve(
      to: CGPoint(x: 234.611, y: 460.343), control1: CGPoint(x: 251.293, y: 458.491),
      control2: CGPoint(x: 243.083, y: 460.343))
    path.addLine(to: CGPoint(x: 234.614, y: 460.343))
    path.closeSubpath()
    path.move(to: CGPoint(x: 300.286, y: 491.854))
    path.addCurve(
      to: CGPoint(x: 365.167, y: 438.892), control1: CGPoint(x: 332.329, y: 491.854),
      control2: CGPoint(x: 359.073, y: 469.082))
    path.addCurve(
      to: CGPoint(x: 413.892, y: 375.073), control1: CGPoint(x: 394.825, y: 431.211),
      control2: CGPoint(x: 413.892, y: 403.406))
    path.addCurve(
      to: CGPoint(x: 391.648, y: 325.552), control1: CGPoint(x: 413.892, y: 356.535),
      control2: CGPoint(x: 405.948, y: 338.529))
    path.addCurve(
      to: CGPoint(x: 393.766, y: 308.87), control1: CGPoint(x: 392.972, y: 319.991),
      control2: CGPoint(x: 393.766, y: 314.43))
    path.addCurve(
      to: CGPoint(x: 327.562, y: 242.666), control1: CGPoint(x: 393.766, y: 271.003),
      control2: CGPoint(x: 363.048, y: 242.666))
    path.addCurve(
      to: CGPoint(x: 306.644, y: 246.109), control1: CGPoint(x: 320.413, y: 242.666),
      control2: CGPoint(x: 313.528, y: 243.723))
    path.addCurve(
      to: CGPoint(x: 260.301, y: 227.042), control1: CGPoint(x: 294.725, y: 234.457),
      control2: CGPoint(x: 278.307, y: 227.042))
    path.addCurve(
      to: CGPoint(x: 195.42, y: 280.004), control1: CGPoint(x: 228.258, y: 227.042),
      control2: CGPoint(x: 201.513, y: 249.815))
    path.addCurve(
      to: CGPoint(x: 146.694, y: 343.824), control1: CGPoint(x: 165.761, y: 287.685),
      control2: CGPoint(x: 146.694, y: 315.49))
    path.addCurve(
      to: CGPoint(x: 168.938, y: 393.344), control1: CGPoint(x: 146.694, y: 362.362),
      control2: CGPoint(x: 154.638, y: 380.368))
    path.addCurve(
      to: CGPoint(x: 166.819, y: 410.027), control1: CGPoint(x: 167.613, y: 398.906),
      control2: CGPoint(x: 166.819, y: 404.467))
    path.addCurve(
      to: CGPoint(x: 233.024, y: 476.231), control1: CGPoint(x: 166.819, y: 447.894),
      control2: CGPoint(x: 197.538, y: 476.231))
    path.addCurve(
      to: CGPoint(x: 253.943, y: 472.788), control1: CGPoint(x: 240.172, y: 476.231),
      control2: CGPoint(x: 247.058, y: 475.173))
    path.addCurve(
      to: CGPoint(x: 300.286, y: 491.854), control1: CGPoint(x: 265.859, y: 484.441),
      control2: CGPoint(x: 282.278, y: 491.854))
    path.closeSubpath()
    let scale = min(rect.width / 267.198, rect.height / 264.812)
    return path.applying(
      CGAffineTransform(
        a: scale, b: 0, c: 0, d: scale,
        tx: rect.midX - 280.293 * scale, ty: rect.midY - 359.448 * scale))
  }
}

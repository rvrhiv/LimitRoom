import AppKit

struct NotchGeometry: Equatable {
  let displayID: CGDirectDisplayID
  let screenFrame: CGRect
  let cameraFrame: CGRect
  let expandedHeight: CGFloat
  static let expandedWidth: CGFloat = 430

  @MainActor init?(screen: NSScreen) {
    guard
      let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
      CGDisplayIsBuiltin(number.uint32Value) != 0
    else { return nil }
    let top = screen.safeAreaInsets.top
    guard let left = screen.auxiliaryTopLeftArea,
      let right = screen.auxiliaryTopRightArea
    else { return nil }
    let width = screen.frame.width - left.width - right.width
    guard top > 0, !left.isEmpty, !right.isEmpty, width >= 100,
      width < screen.frame.width / 2, screen.frame.width >= Self.expandedWidth
    else { return nil }
    displayID = number.uint32Value
    screenFrame = screen.frame
    cameraFrame = CGRect(
      x: screen.frame.minX + left.width, y: screen.frame.maxY - top,
      width: width, height: top)
    let availableBodyHeight = cameraFrame.minY - screen.visibleFrame.minY - 14
    guard availableBodyHeight >= 300 else { return nil }
    expandedHeight = top + min(654, availableBodyHeight)
  }

  func panelFrame(expanded: Bool, leftWidth: CGFloat, rightWidth: CGFloat) -> CGRect {
    let left = min(max(0, leftWidth), cameraFrame.minX - screenFrame.minX)
    let right = min(max(0, rightWidth), screenFrame.maxX - cameraFrame.maxX)
    let width =
      expanded
      ? min(screenFrame.width, max(Self.expandedWidth, cameraFrame.width + 2 * max(left, right)))
      : cameraFrame.width + left + right
    let x =
      expanded
      ? min(screenFrame.maxX - width, max(screenFrame.minX, cameraFrame.midX - width / 2))
      : cameraFrame.minX - left
    let height = expanded ? expandedHeight : cameraFrame.height
    return CGRect(
      x: x, y: screenFrame.maxY - height,
      width: width, height: height)
  }
}

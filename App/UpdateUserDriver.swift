import Foundation
import Sparkle

@MainActor
final class UpdateUserDriver: NSObject, SPUUserDriver {
  private weak var controller: UpdateController?
  private var received: Double = 0
  private var expected: Double = 0

  init(controller: UpdateController) { self.controller = controller }

  func show(
    _ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void
  ) {
    // Normally configured by Info.plist. An unexpected permission request opts out.
    reply(
      SUUpdatePermissionResponse(
        automaticUpdateChecks: false, automaticUpdateDownloading: false, sendSystemProfile: false))
  }
  func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
    controller?.begin(.checking, cancellation: cancellation)
  }
  func showUpdateFound(
    with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void
  ) {
    reply(controller?.found(appcastItem, state: state) ?? .dismiss)
  }
  func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
  func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
  func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
    controller?.noUpdate(error)
    acknowledgement()
  }
  func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
    controller?.fail(error)
    acknowledgement()
  }
  func showDownloadInitiated(cancellation: @escaping () -> Void) {
    received = 0
    expected = 0
    controller?.begin(.downloading, cancellation: cancellation)
  }
  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
    expected = Double(expectedContentLength)
    controller?.setProgress(expected > 0 ? received / expected : nil)
  }
  func showDownloadDidReceiveData(ofLength length: UInt64) {
    received += Double(length)
    controller?.setProgress(expected > 0 ? received / expected : nil)
  }
  func showDownloadDidStartExtractingUpdate() { controller?.begin(.extracting) }
  func showExtractionReceivedProgress(_ progress: Double) { controller?.setProgress(progress) }
  func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
    reply(controller?.ready() ?? .skip)
  }
  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication: @escaping () -> Void
  ) {
    controller?.begin(.installing)
  }
  func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
    controller?.finish()
    acknowledgement()
  }
  func dismissUpdateInstallation() { controller?.finish() }
}

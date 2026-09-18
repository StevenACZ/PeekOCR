import Sparkle
import XCTest

@testable import PeekOCR

@MainActor
private final class UpdaterSessionSpy {
    var isInProgress = false
    var checkCount = 0

    var session: UpdateManager.UpdaterSession {
        UpdateManager.UpdaterSession(
            isInProgress: { self.isInProgress },
            checkForUpdates: { self.checkCount += 1 }
        )
    }
}

@MainActor
final class UpdateManagerTests: XCTestCase {

    private var manager: UpdateManager!
    private var spy: UpdaterSessionSpy!

    override func setUp() async throws {
        try await super.setUp()
        manager = UpdateManager()
        spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
    }

    private func surfacePendingUpdate() {
        _ = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )
    }

    private func surfaceFailedUpdate() {
        surfacePendingUpdate()
        manager.installPendingUpdate()
        manager.handleError("download failed")
    }

    // MARK: - Retry never arms the unattended install

    func testRetryOnANotDownloadedStageStopsAtTheReadyCard() {
        surfaceFailedUpdate()
        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))

        manager.retryPendingUpdate()

        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
        XCTAssertEqual(spy.checkCount, 2)

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )
        XCTAssertEqual(choice, .install)
        manager.handleDownloadInitiated()
        manager.handleExtractionStarted()

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        XCTAssertTrue(choices.isEmpty)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testRetryOnADownloadedStageStopsAtTheReadyCard() {
        surfaceFailedUpdate()

        manager.retryPendingUpdate()
        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .downloaded
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testRetryOnAnInstallingStageStopsAtTheReadyCard() {
        surfaceFailedUpdate()

        manager.retryPendingUpdate()
        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .installing
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testRetryThenInstallNowStillInstalls() {
        surfaceFailedUpdate()
        manager.retryPendingUpdate()
        _ = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

        manager.installNow()

        XCTAssertEqual(choices, [.install])
        XCTAssertEqual(manager.phase, .installing)
    }

    // MARK: - Install now still installs

    func testInstallNowOnADownloadedStageInstalls() {
        surfacePendingUpdate()
        manager.handleReadyToInstall { _ in }
        manager.installLater()

        manager.installNow()

        XCTAssertEqual(manager.phase, .installing)
        XCTAssertEqual(spy.checkCount, 1)

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .downloaded
        )
        XCTAssertEqual(choice, .install)

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        XCTAssertEqual(choices, [.install])
        XCTAssertEqual(manager.phase, .installing)
    }

    func testLaterKeepsTheReplyHeld() {
        surfacePendingUpdate()
        manager.installPendingUpdate()

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        XCTAssertTrue(choices.isEmpty)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

        manager.installLater()

        XCTAssertEqual(choices, [.dismiss])
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }
}

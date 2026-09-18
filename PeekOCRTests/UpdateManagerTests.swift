import AppKit
import Sparkle
import XCTest

@testable import PeekOCR

@MainActor
private final class UpdaterSessionSpy {
    var isInProgress = false
    var checkCount = 0
    var backgroundCheckCount = 0
    var onBackgroundCheck: () -> Void = {}

    var session: UpdateManager.UpdaterSession {
        UpdateManager.UpdaterSession(
            isInProgress: { self.isInProgress },
            checkForUpdates: { self.checkCount += 1 },
            checkForUpdatesInBackground: {
                self.backgroundCheckCount += 1
                self.onBackgroundCheck()
            }
        )
    }
}

@MainActor
final class UpdateManagerTests: XCTestCase {

    private var manager: UpdateManager!
    private var spy: UpdaterSessionSpy!
    private var savedAutoCheckDefault: Any?
    private var now: TimeInterval = 0

    override func setUp() async throws {
        try await super.setUp()
        savedAutoCheckDefault = UserDefaults.standard.object(forKey: UpdateManager.autoCheckDefaultsKey)
        manager = UpdateManager()
        spy = UpdaterSessionSpy()
        manager.updaterSession = spy.session
        now = 0
        manager.monotonicClock = { [unowned self] in self.now }
    }

    override func tearDown() async throws {
        manager.stopBackgroundDiscovery()
        manager = nil
        spy = nil
        if let savedAutoCheckDefault {
            UserDefaults.standard.set(savedAutoCheckDefault, forKey: UpdateManager.autoCheckDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UpdateManager.autoCheckDefaultsKey)
        }
        savedAutoCheckDefault = nil
        try await super.tearDown()
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
        XCTAssertTrue(choices.isEmpty)

        manager.installNow()

        XCTAssertEqual(choices, [.install])
        XCTAssertEqual(manager.phase, .installing)
    }

    func testUpdateButtonOnAPreparedStageStopsAtTheReadyCard() {
        surfacePendingUpdate()

        manager.installPendingUpdate()
        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .downloaded
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testTheResumeWindowOutlastsASlowAppcastFetch() {
        let window = Double(UpdateManager.sessionPollAttemptLimit) * UpdateManager.sessionPollInterval

        XCTAssertGreaterThanOrEqual(window, 70)
    }

    func testAResumePollWithoutALiveUpdaterClearsThePendingFlag() {
        surfacePendingUpdate()
        spy.isInProgress = true
        manager.retryPendingUpdate()
        manager.updaterSession = nil

        manager.startResumeCheck(attempt: 0)

        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
        XCTAssertTrue(manager.phaseAllowsQuietCheck)
    }

    func testAReadyCardSurvivesTheArmedResumeWatchdog() {
        surfacePendingUpdate()
        spy.isInProgress = true
        manager.retryPendingUpdate()
        XCTAssertEqual(manager.phase, .downloading(fraction: nil))

        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }
        XCTAssertTrue(choices.isEmpty)

        manager.startResumeCheck(attempt: 40)

        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))

        manager.installNow()

        XCTAssertEqual(choices, [.install])
        XCTAssertEqual(manager.phase, .installing)
    }

    func testRetryWithAHeldReplyKeepsTheReadyCard() {
        surfacePendingUpdate()
        manager.installPendingUpdate()
        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        manager.retryPendingUpdate()

        XCTAssertTrue(choices.isEmpty)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertEqual(spy.checkCount, 1)
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

    // MARK: - Silent discovery

    func testPanelOpenAsksForASilentCheck() {
        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 1)
        XCTAssertEqual(spy.checkCount, 0)
        XCTAssertEqual(manager.phase, .idle)
        XCTAssertEqual(manager.manualCheckStatus, .idle)
    }

    func testEverySurfaceAsksForASilentCheck() throws {
        let controller = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PeekOCR/Services/MenuBarStatusController.swift")
        let source = try String(contentsOf: controller, encoding: .utf8)

        let panelOpenBranch = try XCTUnwrap(source.range(of: "hosting.rootView = makePanelHost()"))
        let panelShown = try XCTUnwrap(
            source.range(of: "popover.show(relativeTo:", range: panelOpenBranch.upperBound..<source.endIndex))
        XCTAssertNotNil(
            source.range(
                of: "UpdateManager.shared.requestBackgroundCheck()",
                range: panelOpenBranch.upperBound..<panelShown.lowerBound))

        let aboutOpenBranch = try XCTUnwrap(
            source.range(of: "private func presentAboutWindow(reusing window: NSWindow?) -> NSWindow {"))
        let aboutHosting = try XCTUnwrap(
            source.range(
                of: "NSHostingController(rootView: AboutView())",
                range: aboutOpenBranch.upperBound..<source.endIndex))
        XCTAssertNotNil(
            source.range(
                of: "UpdateManager.shared.requestBackgroundCheck()",
                range: aboutOpenBranch.upperBound..<aboutHosting.lowerBound))
    }

    func testTheDiscoveryTimerRunsOnTheRunLoopAndAsksForACheck() {
        let fired = expectation(description: "the discovery timer asked for a silent check")
        fired.assertForOverFulfill = false
        spy.onBackgroundCheck = { fired.fulfill() }
        manager.backgroundCheckIntervalProvider = { 0.05 }

        manager.startBackgroundDiscovery()

        XCTAssertTrue(manager.backgroundDiscoveryArmed)
        wait(for: [fired], timeout: 5)
        manager.stopBackgroundDiscovery()
        XCTAssertEqual(spy.backgroundCheckCount, 1)
    }

    func testWakeAndTimerShareTheFiveMinuteThrottle() {
        manager.requestBackgroundCheck()
        now = UpdateManager.backgroundCheckThrottle - 1
        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 1)

        now = UpdateManager.backgroundCheckThrottle
        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 2)
    }

    func testWakeNotificationAsksForASilentCheck() {
        manager.startBackgroundDiscovery()
        defer { manager.stopBackgroundDiscovery() }

        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)

        XCTAssertTrue(manager.backgroundDiscoveryArmed)
        XCTAssertEqual(spy.backgroundCheckCount, 1)
    }

    func testDisabledAutoChecksFireNoTriggerAndDisarmTheTimer() {
        manager.setAutoCheckEnabled(true)
        XCTAssertTrue(manager.backgroundDiscoveryArmed)

        manager.setAutoCheckEnabled(false)
        manager.requestBackgroundCheck()

        XCTAssertFalse(manager.backgroundDiscoveryArmed)
        XCTAssertEqual(spy.backgroundCheckCount, 0)
    }

    func testBackgroundCheckIsSkippedWhileASessionIsInProgress() {
        spy.isInProgress = true

        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 0)
    }

    func testBackgroundCheckIsSkippedWhileADownloadRuns() {
        surfacePendingUpdate()
        manager.installPendingUpdate()
        manager.handleDownloadInitiated()

        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 0)
        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
    }

    func testSilentCheckThatFindsNothingChangesNoVisibleState() {
        manager.requestBackgroundCheck()

        manager.handleNotFound()

        XCTAssertEqual(manager.phase, .idle)
        XCTAssertEqual(manager.manualCheckStatus, .idle)
        XCTAssertNil(manager.pendingVersion)
    }

    func testSilentCheckThatFailsChangesNoVisibleState() {
        manager.requestBackgroundCheck()

        manager.handleError("offline")

        XCTAssertEqual(manager.phase, .idle)
        XCTAssertEqual(manager.manualCheckStatus, .idle)
    }

    func testSilentCheckOnAPreparedStageStopsAtTheReadyCard() {
        manager.requestBackgroundCheck()

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .downloaded
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    // MARK: - Manual check and Update click are never swallowed

    func testManualCheckIsNeverThrottled() {
        manager.requestBackgroundCheck()

        manager.checkForUpdatesManually()
        manager.checkForUpdatesManually()

        XCTAssertEqual(spy.checkCount, 2)
        XCTAssertEqual(manager.manualCheckStatus, .checking)
    }

    func testManualCheckDuringASilentSessionRunsWhenTheSessionEnds() {
        spy.isInProgress = true

        manager.checkForUpdatesManually()

        XCTAssertEqual(manager.manualCheckStatus, .checking)
        XCTAssertEqual(spy.checkCount, 0)

        spy.isInProgress = false
        manager.startManualCheck(attempt: 1)

        XCTAssertEqual(spy.checkCount, 1)
        XCTAssertEqual(manager.manualCheckStatus, .checking)

        manager.handleNotFound()

        XCTAssertEqual(manager.manualCheckStatus, .upToDate)
    }

    func testManualCheckGivesUpQuietlyWhenTheSessionNeverEnds() {
        spy.isInProgress = true
        manager.checkForUpdatesManually()
        XCTAssertEqual(manager.manualCheckStatus, .checking)

        manager.startManualCheck(attempt: UpdateManager.sessionPollAttemptLimit)

        XCTAssertEqual(spy.checkCount, 0)
        XCTAssertEqual(manager.manualCheckStatus, .idle)
        XCTAssertEqual(manager.phase, .idle)
    }

    func testUpdateClickDuringTheSilentSessionTeardownStillDownloads() {
        surfacePendingUpdate()
        spy.isInProgress = true

        manager.installPendingUpdate()

        XCTAssertEqual(manager.phase, .downloading(fraction: nil))
        XCTAssertEqual(spy.checkCount, 0)

        spy.isInProgress = false
        manager.startResumeCheck(attempt: 1)

        XCTAssertEqual(spy.checkCount, 1)

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .downloaded
        )
        var choices: [SPUUserUpdateChoice] = []
        manager.handleReadyToInstall { choices.append($0) }

        XCTAssertEqual(choice, .dismiss)
        XCTAssertTrue(choices.isEmpty)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testUpdateClickDuringARunningDownloadIsIgnored() {
        surfacePendingUpdate()
        manager.installPendingUpdate()
        _ = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )
        manager.handleDownloadInitiated()
        manager.handleDownloadExpectedLength(1_000)
        manager.handleDownloadReceived(bytes: 400)
        XCTAssertEqual(manager.phase, .downloading(fraction: 0.4))
        spy.isInProgress = true

        manager.installPendingUpdate()

        XCTAssertEqual(manager.phase, .downloading(fraction: 0.4))
        XCTAssertEqual(spy.checkCount, 1)
    }

    func testUpdateClickWhileInstallingIsIgnored() {
        surfacePendingUpdate()
        manager.installPendingUpdate()
        _ = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )
        manager.handleExtractionStarted()
        spy.isInProgress = true

        manager.installPendingUpdate()

        XCTAssertEqual(manager.phase, .installing)
        XCTAssertEqual(spy.checkCount, 1)
    }

    // MARK: - Quiet checks from a resting card

    private func surfacePostponedUpdate() {
        surfacePendingUpdate()
        manager.installPendingUpdate()
        _ = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )
        manager.handleDownloadInitiated()
        manager.handleDownloadExpectedLength(1_000)
        manager.handleDownloadReceived(bytes: 1_000)
        manager.handleExtractionStarted()
        manager.handleReadyToInstall { _ in }
        manager.installLater()
    }

    func testIdleAllowsAQuietCheck() {
        XCTAssertTrue(manager.phaseAllowsQuietCheck)
    }

    func testAnAvailableCardAllowsAQuietCheck() {
        surfacePendingUpdate()

        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
        XCTAssertTrue(manager.phaseAllowsQuietCheck)
    }

    func testAFailedCardAllowsAQuietCheck() {
        surfaceFailedUpdate()

        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
        XCTAssertTrue(manager.phaseAllowsQuietCheck)
    }

    func testDownloadingAndInstallingBlockAQuietCheck() {
        manager.handleDownloadInitiated()
        XCTAssertFalse(manager.phaseAllowsQuietCheck)

        manager.handleExtractionStarted()
        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testAHeldReadyReplyBlocksAQuietCheck() {
        surfacePendingUpdate()
        manager.handleReadyToInstall { _ in }

        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testThePostponedReadyCardBlocksAQuietCheck() {
        surfacePostponedUpdate()

        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testAnUpdateClickBlocksAQuietCheck() {
        surfacePendingUpdate()

        manager.installPendingUpdate()

        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testInstallNowBlocksAQuietCheck() {
        surfacePostponedUpdate()

        manager.installNow()

        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testAManualCheckInFlightBlocksAQuietCheck() {
        spy.isInProgress = true

        manager.checkForUpdatesManually()

        XCTAssertFalse(manager.phaseAllowsQuietCheck)
    }

    func testAQuietCheckWithoutALiveUpdaterIsSkippedAndKeepsTheThrottleFree() {
        manager.updaterSession = nil

        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 0)

        manager.updaterSession = spy.session
        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 1)
    }

    func testAQuietCheckRunsFromAFailedCard() {
        surfaceFailedUpdate()

        manager.requestBackgroundCheck()

        XCTAssertEqual(spy.backgroundCheckCount, 1)
        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
    }

    func testAnUnattendedCheckThatFindsTheSameVersionKeepsTheFailedCard() {
        surfaceFailedUpdate()

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(spy.backgroundCheckCount, 0)
        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .failed(version: "9.9.9"))
        XCTAssertEqual(manager.pendingVersion, "9.9.9")
    }

    func testAnUnattendedCheckThatFindsTheSameVersionKeepsTheAvailableCard() {
        surfacePendingUpdate()

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    }

    func testTheStagedUpdateReofferedUnattendedKeepsThePostponedReadyCard() {
        surfacePostponedUpdate()

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .installing
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testLaterDropsTheInstallConsent() {
        surfacePostponedUpdate()

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .readyToInstall(version: "9.9.9"))
    }

    func testAnUnattendedOlderVersionLeavesTheCardAlone() {
        surfacePendingUpdate()

        let choice = manager.handleUpdateFound(
            version: "9.9.8",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
        XCTAssertEqual(manager.pendingVersion, "9.9.9")
    }

    func testAnUnattendedNewerVersionReplacesTheAvailableCard() {
        surfacePendingUpdate()

        let choice = manager.handleUpdateFound(
            version: "9.9.10",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.10"))
    }

    func testAnUnattendedNewerVersionReplacesTheFailedCard() {
        surfaceFailedUpdate()

        let choice = manager.handleUpdateFound(
            version: "9.9.10",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.10"))
    }

    func testAManualCheckStillReportsAfterAQuietCheckWithoutAnAnswer() {
        surfaceFailedUpdate()
        manager.requestBackgroundCheck()
        XCTAssertEqual(spy.backgroundCheckCount, 1)

        manager.checkForUpdatesManually()

        XCTAssertEqual(manager.manualCheckStatus, .checking)
        XCTAssertEqual(spy.checkCount, 2)

        manager.handleNotFound()

        XCTAssertEqual(manager.manualCheckStatus, .upToDate)
        XCTAssertEqual(manager.phase, .idle)
    }

    func testAnUpdateClickStillDownloadsAfterAQuietCheckWithoutAnAnswer() {
        surfacePendingUpdate()
        manager.requestBackgroundCheck()
        XCTAssertEqual(spy.backgroundCheckCount, 1)

        manager.installPendingUpdate()

        XCTAssertEqual(manager.phase, .downloading(fraction: nil))

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(choice, .install)
    }

    func testAQueuedManualCheckKeepsItsSpinnerUntilItsOwnSessionAnswers() {
        surfacePendingUpdate()
        manager.requestBackgroundCheck()
        XCTAssertEqual(spy.backgroundCheckCount, 1)
        spy.isInProgress = true

        manager.checkForUpdatesManually()

        XCTAssertEqual(manager.manualCheckStatus, .checking)
        XCTAssertEqual(spy.checkCount, 0)

        let quietChoice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(quietChoice, .dismiss)
        XCTAssertEqual(manager.manualCheckStatus, .checking)
        XCTAssertFalse(manager.phaseAllowsQuietCheck)

        spy.isInProgress = false
        manager.startManualCheck(attempt: 1)
        XCTAssertEqual(spy.checkCount, 1)

        let manualChoice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(manualChoice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
        XCTAssertEqual(manager.manualCheckStatus, .idle)
    }

    func testAManualCheckFromAFailedCardCanOfferTheUpdateAgain() {
        surfaceFailedUpdate()

        manager.checkForUpdatesManually()
        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .notDownloaded
        )

        XCTAssertEqual(choice, .dismiss)
        XCTAssertEqual(manager.phase, .available(version: "9.9.9"))
    }

    func testInstallNowStillInstallsAfterAnUnattendedReoffer() {
        surfacePostponedUpdate()
        _ = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .installing
        )

        manager.installNow()

        XCTAssertEqual(manager.phase, .installing)

        let choice = manager.handleUpdateFound(
            version: "9.9.9",
            releasePage: nil,
            informationOnly: false,
            stage: .downloaded
        )

        XCTAssertEqual(choice, .install)
        XCTAssertEqual(manager.phase, .installing)
    }
}

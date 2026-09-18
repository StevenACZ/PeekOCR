//
//  UpdateManager.swift
//  PeekOCR
//
//  In-app updates via Sparkle. Background checks only surface a
//  pending update (update card + About capsule); downloading, installing, and
//  relaunching happen when the user clicks Install, with progress mirrored
//  in `phase`. Scheduled-check failures stay silent; only a user-requested
//  install surfaces errors.
//

import AppKit
import Combine
import Foundation
import Sparkle

@MainActor
final class UpdateManager: ObservableObject {

    static let shared = UpdateManager()

    enum Phase: Equatable {
        case idle
        case available(version: String)
        /// nil fraction = size unknown yet (indeterminate spinner).
        case downloading(fraction: Double?)
        case readyToInstall(version: String)
        case installing
        case failed(version: String)
    }

    struct UpdaterSession {
        let isInProgress: @MainActor () -> Bool
        let checkForUpdates: @MainActor () -> Void
        let checkForUpdatesInBackground: @MainActor () -> Void
    }

    enum ManualCheckStatus: Equatable {
        case idle
        case checking
        case upToDate
    }

    static let autoCheckDefaultsKey = "autoUpdateCheckEnabled"
    /// Local appcast testing only:
    /// `defaults write oli.PeekOCR updateFeedURLOverride <url>`.
    static let feedURLOverrideDefaultsKey = "updateFeedURLOverride"
    static let backgroundCheckInterval: TimeInterval = 30 * 60
    static let backgroundCheckThrottle: TimeInterval = 5 * 60
    static let sessionPollAttemptLimit = 40
    static let sessionPollInterval: TimeInterval = 0.25

    @Published private(set) var phase: Phase = .idle
    /// GitHub release page of the pending update (the appcast item's <link>).
    @Published private(set) var releasePageURL: URL?
    /// Ephemeral "you're up to date" feedback for the About window.
    @Published private(set) var manualCheckStatus: ManualCheckStatus = .idle
    @Published private(set) var autoCheckEnabled: Bool

    var updaterSession: UpdaterSession?
    var backgroundCheckIntervalProvider: @MainActor () -> TimeInterval = {
        UpdateManager.backgroundCheckInterval
    }
    /// Counts time spent asleep, so a wake never lands inside the throttle.
    var monotonicClock: @MainActor () -> TimeInterval = {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000
    }

    private var updater: SPUUpdater?
    private var driver: Driver?
    private var updaterDelegate: UpdaterDelegate?

    private var installRequested = false
    private var installNowRequested = false
    private var resumeCheckPending = false
    private var pendingInstallReply: ((SPUUserUpdateChoice) -> Void)?
    @Published private(set) var pendingVersion: String?
    private var pendingIsInformationOnly = false
    private var expectedDownloadBytes: UInt64 = 0
    private var receivedDownloadBytes: UInt64 = 0
    private var manualCheckPending = false
    private var manualCheckWaiting = false
    private var manualCheckResetTask: Task<Void, Never>?
    private var backgroundCheckTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var lastBackgroundCheck: TimeInterval?

    init() {
        // Defaults to enabled until the Settings toggle writes the key.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.autoCheckDefaultsKey) == nil {
            autoCheckEnabled = true
        } else {
            autoCheckEnabled = defaults.bool(forKey: Self.autoCheckDefaultsKey)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard updater == nil else { return }

        let driver = Driver(manager: self)
        let updaterDelegate = UpdaterDelegate()
        let updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: driver,
            delegate: updaterDelegate
        )
        updater.automaticallyDownloadsUpdates = false
        updater.automaticallyChecksForUpdates = autoCheckEnabled

        do {
            try updater.start()
        } catch {
            AppLogger.error("Updater failed to start: \(error.localizedDescription)", logger: AppLogger.updates)
            return
        }

        self.driver = driver
        self.updaterDelegate = updaterDelegate
        self.updater = updater
        updaterSession = UpdaterSession(
            isInProgress: { updater.sessionInProgress },
            checkForUpdates: { updater.checkForUpdates() },
            checkForUpdatesInBackground: { updater.checkForUpdatesInBackground() }
        )
        if autoCheckEnabled { startBackgroundDiscovery() }
    }

    func setAutoCheckEnabled(_ enabled: Bool) {
        autoCheckEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.autoCheckDefaultsKey)
        updater?.automaticallyChecksForUpdates = enabled
        if enabled {
            startBackgroundDiscovery()
        } else {
            stopBackgroundDiscovery()
        }
    }

    // MARK: - Silent discovery

    var backgroundDiscoveryArmed: Bool { backgroundCheckTimer != nil }

    var phaseAllowsQuietCheck: Bool {
        guard !installRequested, !installNowRequested, !resumeCheckPending,
            !manualCheckPending, pendingInstallReply == nil
        else { return false }
        switch phase {
        case .idle, .available, .failed:
            return true
        case .downloading, .readyToInstall, .installing:
            return false
        }
    }

    private var sessionIsUserDriven: Bool {
        installRequested || installNowRequested || resumeCheckPending
            || (manualCheckPending && !manualCheckWaiting)
    }

    func startBackgroundDiscovery() {
        guard backgroundCheckTimer == nil else { return }
        let interval = backgroundCheckIntervalProvider()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.requestBackgroundCheck()
            }
        }
        timer.tolerance = interval / 10
        RunLoop.main.add(timer, forMode: .common)
        backgroundCheckTimer = timer
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.requestBackgroundCheck()
            }
        }
    }

    func stopBackgroundDiscovery() {
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    func requestBackgroundCheck() {
        guard let updaterSession, autoCheckEnabled, phaseAllowsQuietCheck else { return }
        guard updaterSession.isInProgress() == false else { return }
        let now = monotonicClock()
        if let lastBackgroundCheck, now - lastBackgroundCheck < Self.backgroundCheckThrottle {
            return
        }
        lastBackgroundCheck = now
        updaterSession.checkForUpdatesInBackground()
    }

    // MARK: - User actions

    /// Update card / About capsule click: download the pending update and stop
    /// at the ready card. Information-only updates open the release page.
    func installPendingUpdate() {
        guard let updaterSession else { return }
        if pendingIsInformationOnly {
            openReleasePage()
            return
        }
        let resumeAlreadyPending = resumeCheckPending
        if updaterSession.isInProgress(), !resumeAlreadyPending {
            switch phase {
            case .downloading, .installing:
                return
            case .idle, .available, .readyToInstall, .failed:
                break
            }
        }
        installRequested = true
        installNowRequested = false
        phase = .downloading(fraction: nil)
        guard !resumeAlreadyPending else { return }
        resumeCheckPending = true
        startResumeCheck(attempt: 0)
    }

    /// Ready-to-install card: run the held Sparkle reply, or resume a session
    /// the user ended earlier with "later".
    func installNow() {
        guard phase != .installing else { return }
        if let reply = pendingInstallReply {
            pendingInstallReply = nil
            installRequested = true
            phase = .installing
            reply(.install)
            return
        }
        guard updaterSession != nil else { return }
        installRequested = true
        installNowRequested = true
        resumeCheckPending = true
        phase = .installing
        startResumeCheck(attempt: 0)
    }

    /// Must never arm the unattended install.
    func retryPendingUpdate() {
        guard updaterSession != nil else { return }
        if pendingIsInformationOnly {
            openReleasePage()
            return
        }
        guard pendingInstallReply == nil else {
            phase = .readyToInstall(version: pendingVersion ?? "")
            return
        }
        installRequested = true
        installNowRequested = false
        resumeCheckPending = true
        phase = .downloading(fraction: nil)
        startResumeCheck(attempt: 0)
    }

    /// Resumes the prepared update once Sparkle releases the dismissed session.
    func startResumeCheck(attempt: Int) {
        guard resumeCheckPending else { return }
        guard let updaterSession else { return }
        guard updaterSession.isInProgress() else {
            resumeCheckPending = false
            updaterSession.checkForUpdates()
            return
        }
        guard attempt < Self.sessionPollAttemptLimit else {
            installRequested = false
            installNowRequested = false
            resumeCheckPending = false
            phase = .failed(version: pendingVersion ?? "")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sessionPollInterval) { [weak self] in
            self?.startResumeCheck(attempt: attempt + 1)
        }
    }

    /// Ends the Sparkle session; the card keeps offering the prepared update.
    func installLater() {
        guard let reply = pendingInstallReply else { return }
        pendingInstallReply = nil
        installRequested = false
        reply(.dismiss)
    }

    /// About window: explicit re-check with visible "up to date" feedback.
    func checkForUpdatesManually() {
        guard let updaterSession else { return }
        manualCheckResetTask?.cancel()
        manualCheckPending = true
        manualCheckStatus = .checking
        guard updaterSession.isInProgress() else {
            manualCheckWaiting = false
            updaterSession.checkForUpdates()
            return
        }
        guard !manualCheckWaiting else { return }
        manualCheckWaiting = true
        startManualCheck(attempt: 0)
    }

    /// Sparkle refuses a user check while a silent session is still in flight,
    /// so the manual check waits for that session to end.
    func startManualCheck(attempt: Int) {
        guard manualCheckWaiting, let updaterSession else { return }
        guard attempt < Self.sessionPollAttemptLimit else {
            manualCheckWaiting = false
            finishManualCheck(status: .idle)
            return
        }
        guard updaterSession.isInProgress() else {
            manualCheckWaiting = false
            updaterSession.checkForUpdates()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sessionPollInterval) { [weak self] in
            self?.startManualCheck(attempt: attempt + 1)
        }
    }

    func openReleasePage() {
        guard let releasePageURL else { return }
        NSWorkspace.shared.open(releasePageURL)
    }

    // MARK: - Driver events (pure state transitions, unit-testable)

    func handleUpdateFound(
        version: String,
        releasePage: URL?,
        informationOnly: Bool,
        stage: SPUUserUpdateStage
    ) -> SPUUserUpdateChoice {
        if !sessionIsUserDriven, phase != .idle, let pendingVersion,
            !Self.isNewerVersion(version, than: pendingVersion)
        {
            return .dismiss
        }
        resumeCheckPending = false
        pendingVersion = version
        pendingIsInformationOnly = informationOnly
        releasePageURL = releasePage
        finishManualCheck(status: .idle)

        switch stage {
        case .downloaded, .installing:
            if installNowRequested && !informationOnly {
                phase = .installing
                return .install
            }
            installRequested = false
            installNowRequested = false
            phase = .readyToInstall(version: version)
            return .dismiss
        case .notDownloaded:
            if installRequested && !informationOnly {
                phase = .downloading(fraction: nil)
                return .install
            }
            installRequested = false
            installNowRequested = false
            phase = .available(version: version)
            return .dismiss
        @unknown default:
            installRequested = false
            installNowRequested = false
            phase = .available(version: version)
            return .dismiss
        }
    }

    func handleDownloadInitiated() {
        expectedDownloadBytes = 0
        receivedDownloadBytes = 0
        phase = .downloading(fraction: nil)
    }

    func handleDownloadExpectedLength(_ length: UInt64) {
        expectedDownloadBytes = length
    }

    func handleDownloadReceived(bytes: UInt64) {
        receivedDownloadBytes += bytes
        guard expectedDownloadBytes > 0 else { return }
        let fraction = min(1.0, Double(receivedDownloadBytes) / Double(expectedDownloadBytes))
        phase = .downloading(fraction: fraction)
    }

    func handleExtractionStarted() {
        phase = .installing
    }

    func handleReadyToInstall(reply: @escaping (SPUUserUpdateChoice) -> Void) {
        resumeCheckPending = false
        if installNowRequested {
            installNowRequested = false
            phase = .installing
            reply(.install)
            return
        }
        pendingInstallReply = reply
        phase = .readyToInstall(version: pendingVersion ?? "")
    }

    func handleInstalling() {
        phase = .installing
    }

    func handleNotFound() {
        guard !resumeCheckPending else {
            pendingInstallReply = nil
            return
        }
        guard sessionIsUserDriven || phase == .idle else { return }
        installRequested = false
        installNowRequested = false
        pendingInstallReply = nil
        pendingVersion = nil
        pendingIsInformationOnly = false
        releasePageURL = nil
        phase = .idle
        finishManualCheck(status: .upToDate)
    }

    /// Scheduled-check errors stay silent; a user-requested install shows
    /// a retryable failure row instead.
    func handleError(_ message: String) {
        guard !resumeCheckPending else {
            pendingInstallReply = nil
            return
        }
        guard sessionIsUserDriven || phase == .idle else { return }
        finishManualCheck(status: .idle)
        installNowRequested = false
        pendingInstallReply = nil
        if installRequested, let pendingVersion {
            AppLogger.error("Update install failed: \(message)", logger: AppLogger.updates)
            phase = .failed(version: pendingVersion)
        } else {
            AppLogger.debug("Update check failed silently", logger: AppLogger.updates)
            switch phase {
            case .readyToInstall, .installing:
                phase = .readyToInstall(version: pendingVersion ?? "")
            case .idle, .available, .downloading, .failed:
                phase = pendingVersion.map { .available(version: $0) } ?? .idle
            }
        }
        installRequested = false
    }

    /// Sparkle tears the session down (abort or completion); only roll back
    /// an in-flight progress state.
    func handleDismissInstallation() {
        guard !resumeCheckPending else {
            pendingInstallReply = nil
            return
        }
        installRequested = false
        installNowRequested = false
        pendingInstallReply = nil
        switch phase {
        case .installing, .readyToInstall:
            phase = .readyToInstall(version: pendingVersion ?? "")
        case .downloading:
            phase = pendingVersion.map { .available(version: $0) } ?? .idle
        case .idle, .available, .failed:
            break
        }
    }

    private static func isNewerVersion(_ version: String, than current: String) -> Bool {
        SUStandardVersionComparator.default.compareVersion(version, toVersion: current) == .orderedDescending
    }

    private func finishManualCheck(status: ManualCheckStatus) {
        guard manualCheckPending, !manualCheckWaiting else { return }
        manualCheckPending = false
        manualCheckStatus = status
        guard status != .idle else { return }
        manualCheckResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.manualCheckStatus = .idle
        }
    }
}

// MARK: - Sparkle user driver

/// Bridges Sparkle's user-interaction callbacks onto the manager's phase.
/// Every callback arrives on the main actor (the protocol is NS_SWIFT_UI_ACTOR).
@MainActor
private final class Driver: NSObject, SPUUserDriver {

    private unowned let manager: UpdateManager

    init(manager: UpdateManager) {
        self.manager = manager
    }

    func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        // Unreached: SUEnableAutomaticChecks in Info.plist suppresses the prompt.
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}

    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        let choice = manager.handleUpdateFound(
            version: appcastItem.displayVersionString,
            releasePage: appcastItem.infoURL,
            informationOnly: appcastItem.isInformationOnlyUpdate,
            stage: state.stage
        )
        reply(choice)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        manager.handleNotFound()
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        manager.handleError(error.localizedDescription)
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        manager.handleDownloadInitiated()
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        manager.handleDownloadExpectedLength(expectedContentLength)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        manager.handleDownloadReceived(bytes: length)
    }

    func showDownloadDidStartExtractingUpdate() {
        manager.handleExtractionStarted()
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        manager.handleReadyToInstall(reply: reply)
    }

    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        manager.handleInstalling()
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func dismissUpdateInstallation() {
        manager.handleDismissInstallation()
    }
}

// MARK: - Sparkle updater delegate

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {

    /// Local-testing escape hatch: point the feed at a local appcast.
    /// Production resolves SUFeedURL from Info.plist (return nil).
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        UserDefaults.standard.string(forKey: UpdateManager.feedURLOverrideDefaultsKey)
    }
}

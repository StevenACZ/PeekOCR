//
//  UpdateManager.swift
//  PeekOCR
//
//  In-app updates via Sparkle. The scheduled daily check only surfaces a
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

    enum ManualCheckStatus: Equatable {
        case idle
        case checking
        case upToDate
    }

    static let autoCheckDefaultsKey = "autoUpdateCheckEnabled"
    /// Local appcast testing only:
    /// `defaults write oli.PeekOCR updateFeedURLOverride <url>`.
    static let feedURLOverrideDefaultsKey = "updateFeedURLOverride"

    @Published private(set) var phase: Phase = .idle
    /// GitHub release page of the pending update (the appcast item's <link>).
    @Published private(set) var releasePageURL: URL?
    /// Ephemeral "you're up to date" feedback for the About window.
    @Published private(set) var manualCheckStatus: ManualCheckStatus = .idle
    @Published private(set) var autoCheckEnabled: Bool

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
    private var manualCheckResetTask: Task<Void, Never>?

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
    }

    func setAutoCheckEnabled(_ enabled: Bool) {
        autoCheckEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.autoCheckDefaultsKey)
        updater?.automaticallyChecksForUpdates = enabled
    }

    // MARK: - User actions

    /// Update card / About capsule click: download + install + relaunch, or
    /// retry after a failure. Information-only updates open the release page.
    func installPendingUpdate() {
        guard let updater else { return }
        if pendingIsInformationOnly {
            openReleasePage()
            return
        }
        guard updater.sessionInProgress == false else { return }
        installRequested = true
        phase = .downloading(fraction: nil)
        updater.checkForUpdates()
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
        guard updater != nil else { return }
        installRequested = true
        installNowRequested = true
        resumeCheckPending = true
        phase = .installing
        startResumeCheck(attempt: 0)
    }

    /// Resumes the prepared update once Sparkle releases the dismissed session.
    private func startResumeCheck(attempt: Int) {
        guard resumeCheckPending else { return }
        guard let updater else { return }
        guard updater.sessionInProgress else {
            resumeCheckPending = false
            updater.checkForUpdates()
            return
        }
        guard attempt < 40 else {
            installRequested = false
            installNowRequested = false
            resumeCheckPending = false
            phase = .failed(version: pendingVersion ?? "")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
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
        guard let updater, updater.sessionInProgress == false else { return }
        manualCheckResetTask?.cancel()
        manualCheckPending = true
        manualCheckStatus = .checking
        updater.checkForUpdates()
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
        resumeCheckPending = false
        pendingVersion = version
        pendingIsInformationOnly = informationOnly
        releasePageURL = releasePage
        finishManualCheck(status: .idle)

        switch stage {
        case .downloaded, .installing:
            if installRequested || installNowRequested {
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

    private func finishManualCheck(status: ManualCheckStatus) {
        guard manualCheckPending else { return }
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

//
//  GifClipEditorView+Actions.swift
//  PeekOCR
//
//  Actions and export logic for the clip editor view.
//

import AppKit
import SwiftUI
import os

extension GifClipEditorView {
    var canExport: Bool {
        guard state.isReady, state.durationSeconds > 0 else { return false }
        return selectionDuration >= Constants.Gif.minimumClipDurationSeconds
    }

    var exportDisabledMessage: String? {
        guard state.isReady, state.durationSeconds > 0 else { return nil }
        guard !isBlockingUI else { return nil }

        let minSeconds = Int(Constants.Gif.minimumClipDurationSeconds.rounded())

        if state.durationSeconds < Constants.Gif.minimumClipDurationSeconds {
            return "El clip grabado dura \(formatSeconds(state.durationSeconds)). El mínimo para exportar es \(minSeconds)s. Regraba."
        }

        guard selectionDuration < Constants.Gif.minimumClipDurationSeconds else { return nil }
        return "Selecciona al menos \(minSeconds)s en la línea de tiempo para exportar."
    }

    var isBlockingUI: Bool {
        exportOverlay != nil
    }

    func exportSelectedFormat() async {
        guard exportOverlay == nil else { return }
        guard canExport else {
            errorAlertTitle = "No se pudo exportar"
            errorAlertMessage = exportDisabledMessage ?? "No se puede exportar con la selección actual."
            return
        }

        errorAlertMessage = nil
        frameCaptureFeedback = nil
        let destinationName = friendlySaveDirectoryName()
        exportOverlay = .exporting(format: exportFormat, destinationName: destinationName)

        do {
            let finalVideoURL = state.videoURL
            let url: URL
            switch exportFormat {
            case .gif:
                url = try await GifExportService.shared.exportGif(
                    videoURL: state.videoURL,
                    timeRange: state.currentTimeRange(),
                    outputDirectory: saveDirectory,
                    options: gifOptions
                )
            case .video:
                url = try await VideoExportService.shared.exportVideo(
                    videoURL: state.videoURL,
                    timeRange: state.currentTimeRange(),
                    outputDirectory: saveDirectory,
                    options: videoOptions
                )
            }

            state.stopPlayback()
            try? FileManager.default.removeItem(at: finalVideoURL)
            exportOverlay = .success(format: exportFormat, destinationName: destinationName)
            try? await Task.sleep(nanoseconds: 900_000_000)
            onExport(ClipExportResult(url: url, format: exportFormat))
        } catch {
            AppLogger.capture.error("Clip export failed: \(error.localizedDescription)")
            errorAlertTitle = "No se pudo exportar"
            errorAlertMessage = error.localizedDescription
            exportOverlay = nil
        }
    }

    func captureCurrentFrame() async {
        guard !isSavingFrame, exportOverlay == nil else { return }
        guard state.isReady, state.durationSeconds > 0 else { return }

        isSavingFrame = true
        defer { isSavingFrame = false }

        state.stopPlayback()

        let settings = ScreenshotSettings.shared
        let captureTime = max(0, min(state.currentSeconds, state.durationSeconds))
        frameCaptureFeedback = makeFrameCaptureProgressFeedback(settings: settings)

        do {
            let image = try await VideoFrameCaptureService.shared.extractFrameImage(
                videoURL: state.videoURL,
                at: captureTime
            )
            let savedURL = await ScreenshotService.shared.processScreenshot(image)

            let displayText = savedURL?.lastPathComponent ?? frameCaptureFallbackHistoryText(settings: settings)
            HistoryManager.shared.addItem(
                CaptureItem(
                    text: displayText,
                    captureType: .screenshot
                ))

            CaptureSoundService.shared.playCapture()

            if let savedURL {
                AppLogger.capture.info("Video frame captured: \(savedURL.lastPathComponent)")
            } else {
                AppLogger.capture.info("Video frame captured without file output")
            }
            showFrameCaptureFeedback(makeFrameCaptureSuccessFeedback(savedURL: savedURL, settings: settings))
        } catch {
            AppLogger.capture.error("Video frame capture failed: \(error.localizedDescription)")
            frameCaptureFeedback = nil
            errorAlertTitle = "No se pudo guardar la captura"
            errorAlertMessage = error.localizedDescription
        }
    }

    func reRecord() async {
        state.stopPlayback()
        frameCaptureFeedback = nil

        let windowToHide = NSApp.keyWindow
        windowToHide?.orderOut(nil)
        defer {
            windowToHide?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        AppLogger.capture.info("GIF clip re-record requested")
        guard
            let newVideoURL = await ClipRecordingController.shared.record(
                maxDurationSeconds: GifClipSettings.shared.effectiveMaxDurationSeconds)
        else {
            AppLogger.capture.info("GIF clip re-record cancelled")
            return
        }

        let oldVideoURL = state.videoURL
        await state.setVideo(url: newVideoURL)
        try? FileManager.default.removeItem(at: oldVideoURL)
    }

    func configureKeyboardShortcuts() {
        keyboardHandler.onCancel = {
            let finalVideoURL = state.videoURL
            state.stopPlayback()
            try? FileManager.default.removeItem(at: finalVideoURL)
            onCancel()
        }
        keyboardHandler.onTogglePlay = {
            togglePlayPause()
        }
        keyboardHandler.onStepFrame = { delta in
            stepFrame(delta)
        }
        keyboardHandler.setup()
    }

    func togglePlayPause() {
        if state.isPreviewPlaying {
            state.stopPlayback()
        } else {
            state.playSelection()
        }
    }

    func stepFrame(_ delta: Int) {
        state.stopPlayback()
        state.stepFrame(delta: delta)
    }

    var selectionDuration: Double {
        max(0, state.endSeconds - state.startSeconds)
    }

    func primaryExportButtonTitle() -> String {
        if let overlay = exportOverlay {
            switch overlay {
            case .exporting:
                return "Exportando…"
            case .success:
                return "Listo"
            }
        }
        switch exportFormat {
        case .gif:
            return "Exportar GIF"
        case .video:
            return "Exportar MP4"
        }
    }

    private func formatSeconds(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0.0s" }
        return String(format: "%.1fs", max(0, seconds))
    }

    private func makeFrameCaptureProgressFeedback(settings: ScreenshotSettings) -> GifClipActionFeedback {
        GifClipActionFeedback(
            tone: .progress,
            title: frameCaptureProgressTitle(settings: settings),
            message: frameCaptureProgressMessage(settings: settings),
            badgeText: settings.imageFormat.displayName
        )
    }

    private func makeFrameCaptureSuccessFeedback(savedURL: URL?, settings: ScreenshotSettings) -> GifClipActionFeedback {
        GifClipActionFeedback(
            tone: .success,
            title: frameCaptureSuccessTitle(savedURL: savedURL, settings: settings),
            message: savedURL?.lastPathComponent ?? frameCaptureFallbackHistoryText(settings: settings),
            badgeText: settings.imageFormat.displayName
        )
    }

    private func frameCaptureProgressTitle(settings: ScreenshotSettings) -> String {
        settings.saveToFile ? "Guardando frame…" : "Copiando frame…"
    }

    private func frameCaptureProgressMessage(settings: ScreenshotSettings) -> String {
        switch (settings.saveToFile, settings.copyToClipboard) {
        case (true, true):
            return "Se guardará en \(friendlyDirectoryName(for: settings.saveDirectoryURL)) y se copiará al portapapeles."
        case (true, false):
            return "Se guardará como \(settings.imageFormat.displayName) en \(friendlyDirectoryName(for: settings.saveDirectoryURL))."
        case (false, true):
            return "Se copiará al portapapeles."
        case (false, false):
            return "Se procesará con la configuración actual."
        }
    }

    private func frameCaptureSuccessTitle(savedURL: URL?, settings: ScreenshotSettings) -> String {
        switch (savedURL != nil, settings.copyToClipboard) {
        case (true, true):
            return "Frame guardado y copiado"
        case (true, false):
            return "Frame guardado"
        case (false, true):
            return "Frame copiado"
        case (false, false):
            return "Frame procesado"
        }
    }

    private func frameCaptureFallbackHistoryText(settings: ScreenshotSettings) -> String {
        settings.copyToClipboard ? "Captura copiada al portapapeles" : "Frame procesado"
    }

    private func showFrameCaptureFeedback(_ feedback: GifClipActionFeedback) {
        frameCaptureFeedback = feedback

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if frameCaptureFeedback == feedback {
                frameCaptureFeedback = nil
            }
        }
    }

    private func friendlySaveDirectoryName() -> String {
        friendlyDirectoryName(for: saveDirectory)
    }

    private func friendlyDirectoryName(for directory: URL) -> String {
        let path = directory.path
        if path.contains("/Downloads") || path.contains("/Descargas") {
            return "Descargas"
        }
        if path.contains("/Desktop") || path.contains("/Escritorio") {
            return "Escritorio"
        }
        return directory.lastPathComponent
    }
}

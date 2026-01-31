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
            exportError = exportDisabledMessage ?? "No se puede exportar con la selección actual."
            return
        }

        exportError = nil
        exportOverlay = .exporting(format: exportFormat)

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
            exportOverlay = .success(format: exportFormat)
            try? await Task.sleep(nanoseconds: 900_000_000)
            onExport(ClipExportResult(url: url, format: exportFormat))
        } catch {
            AppLogger.capture.error("Clip export failed: \(error.localizedDescription)")
            exportError = error.localizedDescription
            exportOverlay = nil
        }
    }

    func reRecord() async {
        state.stopPlayback()

        let windowToHide = NSApp.keyWindow
        windowToHide?.orderOut(nil)
        defer {
            windowToHide?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        AppLogger.capture.info("GIF clip re-record requested")
        guard let newVideoURL = await GifRecordingController.shared.record(maxDurationSeconds: GifClipSettings.shared.maxDurationSeconds) else {
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
            return "Exportar Video"
        }
    }

    private func formatSeconds(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0.0s" }
        return String(format: "%.1fs", max(0, seconds))
    }
}

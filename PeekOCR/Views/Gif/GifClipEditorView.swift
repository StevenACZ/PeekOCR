//
//  GifClipEditorView.swift
//  PeekOCR
//
//  Post-recording editor for trimming a video and exporting it as a GIF.
//

import AppKit
import SwiftUI
import os

/// Editor UI for selecting a trim range and exporting a GIF
struct GifClipEditorView: View {
    let videoURL: URL
    let saveDirectory: URL
    let onExport: (URL) -> Void
    let onCancel: () -> Void

    @StateObject private var state: GifClipEditorState
    @State private var exportOptions = GifExportOptions()
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var keyboardHandler = GifClipKeyboardHandler()

    init(
        videoURL: URL,
        saveDirectory: URL,
        onExport: @escaping (URL) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.videoURL = videoURL
        self.saveDirectory = saveDirectory
        self.onExport = onExport
        self.onCancel = onCancel
        _state = StateObject(wrappedValue: GifClipEditorState(
            videoURL: videoURL,
            maxDurationSeconds: Constants.Gif.maxDurationSeconds
        ))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                mainContent
                Divider()
                bottomBar
            }
            .disabled(isExporting || !state.isReady)

            if isExporting {
                GifExportLoadingOverlay()
            }
        }
        .frame(minWidth: 1120, minHeight: 680)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await state.prepare()
        }
        .onAppear {
            configureKeyboardShortcuts()
        }
        .onDisappear {
            keyboardHandler.teardown()
            state.stopPlayback()
        }
        .alert("No se pudo exportar el GIF", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(exportError ?? "Error desconocido")
        }
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            leftPane
            Divider()
            GifClipSidebarView(
                options: $exportOptions,
                outputDirectory: saveDirectory,
                selectionDurationSeconds: selectionDuration
            )
        }
    }

    private var leftPane: some View {
        VStack(spacing: 14) {
            GifClipVideoPreviewView(
                player: state.player,
                isPlaying: state.isPreviewPlaying,
                currentSeconds: state.currentSeconds,
                durationSeconds: state.durationSeconds,
                onTogglePlay: togglePlayPause,
                onStepBackward: { stepFrame(-1) },
                onStepForward: { stepFrame(1) }
            )
            timelineSection
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var timelineSection: some View {
        VStack(spacing: 10) {
            if let message = state.loadErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if state.durationSeconds > 0 {
                GifClipTimelineView(
                    startSeconds: $state.startSeconds,
                    endSeconds: $state.endSeconds,
                    durationSeconds: state.durationSeconds,
                    currentSeconds: state.currentSeconds,
                    stepSeconds: Constants.Gif.trimStepSeconds,
                    minimumSelectionSeconds: Constants.Gif.minimumClipDurationSeconds,
                    onScrub: { seconds in
                        state.stopPlayback()
                        state.seek(toSeconds: seconds)
                    },
                    onBeginEditing: {
                        state.stopPlayback()
                    }
                )

                GifClipTimelineReadoutView(startSeconds: state.startSeconds, endSeconds: state.endSeconds)
            } else {
                Text("Cargando…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Cancelar", role: .cancel) {
                let finalVideoURL = state.videoURL
                state.stopPlayback()
                try? FileManager.default.removeItem(at: finalVideoURL)
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Regrabar") {
                Task { await reRecord() }
            }
            .buttonStyle(.bordered)

            Button {
                Task { await exportGif() }
            } label: {
                Text(isExporting ? "Exportando…" : "Exportar GIF")
                    .frame(minWidth: 130)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting || !canExport)
        }
        .padding(16)
    }

    private var canExport: Bool {
        guard state.isReady, state.durationSeconds > 0 else { return false }
        let duration = state.endSeconds - state.startSeconds
        return duration >= Constants.Gif.minimumClipDurationSeconds
    }

    private func exportGif() async {
        guard !isExporting else { return }
        isExporting = true
        exportError = nil

        do {
            let finalVideoURL = state.videoURL
            let url = try await GifExportService.shared.exportGif(
                videoURL: state.videoURL,
                timeRange: state.currentTimeRange(),
                outputDirectory: saveDirectory,
                options: exportOptions
            )
            state.stopPlayback()
            try? FileManager.default.removeItem(at: finalVideoURL)
            onExport(url)
        } catch {
            AppLogger.capture.error("GIF export failed: \(error.localizedDescription)")
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    private func reRecord() async {
        state.stopPlayback()

        let windowToHide = NSApp.keyWindow
        windowToHide?.orderOut(nil)
        defer {
            windowToHide?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        AppLogger.capture.info("GIF clip re-record requested")
        guard let newVideoURL = await GifRecordingController.shared.record(maxDurationSeconds: Constants.Gif.maxDurationSeconds) else {
            AppLogger.capture.info("GIF clip re-record cancelled")
            return
        }

        let oldVideoURL = state.videoURL
        await state.setVideo(url: newVideoURL)
        try? FileManager.default.removeItem(at: oldVideoURL)
    }

    private func configureKeyboardShortcuts() {
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

    private func togglePlayPause() {
        if state.isPreviewPlaying {
            state.stopPlayback()
        } else {
            state.playSelection()
        }
    }

    private func stepFrame(_ delta: Int) {
        state.stopPlayback()
        state.stepFrame(delta: delta)
    }

    private var selectionDuration: Double {
        max(0, state.endSeconds - state.startSeconds)
    }
}

// MARK: - Preview

#Preview {
    Text("GifClipEditorView Preview")
        .frame(width: 1120, height: 680)
}

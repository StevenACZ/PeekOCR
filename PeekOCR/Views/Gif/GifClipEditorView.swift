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
    let onExport: (ClipExportResult) -> Void
    let onCancel: () -> Void

    @StateObject var state: GifClipEditorState
    @State var exportFormat: ClipExportFormat
    @State var gifOptions: GifExportOptions
    @State var videoOptions: VideoExportOptions
    @State var exportOverlay: ClipExportOverlayState?
    @State var exportError: String?
    @State var keyboardHandler = GifClipKeyboardHandler()

    init(
        videoURL: URL,
        saveDirectory: URL,
        onExport: @escaping (ClipExportResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.videoURL = videoURL
        self.saveDirectory = saveDirectory
        self.onExport = onExport
        self.onCancel = onCancel

        let clipSettings = GifClipSettings.shared
        _exportFormat = State(initialValue: clipSettings.defaultExportFormat)
        _gifOptions = State(initialValue: clipSettings.makeDefaultGifOptions())
        _videoOptions = State(initialValue: clipSettings.makeDefaultVideoOptions())

        _state = StateObject(wrappedValue: GifClipEditorState(
            videoURL: videoURL,
            maxDurationSeconds: clipSettings.maxDurationSeconds
        ))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                mainContent
                Divider()
                bottomBar
            }
            .disabled(isBlockingUI || !state.isReady)

            if let overlay = exportOverlay {
                ClipExportOverlay(state: overlay)
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
        .alert("No se pudo exportar", isPresented: Binding(
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
                exportFormat: $exportFormat,
                gifOptions: $gifOptions,
                videoOptions: $videoOptions,
                outputDirectory: saveDirectory,
                selectionDurationSeconds: selectionDuration,
                sourceNominalFps: state.sourceNominalFps,
                exportDisabledMessage: exportDisabledMessage
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

            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    Task { await exportSelectedFormat() }
                } label: {
                    Text(primaryExportButtonTitle())
                        .frame(minWidth: 130)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBlockingUI || !canExport)
            }
        }
        .padding(16)
    }
}

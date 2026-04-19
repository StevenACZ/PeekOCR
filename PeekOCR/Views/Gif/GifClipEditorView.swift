//
//  GifClipEditorView.swift
//  PeekOCR
//
//  Post-recording editor for trimming a video and exporting it as a GIF or MP4.
//

import AppKit
import SwiftUI
import os

/// Editor UI for selecting a trim range and exporting a GIF or video
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
    @State var errorAlertTitle = "Error"
    @State var errorAlertMessage: String?
    @State var isSavingFrame = false
    @State var frameCaptureFeedback: GifClipActionFeedback?
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
        .alert(errorAlertTitle, isPresented: Binding(
            get: { errorAlertMessage != nil },
            set: { if !$0 { errorAlertMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorAlertMessage ?? "Error desconocido")
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
        VStack(spacing: 16) {
            GifClipVideoPreviewView(
                player: state.player,
                isPlaying: state.isPreviewPlaying,
                currentSeconds: state.currentSeconds,
                durationSeconds: state.durationSeconds,
                isCaptureFrameDisabled: isBlockingUI || isSavingFrame || !state.isReady || state.durationSeconds <= 0,
                onTogglePlay: togglePlayPause,
                onStepBackward: { stepFrame(-1) },
                onStepForward: { stepFrame(1) },
                onCaptureFrame: {
                    Task { await captureCurrentFrame() }
                }
            )
            timelineSection
        }
        .padding(20)
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
        HStack(alignment: .center, spacing: 12) {
            Button("Cancelar", role: .cancel) {
                let finalVideoURL = state.videoURL
                state.stopPlayback()
                try? FileManager.default.removeItem(at: finalVideoURL)
                onCancel()
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.large)

            Spacer()

            if let feedback = frameCaptureFeedback {
                GifClipActionFeedbackView(feedback: feedback)
                    .frame(maxWidth: 320)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                Button {
                    Task { await reRecord() }
                } label: {
                    Label("Regrabar", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isBlockingUI || isSavingFrame)

                Button {
                    Task { await exportSelectedFormat() }
                } label: {
                    Text(primaryExportButtonTitle())
                        .frame(minWidth: 130)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isBlockingUI || isSavingFrame || !canExport)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: frameCaptureFeedback)
    }
}

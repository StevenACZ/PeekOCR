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
    @State private var filmstripFrames: [CGImage?] = Array(repeating: nil, count: GifClipFilmstrip.frameCount)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

        _state = StateObject(wrappedValue: GifClipEditorState(videoURL: videoURL))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                mainContent
                Divider()
                bottomBar
            }
            .disabled(isBlockingUI || !state.isReady)
            .scaleEffect(exportOverlay != nil && !reduceMotion ? 0.985 : 1)

            if let overlay = exportOverlay {
                ClipExportOverlay(state: overlay)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.32), value: exportOverlay)
        .frame(minWidth: 1120, minHeight: 680)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await state.prepare()
        }
        .task(id: state.durationSeconds > 0 ? state.videoURL : nil) {
            filmstripFrames = Array(repeating: nil, count: GifClipFilmstrip.frameCount)
            guard state.durationSeconds > 0 else { return }
            await GifClipFilmstrip.load(videoURL: state.videoURL, durationSeconds: state.durationSeconds) { index, frame in
                if filmstripFrames.indices.contains(index) { filmstripFrames[index] = frame }
            }
        }
        .onAppear {
            configureKeyboardShortcuts()
        }
        .onDisappear {
            keyboardHandler.teardown()
            state.stopPlayback()
        }
        .alert(
            errorAlertTitle,
            isPresented: Binding(
                get: { errorAlertMessage != nil },
                set: { if !$0 { errorAlertMessage = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(errorAlertMessage ?? "common.unknown_error".localized)
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
        .opacity(state.isReady ? 1 : 0.35)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: state.isReady)
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
                    isPlaying: state.isPreviewPlaying,
                    frames: filmstripFrames,
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
                Text("common.loading".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button("common.cancel".localized, role: .cancel) {
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
                    Label("clip_editor.rerecord".localized, systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isBlockingUI || isSavingFrame)

                Button {
                    Task { await exportSelectedFormat() }
                } label: {
                    Label(primaryExportButtonTitle(), systemImage: exportFormat == .gif ? "photo.stack" : "film")
                        .labelStyle(.titleAndIcon)
                        .frame(minWidth: 130)
                        .contentTransition(.opacity)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: primaryExportButtonTitle())
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

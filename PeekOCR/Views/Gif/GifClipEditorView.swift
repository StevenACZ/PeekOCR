//
//  GifClipEditorView.swift
//  PeekOCR
//
//  SwiftUI editor for trimming a recorded video and exporting it as an optimized GIF.
//

import SwiftUI
import os

/// Editor UI for selecting a trim range and exporting a GIF
struct GifClipEditorView: View {
    let videoURL: URL
    let saveDirectory: URL
    let onExport: (URL) -> Void
    let onCancel: () -> Void

    @StateObject private var state: GifClipEditorState
    @State private var isExporting = false
    @State private var exportError: String?

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
                header
                Divider()
                content
                Divider()
                footer
            }
            .disabled(isExporting)

            if isExporting {
                GifExportLoadingOverlay()
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await state.prepare()
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

    private var header: some View {
        HStack {
            Image(systemName: "film")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Exportar GIF")
                    .font(.headline)
                Text("Selecciona el rango y exporta con calidad media")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Max \(Constants.Gif.maxDurationSeconds)s")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
    }

    private var content: some View {
        HStack(spacing: 0) {
            mainPanel
            Divider()
            sidePanel
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 12) {
            NonInteractiveVideoPlayer(player: state.player)
                .onDisappear { state.stopPlayback() }

            rangeTimeline

            playbackControls
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var playbackControls: some View {
        HStack(spacing: 8) {
            Button {
                state.seek(toSeconds: state.startSeconds)
            } label: {
                Label("Ir al inicio", systemImage: "backward.end")
            }

            Button {
                if state.isPreviewPlaying {
                    state.stopPlayback()
                } else {
                    state.playSelection()
                }
            } label: {
                Label(state.isPreviewPlaying ? "Pausar" : "Previsualizar", systemImage: state.isPreviewPlaying ? "pause.fill" : "play.fill")
            }
            .keyboardShortcut(.defaultAction)

            Spacer()
        }
        .buttonStyle(.bordered)
    }

    private var rangeTimeline: some View {
        GroupBox("Rango") {
            VStack(alignment: .leading, spacing: 12) {
                if !state.isReady {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Cargando video…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else if let message = state.loadErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if state.durationSeconds <= 0 {
                    Text("El video no tiene duración válida.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Inicio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedDuration(state.startSeconds))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text("—")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formattedDuration(state.endSeconds))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                        Text("Fin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    RangeSlider(
                        lowerValue: $state.startSeconds,
                        upperValue: $state.endSeconds,
                        bounds: 0...state.durationSeconds,
                        step: Constants.Gif.trimStepSeconds,
                        minimumDistance: Constants.Gif.minimumClipDurationSeconds,
                        onValueChange: { _, value in
                            state.seek(toSeconds: value)
                        }
                    )

                    HStack {
                        let selectionDuration = max(0, state.endSeconds - state.startSeconds)
                        Text("Duración: \(formattedDuration(selectionDuration)) (mín \(formattedDuration(Constants.Gif.minimumClipDurationSeconds)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Salida") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(saveDirectory.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text("FPS: \(Constants.Gif.defaultFps) • Max \(Constants.Gif.maxPixelSize)px")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 280)
    }

    private var footer: some View {
        HStack {
            Button("Cancelar", role: .cancel) {
                state.stopPlayback()
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if isExporting {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task { await exportGif() }
            } label: {
                Label(isExporting ? "Exportando..." : "Exportar GIF", systemImage: "square.and.arrow.down")
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
            let url = try await GifExportService.shared.exportGif(
                videoURL: videoURL,
                timeRange: state.currentTimeRange(),
                outputDirectory: saveDirectory
            )
            state.stopPlayback()
            onExport(url)
        } catch {
            AppLogger.capture.error("GIF export failed: \(error.localizedDescription)")
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    private func formattedDuration(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0.0s" }
        return String(format: "%.1fs", seconds)
    }
}

// MARK: - Preview

#Preview {
    Text("GifClipEditorView Preview")
        .frame(width: 720, height: 520)
}

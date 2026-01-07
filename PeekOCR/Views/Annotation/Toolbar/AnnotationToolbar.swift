//
//  AnnotationToolbar.swift
//  PeekOCR
//
//  Vertical toolbar for annotation tools and settings.
//

import SwiftUI

/// Vertical toolbar with tools, colors, stroke width, and actions
struct AnnotationToolbar: View {
    @ObservedObject var state: AnnotationState
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Tools section
            ToolsSection(selectedTool: $state.selectedTool)
                .padding(.top, 20)
                .padding(.bottom, 16)

            SectionDivider()

            // Color palette
            ColorPaletteView(selectedColor: $state.selectedColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

            SectionDivider()

            // Stroke width
            StrokeWidthPicker(strokeWidth: $state.strokeWidth)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

            Spacer()

            // Action buttons
            ActionButtonsSection(
                canUndo: state.canUndo,
                canRedo: state.canRedo,
                onUndo: state.undo,
                onRedo: state.redo,
                onClear: state.clearAll
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            SectionDivider()

            // Save/Cancel buttons
            SaveCancelSection(onSave: onSave, onCancel: onCancel)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
        }
        .frame(width: 200)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Tools Section

private struct ToolsSection: View {
    @Binding var selectedTool: AnnotationTool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Herramientas")
                .padding(.horizontal, 16)

            VStack(spacing: 4) {
                ForEach(AnnotationTool.allCases, id: \.self) { tool in
                    ToolButton(
                        tool: tool,
                        isSelected: selectedTool == tool
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedTool = tool
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

// MARK: - Action Buttons Section

private struct ActionButtonsSection: View {
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ActionIconButton(
                    icon: "arrow.uturn.backward",
                    label: "Deshacer",
                    shortcut: "⌘Z",
                    isEnabled: canUndo,
                    action: onUndo
                )

                ActionIconButton(
                    icon: "arrow.uturn.forward",
                    label: "Rehacer",
                    shortcut: "⌘⇧Z",
                    isEnabled: canRedo,
                    action: onRedo
                )
            }

            Button(action: onClear) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                    Text("Limpiar todo")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
        }
    }
}

// MARK: - Save/Cancel Section

private struct SaveCancelSection: View {
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onSave) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text("Guardar")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)

            Button(action: onCancel) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14))
                    Text("Cancelar")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }
}

// MARK: - Preview

#Preview {
    AnnotationToolbar(
        state: AnnotationState(),
        onSave: {},
        onCancel: {}
    )
    .frame(height: 700)
}

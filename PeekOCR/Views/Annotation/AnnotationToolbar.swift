//
//  AnnotationToolbar.swift
//  PeekOCR
//
//  Created by Steven on 06/01/26.
//

import SwiftUI

/// Vertical toolbar for annotation tools and settings - iOS style
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

// MARK: - Section Divider

private struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 20)
            .opacity(0.5)
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Tool Button

private struct ToolButton: View {
    let tool: AnnotationTool
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tool.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Text(tool.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Spacer()

                Text(tool.shortcutKey)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color.secondary.opacity(0.08)
        }
        return Color.clear
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
                // Undo button
                ActionIconButton(
                    icon: "arrow.uturn.backward",
                    label: "Deshacer",
                    shortcut: "⌘Z",
                    isEnabled: canUndo,
                    action: onUndo
                )

                // Redo button
                ActionIconButton(
                    icon: "arrow.uturn.forward",
                    label: "Rehacer",
                    shortcut: "⌘⇧Z",
                    isEnabled: canRedo,
                    action: onRedo
                )
            }

            // Clear button
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

// MARK: - Action Icon Button

private struct ActionIconButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isHovered && isEnabled ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
        .scaleEffect(isHovered && isEnabled ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("\(label) (\(shortcut))")
    }
}

// MARK: - Save/Cancel Section

private struct SaveCancelSection: View {
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Save button - prominent
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

            // Cancel button - secondary
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

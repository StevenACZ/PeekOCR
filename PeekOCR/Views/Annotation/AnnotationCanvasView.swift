//
//  AnnotationCanvasView.swift
//  PeekOCR
//
//  Created by Steven on 06/01/26.
//

import SwiftUI

/// Canvas view for drawing annotations on top of the base image
struct AnnotationCanvasView: View {
    let baseImage: CGImage
    @ObservedObject var state: AnnotationState
    let imageId: UUID

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Canvas with base image and annotations
                Canvas { context, size in
                    // Draw base image
                    drawBaseImage(context: context, size: size)

                    // Draw completed annotations
                    for annotation in state.annotations {
                        drawAnnotation(annotation, context: context, size: size)
                    }

                    // Draw current annotation in progress
                    if let current = state.currentAnnotation {
                        drawAnnotation(current, context: context, size: size)
                    }

                    // Draw selection handles if in select mode
                    if state.selectedTool == .select, let selected = state.selectedAnnotation {
                        drawSelectionHandles(for: selected, context: context)
                    }
                }
                .id(imageId) // Force Canvas recreation when image changes
                .gesture(canvasGesture)

                // Text input overlay
                if state.isTextInputActive {
                    TextInputOverlay(
                        text: $state.currentText,
                        position: state.textInputPosition,
                        color: state.selectedColor,
                        fontSize: max(12, state.strokeWidth * 5),
                        onCommit: state.finishTextInput,
                        onCancel: state.cancelTextInput
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }

    // MARK: - Gesture

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if state.selectedTool == .select {
                    handleSelectDrag(value)
                    return
                }

                if state.selectedTool == .text {
                    // Text tool handles clicks differently
                    return
                }

                if state.currentAnnotation == nil {
                    state.startAnnotation(at: value.startLocation)
                } else {
                    state.updateAnnotation(to: value.location)
                }
            }
            .onEnded { value in
                if state.selectedTool == .select {
                    handleSelectEnd(value)
                    return
                }

                if state.selectedTool == .text {
                    // Start text input at click location
                    state.startTextInput(at: value.location)
                } else {
                    state.finishAnnotation()
                }
            }
    }

    // MARK: - Selection Handling

    @State private var isDraggingSelection = false

    private func handleSelectDrag(_ value: DragGesture.Value) {
        if !isDraggingSelection {
            // First drag event - check if we're on a handle or should select
            if state.selectedAnnotationId != nil {
                if let handle = state.hitTestHandle(at: value.startLocation) {
                    // Start resizing
                    state.startDrag(at: value.startLocation, handle: handle)
                    isDraggingSelection = true
                } else if state.selectedAnnotation != nil {
                    let rect = state.boundingRect(for: state.selectedAnnotation!)
                    if rect.insetBy(dx: -15, dy: -15).contains(value.startLocation) {
                        // Start moving
                        state.startDrag(at: value.startLocation, handle: nil)
                        isDraggingSelection = true
                    } else {
                        // Click outside - try to select another
                        _ = state.selectAnnotation(at: value.startLocation)
                    }
                }
            } else {
                // No selection - try to select
                _ = state.selectAnnotation(at: value.startLocation)
            }
        }

        if isDraggingSelection {
            state.updateDrag(to: value.location)
        }
    }

    private func handleSelectEnd(_ value: DragGesture.Value) {
        if isDraggingSelection {
            state.finishDrag()
            isDraggingSelection = false
        } else {
            // Single click - select annotation
            _ = state.selectAnnotation(at: value.location)
        }
    }

    // MARK: - Drawing Methods

    /// Calculate the rect to draw the image maintaining aspect ratio (aspect fit)
    private func calculateImageRect(imageSize: CGSize, canvasSize: CGSize) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let canvasAspect = canvasSize.width / canvasSize.height

        if imageAspect > canvasAspect {
            // Image is wider than canvas - fit by width
            let drawWidth = canvasSize.width
            let drawHeight = drawWidth / imageAspect
            let y = (canvasSize.height - drawHeight) / 2
            return CGRect(x: 0, y: y, width: drawWidth, height: drawHeight)
        } else {
            // Image is taller than canvas - fit by height
            let drawHeight = canvasSize.height
            let drawWidth = drawHeight * imageAspect
            let x = (canvasSize.width - drawWidth) / 2
            return CGRect(x: x, y: 0, width: drawWidth, height: drawHeight)
        }
    }

    private func drawBaseImage(context: GraphicsContext, size: CGSize) {
        let imageSize = CGSize(width: baseImage.width, height: baseImage.height)
        let imageRect = calculateImageRect(imageSize: imageSize, canvasSize: size)

        // Create fresh NSImage using NSBitmapImageRep to avoid caching issues
        let nsImage = NSImage(size: imageSize)
        nsImage.addRepresentation(NSBitmapImageRep(cgImage: baseImage))

        let image = Image(nsImage: nsImage)
        context.draw(image, in: imageRect)
    }

    private func drawAnnotation(_ annotation: Annotation, context: GraphicsContext, size: CGSize) {
        let strokeStyle = StrokeStyle(lineWidth: annotation.strokeWidth, lineCap: .round, lineJoin: .round)
        let shading = GraphicsContext.Shading.color(annotation.color)

        switch annotation.tool {
        case .select:
            break // Select tool doesn't create annotations
        case .arrow:
            drawArrow(annotation, context: context, strokeStyle: strokeStyle, color: shading)
        case .text:
            drawText(annotation, context: context)
        case .freehand:
            drawFreehand(annotation, context: context, strokeStyle: strokeStyle, color: shading)
        case .rectangle:
            drawRectangle(annotation, context: context, strokeStyle: strokeStyle, color: shading)
        case .oval:
            drawOval(annotation, context: context, strokeStyle: strokeStyle, color: shading)
        }
    }

    // MARK: - Arrow Drawing

    private func drawArrow(_ annotation: Annotation, context: GraphicsContext, strokeStyle: StrokeStyle, color: GraphicsContext.Shading) {
        let start = annotation.startPoint
        let end = annotation.endPoint

        // Draw the line
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: color, style: strokeStyle)

        // Draw the arrowhead
        let arrowPath = createArrowhead(from: start, to: end, size: annotation.strokeWidth * 4)
        context.fill(arrowPath, with: color)
    }

    private func createArrowhead(from start: CGPoint, to end: CGPoint, size: CGFloat) -> Path {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowAngle: CGFloat = .pi / 6 // 30 degrees

        let point1 = CGPoint(
            x: end.x - size * cos(angle - arrowAngle),
            y: end.y - size * sin(angle - arrowAngle)
        )

        let point2 = CGPoint(
            x: end.x - size * cos(angle + arrowAngle),
            y: end.y - size * sin(angle + arrowAngle)
        )

        var path = Path()
        path.move(to: end)
        path.addLine(to: point1)
        path.addLine(to: point2)
        path.closeSubpath()

        return path
    }

    // MARK: - Text Drawing

    private func drawText(_ annotation: Annotation, context: GraphicsContext) {
        guard !annotation.text.isEmpty else { return }

        let text = Text(annotation.text)
            .font(.system(size: annotation.fontSize, weight: .medium))
            .foregroundColor(annotation.color)

        context.draw(text, at: annotation.startPoint, anchor: .topLeading)
    }

    // MARK: - Freehand Drawing

    private func drawFreehand(_ annotation: Annotation, context: GraphicsContext, strokeStyle: StrokeStyle, color: GraphicsContext.Shading) {
        guard annotation.points.count > 1 else { return }

        var path = Path()
        path.move(to: annotation.points[0])

        for point in annotation.points.dropFirst() {
            path.addLine(to: point)
        }

        context.stroke(path, with: color, style: strokeStyle)
    }

    // MARK: - Rectangle Drawing

    private func drawRectangle(_ annotation: Annotation, context: GraphicsContext, strokeStyle: StrokeStyle, color: GraphicsContext.Shading) {
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )

        let path = Path(rect)
        context.stroke(path, with: color, style: strokeStyle)
    }

    // MARK: - Oval Drawing

    private func drawOval(_ annotation: Annotation, context: GraphicsContext, strokeStyle: StrokeStyle, color: GraphicsContext.Shading) {
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )

        let path = Path(ellipseIn: rect)
        context.stroke(path, with: color, style: strokeStyle)
    }

    // MARK: - Selection Handles Drawing

    private func drawSelectionHandles(for annotation: Annotation, context: GraphicsContext) {
        let rect = state.boundingRect(for: annotation)
        guard !rect.isEmpty else { return }

        // Draw selection border
        let borderPath = Path(rect.insetBy(dx: -2, dy: -2))
        context.stroke(borderPath, with: .color(.blue.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // Draw handles
        let handleColor = GraphicsContext.Shading.color(.blue)
        let handleBorderColor = GraphicsContext.Shading.color(.white)

        for handle in ResizeHandle.allCases {
            let handleRect = state.handleRect(for: handle, in: rect)

            // White border
            let borderPath = Path(ellipseIn: handleRect.insetBy(dx: -1, dy: -1))
            context.fill(borderPath, with: handleBorderColor)

            // Blue fill
            let fillPath = Path(ellipseIn: handleRect)
            context.fill(fillPath, with: handleColor)
        }
    }
}

// MARK: - Text Input Overlay

private struct TextInputOverlay: View {
    @Binding var text: String
    let position: CGPoint
    let color: Color
    let fontSize: CGFloat
    let onCommit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            TextField("Escribe aquí...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: max(14, fontSize), weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                .frame(minWidth: 180, maxWidth: 350)
                .fixedSize()
                .position(
                    x: min(max(position.x + 90, 120), geometry.size.width - 120),
                    y: min(max(position.y, 40), geometry.size.height - 40)
                )
                .focused($isFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
                .onSubmit {
                    onCommit()
                }
        }
    }
}

// MARK: - Escape Key Handler

private struct EscapeKeyHandler: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = EscapeKeyView()
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? EscapeKeyView {
            view.onEscape = onEscape
        }
    }
}

private class EscapeKeyView: NSView {
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Preview

#Preview {
    // Create a sample image for preview
    let size = CGSize(width: 400, height: 300)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(NSColor.lightGray.cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    let sampleImage = context.makeImage()!

    return AnnotationCanvasView(baseImage: sampleImage, state: AnnotationState(), imageId: UUID())
        .frame(width: 400, height: 300)
}

//
//  AnnotationCanvasView.swift
//  PeekOCR
//
//  Canvas view for drawing annotations on top of the base image.
//

import SwiftUI

/// Canvas view for drawing and editing annotations
struct AnnotationCanvasView: View {
    let baseImage: CGImage
    @ObservedObject var state: AnnotationState
    let imageId: UUID

    @State private var isDraggingSelection = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Canvas with base image and annotations
                Canvas { context, size in
                    drawBaseImage(context: context, size: size)
                    drawAnnotations(context: context)
                    drawSelectionIfNeeded(context: context)
                }
                .id(imageId)
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

    // MARK: - Drawing

    private func drawBaseImage(context: GraphicsContext, size: CGSize) {
        let imageSize = CGSize(width: baseImage.width, height: baseImage.height)
        let imageRect = AnnotationGeometry.calculateImageRect(imageSize: imageSize, canvasSize: size)

        let nsImage = NSImage(size: imageSize)
        nsImage.addRepresentation(NSBitmapImageRep(cgImage: baseImage))

        let image = Image(nsImage: nsImage)
        context.draw(image, in: imageRect)
    }

    private func drawAnnotations(context: GraphicsContext) {
        for annotation in state.annotations {
            AnnotationRenderer.draw(annotation, context: context)
        }

        if let current = state.currentAnnotation {
            AnnotationRenderer.draw(current, context: context)
        }
    }

    private func drawSelectionIfNeeded(context: GraphicsContext) {
        guard state.selectedTool == .select,
              let selected = state.selectedAnnotation else { return }

        let boundingRect = state.boundingRect(for: selected)
        SelectionHandlesRenderer.draw(
            for: selected,
            context: context,
            boundingRect: boundingRect,
            handleRectProvider: state.handleRect
        )
    }

    // MARK: - Gesture

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        if state.selectedTool == .select {
            handleSelectDrag(value)
            return
        }

        if state.selectedTool == .text {
            return
        }

        if state.currentAnnotation == nil {
            state.startAnnotation(at: value.startLocation)
        } else {
            state.updateAnnotation(to: value.location)
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        if state.selectedTool == .select {
            handleSelectEnd(value)
            return
        }

        if state.selectedTool == .text {
            state.startTextInput(at: value.location)
        } else {
            state.finishAnnotation()
        }
    }

    // MARK: - Selection Handling

    private func handleSelectDrag(_ value: DragGesture.Value) {
        if !isDraggingSelection {
            if state.selectedAnnotationId != nil {
                if let handle = state.hitTestHandle(at: value.startLocation) {
                    state.startDrag(at: value.startLocation, handle: handle)
                    isDraggingSelection = true
                } else if let selected = state.selectedAnnotation {
                    let rect = state.boundingRect(for: selected)
                    if rect.insetBy(dx: -15, dy: -15).contains(value.startLocation) {
                        state.startDrag(at: value.startLocation, handle: nil)
                        isDraggingSelection = true
                    } else {
                        _ = state.selectAnnotation(at: value.startLocation)
                    }
                }
            } else {
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
            _ = state.selectAnnotation(at: value.location)
        }
    }
}

// MARK: - Preview

#Preview {
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

//
//  AnnotationEditorView.swift
//  PeekOCR
//
//  Created by Steven on 06/01/26.
//

import SwiftUI
import AppKit

/// Main annotation editor view combining canvas and toolbar
struct AnnotationEditorView: View {
    let baseImage: CGImage
    let imageId: UUID
    @ObservedObject var state: AnnotationState
    let onSave: (CGImage) -> Void
    let onCancel: () -> Void
    @State private var canvasSize: CGSize = .zero
    @State private var keyMonitor: Any?

    var body: some View {
        HStack(spacing: 0) {
            // Toolbar on the left
            AnnotationToolbar(
                state: state,
                onSave: saveAnnotatedImage,
                onCancel: onCancel
            )

            Divider()

            // Canvas taking the remaining space
            GeometryReader { geometry in
                AnnotationCanvasView(baseImage: baseImage, state: state, imageId: imageId)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color(NSColor.controlBackgroundColor))
                    .onAppear {
                        canvasSize = geometry.size
                    }
                    .onChange(of: geometry.size) { newSize in
                        canvasSize = newSize
                    }
            }
        }
        .id(imageId) // Force complete view recreation including @StateObject
        .onAppear {
            state.reset()
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if handleKeyEvent(event) {
                return nil // Event handled, consume it
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Si estamos escribiendo texto, no interceptar teclas excepto Escape
        if state.isTextInputActive {
            if event.keyCode == 53 { // Escape - cancelar texto
                state.cancelTextInput()
                return true
            }
            // Dejar que el TextField maneje Enter y otras teclas
            return false
        }

        let characters = event.charactersIgnoringModifiers ?? ""
        let modifiers = event.modifierFlags

        // Tool shortcuts (0-5, 0 para selección)
        if let tool = toolForKey(characters) {
            state.selectedTool = tool
            return true
        }

        // Delete para eliminar anotación seleccionada
        if event.keyCode == 51 || event.keyCode == 117 { // Backspace o Delete
            if state.selectedAnnotationId != nil {
                state.deleteSelectedAnnotation()
                return true
            }
        }

        // Cmd+Z for undo, Cmd+Shift+Z for redo
        if modifiers.contains(.command) && characters.lowercased() == "z" {
            if modifiers.contains(.shift) {
                state.redo()
            } else {
                state.undo()
            }
            return true
        }

        // Cmd+S for save
        if modifiers.contains(.command) && characters.lowercased() == "s" {
            saveAnnotatedImage()
            return true
        }

        // Escape to cancel (solo si no hay texto activo)
        if event.keyCode == 53 { // Escape key
            onCancel()
            return true
        }

        // Enter to save (solo si no hay texto activo)
        if event.keyCode == 36 { // Return key
            saveAnnotatedImage()
            return true
        }

        return false
    }

    private func toolForKey(_ key: String) -> AnnotationTool? {
        switch key {
        case "0": return .select
        case "1": return .arrow
        case "2": return .text
        case "3": return .freehand
        case "4": return .rectangle
        case "5": return .oval
        default: return nil
        }
    }

    // MARK: - Save Annotated Image

    private func saveAnnotatedImage() {
        // Render the canvas to a CGImage
        guard let annotatedImage = renderAnnotatedImage() else {
            onCancel()
            return
        }

        onSave(annotatedImage)
    }

    private func renderAnnotatedImage() -> CGImage? {
        let width = baseImage.width
        let height = baseImage.height
        let imageSize = CGSize(width: width, height: height)

        // Calculate the imageRect as displayed in canvas (with aspect fit)
        let imageRect = calculateImageRect(imageSize: imageSize, canvasSize: canvasSize)

        // Calculate scale factor from imageRect to actual image
        let scaleX = CGFloat(width) / imageRect.width
        let scaleY = CGFloat(height) / imageRect.height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        // Draw base image (CGContext has Y pointing up, origin at bottom-left)
        context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw annotations (adjust coordinates relative to imageRect)
        for annotation in state.annotations {
            drawAnnotationToContext(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: CGFloat(height), imageRect: imageRect)
        }

        return context.makeImage()
    }

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

    private func drawAnnotationToContext(_ annotation: Annotation, context: CGContext, scaleX: CGFloat, scaleY: CGFloat, height: CGFloat, imageRect: CGRect) {
        // Convert SwiftUI Color to CGColor
        let cgColor = NSColor(annotation.color).cgColor

        context.setStrokeColor(cgColor)
        context.setFillColor(cgColor)
        context.setLineWidth(annotation.strokeWidth * scaleX)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.tool {
        case .select:
            break // Select tool doesn't create annotations
        case .arrow:
            drawArrowToContext(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        case .text:
            drawTextToContext(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        case .freehand:
            drawFreehandToContext(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        case .rectangle:
            drawRectangleToContext(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        case .oval:
            drawOvalToContext(annotation, context: context, scaleX: scaleX, scaleY: scaleY, height: height, imageRect: imageRect)
        }
    }

    // MARK: - Arrow Drawing

    private func drawArrowToContext(_ annotation: Annotation, context: CGContext, scaleX: CGFloat, scaleY: CGFloat, height: CGFloat, imageRect: CGRect) {
        // Adjust coordinates relative to imageRect origin
        let startX = (annotation.startPoint.x - imageRect.minX) * scaleX
        let startY = height - ((annotation.startPoint.y - imageRect.minY) * scaleY)
        let endX = (annotation.endPoint.x - imageRect.minX) * scaleX
        let endY = height - ((annotation.endPoint.y - imageRect.minY) * scaleY)

        // Draw line
        context.move(to: CGPoint(x: startX, y: startY))
        context.addLine(to: CGPoint(x: endX, y: endY))
        context.strokePath()

        // Draw arrowhead
        let angle = atan2(endY - startY, endX - startX)
        let arrowSize = annotation.strokeWidth * 4 * scaleX
        let arrowAngle: CGFloat = .pi / 6

        let point1 = CGPoint(
            x: endX - arrowSize * cos(angle - arrowAngle),
            y: endY - arrowSize * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: endX - arrowSize * cos(angle + arrowAngle),
            y: endY - arrowSize * sin(angle + arrowAngle)
        )

        context.move(to: CGPoint(x: endX, y: endY))
        context.addLine(to: point1)
        context.addLine(to: point2)
        context.closePath()
        context.fillPath()
    }

    // MARK: - Text Drawing

    private func drawTextToContext(_ annotation: Annotation, context: CGContext, scaleX: CGFloat, scaleY: CGFloat, height: CGFloat, imageRect: CGRect) {
        guard !annotation.text.isEmpty else { return }

        // Adjust coordinates relative to imageRect origin
        let x = (annotation.startPoint.x - imageRect.minX) * scaleX
        let scaledFontSize = annotation.fontSize * scaleX
        // CGContext Y is from bottom, text baseline should be at the annotation point
        // Subtract font size to position text correctly (text draws upward from baseline)
        let y = height - ((annotation.startPoint.y - imageRect.minY) * scaleY) - scaledFontSize

        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, scaledFontSize, nil)
        let cgColor = NSColor(annotation.color).cgColor

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: cgColor
        ]

        let attributedString = NSAttributedString(string: annotation.text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.saveGState()
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    // MARK: - Freehand Drawing

    private func drawFreehandToContext(_ annotation: Annotation, context: CGContext, scaleX: CGFloat, scaleY: CGFloat, height: CGFloat, imageRect: CGRect) {
        guard annotation.points.count > 1 else { return }

        // Adjust coordinates relative to imageRect origin
        let scaledPoints = annotation.points.map { point in
            CGPoint(
                x: (point.x - imageRect.minX) * scaleX,
                y: height - ((point.y - imageRect.minY) * scaleY)
            )
        }

        context.move(to: scaledPoints[0])
        for point in scaledPoints.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    // MARK: - Rectangle Drawing

    private func drawRectangleToContext(_ annotation: Annotation, context: CGContext, scaleX: CGFloat, scaleY: CGFloat, height: CGFloat, imageRect: CGRect) {
        // Adjust coordinates relative to imageRect origin
        let x1 = (annotation.startPoint.x - imageRect.minX) * scaleX
        let y1 = height - ((annotation.startPoint.y - imageRect.minY) * scaleY)
        let x2 = (annotation.endPoint.x - imageRect.minX) * scaleX
        let y2 = height - ((annotation.endPoint.y - imageRect.minY) * scaleY)

        let rect = CGRect(
            x: min(x1, x2),
            y: min(y1, y2),
            width: abs(x2 - x1),
            height: abs(y2 - y1)
        )

        context.stroke(rect)
    }

    // MARK: - Oval Drawing

    private func drawOvalToContext(_ annotation: Annotation, context: CGContext, scaleX: CGFloat, scaleY: CGFloat, height: CGFloat, imageRect: CGRect) {
        // Adjust coordinates relative to imageRect origin
        let x1 = (annotation.startPoint.x - imageRect.minX) * scaleX
        let y1 = height - ((annotation.startPoint.y - imageRect.minY) * scaleY)
        let x2 = (annotation.endPoint.x - imageRect.minX) * scaleX
        let y2 = height - ((annotation.endPoint.y - imageRect.minY) * scaleY)

        let rect = CGRect(
            x: min(x1, x2),
            y: min(y1, y2),
            width: abs(x2 - x1),
            height: abs(y2 - y1)
        )

        context.strokeEllipse(in: rect)
    }
}

// MARK: - Preview

#Preview {
    // Create a sample image for preview
    let size = CGSize(width: 800, height: 600)
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

    return AnnotationEditorView(
        baseImage: sampleImage,
        imageId: UUID(),
        state: AnnotationState(),
        onSave: { _ in },
        onCancel: {}
    )
    .frame(width: 800, height: 600)
}

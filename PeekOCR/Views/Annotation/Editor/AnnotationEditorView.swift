//
//  AnnotationEditorView.swift
//  PeekOCR
//
//  Main annotation editor view combining canvas and toolbar.
//

import SwiftUI
import AppKit

/// Main editor view for annotating screenshots
struct AnnotationEditorView: View {
    let baseImage: CGImage
    let imageId: UUID
    @ObservedObject var state: AnnotationState
    let onSave: (CGImage) -> Void
    let onCancel: () -> Void

    @State private var canvasSize: CGSize = .zero
    @State private var keyboardHandler = KeyboardEventHandler()

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
        .id(imageId)
        .onAppear {
            state.reset()
            keyboardHandler.setup(state: state, onSave: saveAnnotatedImage, onCancel: onCancel)
        }
        .onDisappear {
            keyboardHandler.teardown()
        }
    }

    // MARK: - Save

    private func saveAnnotatedImage() {
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

        // Draw base image
        context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw annotations
        CGContextAnnotationRenderer.render(
            annotations: state.annotations,
            to: context,
            imageSize: imageSize,
            canvasSize: canvasSize
        )

        return context.makeImage()
    }
}

// MARK: - Preview

#Preview {
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

//
//  GifClipEditorView+Preview.swift
//  PeekOCR
//
//  Preview-only scaffolding for the GIF clip editor view.
//

import AVFoundation
import CoreGraphics
import SwiftUI

#Preview {
    GifClipEditorPreviewWrapper()
        .frame(width: 1120, height: 680)
}

private struct GifClipEditorPreviewWrapper: View {
    var body: some View {
        GifClipEditorView(
            videoURL: GifClipEditorPreviewVideoFactory.previewURL,
            saveDirectory: FileManager.default.temporaryDirectory,
            onExport: { _ in },
            onCancel: {}
        )
    }
}

private enum GifClipEditorPreviewVideoFactory {
    static let previewURL: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekocr-gif-editor-preview")
            .appendingPathExtension("mov")

        guard !FileManager.default.fileExists(atPath: url.path) else {
            return url
        }

        do {
            try createPreviewVideo(at: url)
        } catch {
            try? FileManager.default.removeItem(at: url)
        }

        return url
    }()

    private static func createPreviewVideo(at url: URL) throws {
        try? FileManager.default.removeItem(at: url)

        let size = CGSize(width: 1280, height: 720)
        let framesPerSecond = 12
        let frameCount = 48

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.canAdd(input) else {
            throw PreviewVideoError.unableToAddInput
        }

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let lastFrameIndex = max(frameCount - 1, 1)
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            }

            let progress = CGFloat(frame) / CGFloat(lastFrameIndex)
            let pixelBuffer = try makePixelBuffer(
                from: adaptor,
                size: size,
                progress: progress
            )
            let time = CMTime(value: Int64(frame), timescale: Int32(framesPerSecond))

            guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                throw writer.error ?? PreviewVideoError.unableToAppendFrame
            }
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            throw writer.error ?? PreviewVideoError.writerFailed
        }
    }

    private static func makePixelBuffer(
        from adaptor: AVAssetWriterInputPixelBufferAdaptor,
        size: CGSize,
        progress: CGFloat
    ) throws -> CVPixelBuffer {
        guard let pool = adaptor.pixelBufferPool else {
            throw PreviewVideoError.missingPixelBufferPool
        }

        var buffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard status == kCVReturnSuccess, let buffer else {
            throw PreviewVideoError.unableToCreatePixelBuffer
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw PreviewVideoError.missingPixelBufferBaseAddress
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: baseAddress,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )

        guard let context else {
            throw PreviewVideoError.unableToCreateContext
        }

        drawFrame(in: context, size: size, progress: progress)
        return buffer
    }

    private static func drawFrame(in context: CGContext, size: CGSize, progress: CGFloat) {
        let bounds = CGRect(origin: .zero, size: size)
        let panelRect = bounds.insetBy(dx: 56, dy: 56)
        let liveCardWidth = panelRect.width * 0.28
        let liveCardHeight = panelRect.height * 0.24
        let travel = panelRect.width - liveCardWidth - 64
        let liveCardX = panelRect.minX + 32 + travel * progress
        let liveCardY = panelRect.midY - liveCardHeight / 2
        let timelineTrack = CGRect(x: panelRect.minX + 56, y: panelRect.minY + 54, width: panelRect.width - 112, height: 18)

        context.setFillColor(CGColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1))
        context.fill(bounds)

        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                CGColor(red: 0.99, green: 0.56, blue: 0.25, alpha: 1),
                CGColor(red: 0.32, green: 0.56, blue: 0.98, alpha: 1),
                CGColor(red: 0.64, green: 0.27, blue: 0.88, alpha: 1),
            ] as CFArray,
            locations: [0, 0.55, 1]
        ) {
            let panelPath = CGPath(
                roundedRect: panelRect,
                cornerWidth: 28,
                cornerHeight: 28,
                transform: nil
            )
            context.saveGState()
            context.addPath(panelPath)
            context.clip()
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: panelRect.minX, y: panelRect.maxY),
                end: CGPoint(x: panelRect.maxX, y: panelRect.minY),
                options: []
            )
            context.restoreGState()
        }

        fillRoundedRect(
            panelRect,
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.08),
            radius: 28,
            in: context
        )

        fillRoundedRect(
            timelineTrack,
            color: CGColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 0.75),
            radius: 9,
            in: context
        )

        let selectionWidth = timelineTrack.width * 0.42
        let selectionX = timelineTrack.minX + (timelineTrack.width - selectionWidth) * 0.28
        fillRoundedRect(
            CGRect(x: selectionX, y: timelineTrack.minY, width: selectionWidth, height: timelineTrack.height),
            color: CGColor(red: 0.98, green: 0.86, blue: 0.22, alpha: 0.95),
            radius: 9,
            in: context
        )

        let playheadX = timelineTrack.minX + timelineTrack.width * progress
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
        context.fill(CGRect(x: playheadX - 2, y: timelineTrack.minY - 12, width: 4, height: timelineTrack.height + 24))

        fillRoundedRect(
            CGRect(x: liveCardX, y: liveCardY, width: liveCardWidth, height: liveCardHeight),
            color: CGColor(red: 0.96, green: 0.98, blue: 1, alpha: 0.22),
            radius: 24,
            in: context
        )

        fillRoundedRect(
            CGRect(x: liveCardX + 20, y: liveCardY + 20, width: liveCardWidth * 0.52, height: 16),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.55),
            radius: 8,
            in: context
        )

        fillRoundedRect(
            CGRect(x: liveCardX + 20, y: liveCardY + 52, width: liveCardWidth * 0.72, height: 12),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.28),
            radius: 6,
            in: context
        )

        fillRoundedRect(
            CGRect(x: liveCardX + 20, y: liveCardY + 76, width: liveCardWidth * 0.44, height: 12),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.28),
            radius: 6,
            in: context
        )

        fillRoundedRect(
            CGRect(x: panelRect.minX + 36, y: panelRect.maxY - 96, width: panelRect.width - 72, height: 28),
            color: CGColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 0.62),
            radius: 14,
            in: context
        )

        fillRoundedRect(
            CGRect(x: panelRect.minX + 52, y: panelRect.maxY - 88, width: 56, height: 12),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.8),
            radius: 6,
            in: context
        )
    }

    private static func fillRoundedRect(
        _ rect: CGRect,
        color: CGColor,
        radius: CGFloat,
        in context: CGContext
    ) {
        context.setFillColor(color)
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        context.addPath(path)
        context.fillPath()
    }

    private enum PreviewVideoError: Error {
        case missingPixelBufferBaseAddress
        case missingPixelBufferPool
        case unableToAddInput
        case unableToAppendFrame
        case unableToCreateContext
        case unableToCreatePixelBuffer
        case writerFailed
    }
}

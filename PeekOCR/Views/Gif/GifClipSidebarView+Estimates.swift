// GIF clip sidebar export estimate formatting helpers.

import Foundation

extension GifClipSidebarView {
    func friendlyDirectoryName() -> String {
        let path = outputDirectory.path
        if path.contains("/Downloads") || path.contains("/Descargas") { return "Descargas" }
        if path.contains("/Desktop") || path.contains("/Escritorio") { return "Escritorio" }
        return outputDirectory.lastPathComponent
    }

    func estimatedGifFrames() -> Int {
        let duration = max(0, selectionDurationSeconds)
        let fps = max(1, gifOptions.fps)
        return max(1, Int(ceil(duration * Double(fps))))
    }

    func estimatedGifSizeBytes() -> Int64 {
        let frames = Double(estimatedGifFrames())
        let pixelsPerFrame = Double(gifOptions.maxPixelSize * gifOptions.maxPixelSize)
        let bytes = frames * pixelsPerFrame * 0.05
        return Int64(max(0, bytes))
    }

    func estimatedVideoSizeBytes() -> Int64 {
        let duration = max(0, selectionDurationSeconds)
        let size = videoOptions.resolution.maxSize
        let fps = max(1, videoOptions.fps)
        let bitsPerPixelPerFrame: Double = videoOptions.codec == .hevc ? 0.07 : 0.12
        let estimatedBitsPerSecond = Double(size.width * size.height) * Double(fps) * bitsPerPixelPerFrame
        let estimatedBytes = (estimatedBitsPerSecond / 8) * duration
        return Int64(max(0, estimatedBytes))
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatSeconds(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0.0s" }
        return String(format: "%.1fs", max(0, seconds))
    }

    func estimateSummary() -> String {
        switch exportFormat {
        case .gif:
            return "GIF · \(gifOptions.profile.displayName) · \(gifOptions.fps) FPS"
        case .video:
            let resolution = videoOptions.resolution.displayName
            return "Video · \(resolution) · \(videoOptions.fps) FPS · \(videoOptions.codec.displayName)"
        }
    }
}

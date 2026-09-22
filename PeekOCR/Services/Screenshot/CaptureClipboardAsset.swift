import AVFoundation
import AppKit
import ImageIO

struct CaptureClipboardAsset: @unchecked Sendable, Identifiable {
    let id: UUID
    let url: URL
    let thumbnail: CGImage

    var isClip: Bool { Self.clipExtensions.contains(url.pathExtension.lowercased()) }
    var formatLabel: String { url.pathExtension.uppercased() }

    private static let clipExtensions: Set<String> = ["gif", "mp4", "mov"]

    nonisolated static func prepare(_ image: CGImage, savedURL: URL?) -> CaptureClipboardAsset? {
        let id = UUID()
        let url: URL
        if let savedURL, savedURL.pathExtension.lowercased() == "png" {
            url = savedURL
        } else {
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PeekOCR/CaptureClipboard", isDirectory: true)
            do {
                try FileManager.default.createDirectory(
                    at: directory, withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700])
                url = directory.appendingPathComponent("PeekOCR_\(id.uuidString).png")
                guard let data = ImageEncodingService.encode(image, format: .png) else { return nil }
                try data.write(to: url, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            } catch {
                return nil
            }
        }
        guard let thumbnail = makeThumbnail(image) else { return nil }
        return CaptureClipboardAsset(id: id, url: url, thumbnail: thumbnail)
    }

    nonisolated static func prepare(clipURL: URL) async -> CaptureClipboardAsset? {
        guard FileManager.default.isReadableFile(atPath: clipURL.path), let frame = await firstFrame(of: clipURL),
            let thumbnail = makeThumbnail(frame)
        else { return nil }
        return CaptureClipboardAsset(id: UUID(), url: clipURL, thumbnail: thumbnail)
    }

    nonisolated private static func firstFrame(of url: URL) async -> CGImage? {
        if url.pathExtension.lowercased() == "gif" {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1200, height: 1200)
        return try? await generator.image(at: .zero).image
    }

    nonisolated private static func makeThumbnail(_ image: CGImage) -> CGImage? {
        let scale = min(1, 600 / Double(max(image.width, image.height)))
        let width = max(1, Int(Double(image.width) * scale))
        let height = max(1, Int(Double(image.height) * scale))
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    nonisolated static func removeExpiredFiles(excluding urls: Set<URL>, now: Date = Date()) {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PeekOCR/CaptureClipboard", isDirectory: true)
        guard
            let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey])
        else { return }
        for url in files where url.pathExtension == "png" && url.lastPathComponent.hasPrefix("PeekOCR_") && !urls.contains(url) {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                values.isRegularFile == true, let date = values.contentModificationDate,
                now.timeIntervalSince(date) > 7 * 24 * 60 * 60
            else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}

@MainActor
enum CaptureClipboardWriter {
    @discardableResult
    static func write(_ assets: [CaptureClipboardAsset], to pasteboard: NSPasteboard) -> Bool {
        guard !assets.isEmpty, assets.allSatisfy({ FileManager.default.isReadableFile(atPath: $0.url.path) }) else { return false }
        let items = assets.map { asset in
            let item = NSPasteboardItem()
            item.setString(asset.url.absoluteString, forType: .fileURL)
            return item
        }
        if assets.count == 1 {
            if assets[0].url.pathExtension.lowercased() == "png" {
                guard let png = try? Data(contentsOf: assets[0].url) else { return false }
                items[0].setData(png, forType: .png)
            }
        } else {
            let paths = assets.map { "'" + $0.url.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }.joined(separator: " ")
            items[0].setString(paths, forType: .string)
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects(items)
    }
}

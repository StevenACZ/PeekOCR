import AppKit

/// A captured image laid out on screen for editing: the overlay selection is its crop.
struct ImageEditStage {
    let image: CGImage
    let rectInScreen: CGRect

    static func fitted(_ image: CGImage, on screen: NSScreen) -> ImageEditStage {
        let scale = screen.backingScaleFactor
        let natural = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        let area = screen.visibleFrame.insetBy(dx: 40, dy: 96)
        let fit = min(1, area.width / natural.width, area.height / natural.height)
        let size = CGSize(width: (natural.width * fit).rounded(), height: (natural.height * fit).rounded())
        let origin = CGPoint(x: (area.midX - size.width / 2).rounded(), y: (area.midY - size.height / 2).rounded())
        return ImageEditStage(image: image, rectInScreen: CGRect(origin: origin, size: size))
    }

    private var scale: CGFloat { CGFloat(image.width) / rectInScreen.width }

    /// The crop in image pixels (top-left origin) for a selection in screen points.
    func pixelRect(for selectionRectInScreen: CGRect) -> CGRect? {
        let selection = selectionRectInScreen.intersection(rectInScreen)
        guard !selection.isNull else { return nil }
        let pixelRect = CGRect(
            x: (selection.minX - rectInScreen.minX) * scale,
            y: (rectInScreen.maxY - selection.maxY) * scale,
            width: selection.width * scale,
            height: selection.height * scale
        ).integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixelRect.width >= 1 && pixelRect.height >= 1 ? pixelRect : nil
    }

    func render(selectionRectInScreen: CGRect, annotations: [LiveAnnotation]) -> CGImage? {
        guard let pixelRect = pixelRect(for: selectionRectInScreen) else { return nil }
        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)

        let cropped = pixelRect == imageBounds ? image : image.cropping(to: pixelRect)
        guard let cropped else { return nil }
        guard !annotations.isEmpty else { return cropped }

        let snappedSelection = CGRect(
            x: rectInScreen.minX + pixelRect.minX / scale,
            y: rectInScreen.maxY - pixelRect.maxY / scale,
            width: pixelRect.width / scale,
            height: pixelRect.height / scale)
        return LiveAnnotationRenderer.render(
            image: cropped, selectionRectInScreen: snappedSelection, scaleFactor: scale, annotations: annotations)
    }
}

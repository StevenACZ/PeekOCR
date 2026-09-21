import CoreGraphics

struct CapturePreviewLayout {
    static let visibleLimit = 4
    static let width: CGFloat = 344
    static let spacing: CGFloat = 10

    let screenHeight: CGFloat

    func cardSize(for imageSize: CGSize) -> CGSize {
        let maxHeight = min(216, max(96, (screenHeight * 0.78 - 148) / CGFloat(Self.visibleLimit) - Self.spacing))
        let scale = min(312 / max(1, imageSize.width), maxHeight / max(1, imageSize.height))
        return CGSize(width: imageSize.width * scale + 8, height: imageSize.height * scale + 8)
    }

    func viewportHeight(for imageSizes: [CGSize]) -> CGFloat {
        let visible = imageSizes.suffix(Self.visibleLimit)
        return visible.reduce(CGFloat(0)) { $0 + cardSize(for: $1).height }
            + CGFloat(max(0, visible.count - 1)) * Self.spacing + 20
    }

    func panelHeight(for imageSizes: [CGSize]) -> CGFloat {
        viewportHeight(for: imageSizes) + (imageSizes.count > Self.visibleLimit ? 80 : 50)
    }
}

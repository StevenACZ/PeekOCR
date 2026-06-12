import AppKit

/// Lightweight annotation model used by the live pre-capture overlay.
enum LiveAnnotationTool: String, CaseIterable {
    case select
    case arrow
    case text
    case highlight
    case pen

    var displayName: String {
        switch self {
        case .select: return "Seleccionar"
        case .arrow: return "Flecha"
        case .text: return "Texto"
        case .highlight: return "Highlight"
        case .pen: return "Lápiz"
        }
    }

    var iconName: String {
        switch self {
        case .select: return "selection.pin.in.out"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .highlight: return "highlighter"
        case .pen: return "pencil.line"
        }
    }

    var shortcutKey: String {
        switch self {
        case .select: return "S"
        case .arrow: return "A"
        case .text: return "T"
        case .highlight: return "H"
        case .pen: return "P"
        }
    }
}

struct LiveAnnotation: Identifiable, Equatable {
    let id = UUID()
    let tool: LiveAnnotationTool
    var color: NSColor
    var startPoint: CGPoint
    var endPoint: CGPoint
    var text: String = ""
    var fontSize: CGFloat = 18
    var strokeWidth: CGFloat = 3
    /// Freehand path in screen coordinates; only used by the pen tool.
    var points: [CGPoint] = []

    /// Text annotations anchor at their TOP-left corner (`startPoint`);
    /// multi-line text grows downward from there.
    var bounds: CGRect {
        switch tool {
        case .text:
            let textSize = LiveAnnotation.textSize(for: text.isEmpty ? "Texto" : text, fontSize: fontSize)
            return CGRect(
                x: startPoint.x,
                y: startPoint.y - textSize.height,
                width: textSize.width,
                height: textSize.height
            )
        case .pen:
            guard let first = points.first else {
                return CGRect(origin: startPoint, size: .zero)
            }
            var minX = first.x
            var maxX = first.x
            var minY = first.y
            var maxY = first.y
            for point in points.dropFirst() {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .arrow, .highlight, .select:
            return CGRect(
                x: min(startPoint.x, endPoint.x),
                y: min(startPoint.y, endPoint.y),
                width: abs(endPoint.x - startPoint.x),
                height: abs(endPoint.y - startPoint.y)
            )
        }
    }

    // MARK: - Shared text typography

    /// Single source of truth for annotation text rendering: the live overlay,
    /// the final image render, and the floating editor must all match.
    static func textFont(ofSize fontSize: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
        let descriptor = base.fontDescriptor.withDesign(.rounded)
        guard let descriptor, let rounded = NSFont(descriptor: descriptor, size: fontSize) else {
            return base
        }
        return rounded
    }

    static func textAttributes(fontSize: CGFloat, color: NSColor) -> [NSAttributedString.Key: Any] {
        // Thumbnail-style lettering: a negative stroke width fills AND strokes,
        // so the thick black outline keeps text readable on any background.
        [
            .font: textFont(ofSize: fontSize),
            .foregroundColor: color,
            .strokeColor: NSColor.black,
            .strokeWidth: -8.0,
        ]
    }

    /// Multi-line measurement; a trailing newline still reserves a visible line.
    static func textSize(for text: String, fontSize: CGFloat) -> CGSize {
        var measured = text.isEmpty ? " " : text
        if measured.hasSuffix("\n") {
            measured += " "
        }
        let bounding = (measured as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: textFont(ofSize: fontSize)]
        )
        return CGSize(width: max(44, ceil(bounding.width)), height: ceil(bounding.height))
    }
}

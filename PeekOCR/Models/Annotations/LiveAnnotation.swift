import AppKit

/// Lightweight annotation model used by the live pre-capture overlay.
enum LiveAnnotationTool: String, CaseIterable {
    case select
    case arrow
    case text
    case highlight

    var displayName: String {
        switch self {
        case .select: return "Seleccionar"
        case .arrow: return "Flecha"
        case .text: return "Texto"
        case .highlight: return "Highlight"
        }
    }

    var iconName: String {
        switch self {
        case .select: return "selection.pin.in.out"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .highlight: return "highlighter"
        }
    }

    var shortcutKey: String {
        switch self {
        case .select: return "S"
        case .arrow: return "A"
        case .text: return "T"
        case .highlight: return "H"
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
        .systemFont(ofSize: fontSize, weight: .bold)
    }

    static func textAttributes(fontSize: CGFloat, color: NSColor) -> [NSAttributedString.Key: Any] {
        [
            .font: textFont(ofSize: fontSize),
            .foregroundColor: color,
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

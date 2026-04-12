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

struct LiveAnnotation: Identifiable {
    let id = UUID()
    let tool: LiveAnnotationTool
    var color: NSColor
    var startPoint: CGPoint
    var endPoint: CGPoint
    var text: String = ""
    var fontSize: CGFloat = 18
    var strokeWidth: CGFloat = 3

    var bounds: CGRect {
        switch tool {
        case .text:
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold)
            ]
            let textSize = max(text.isEmpty ? "Texto" : text, " ").size(withAttributes: attributes)
            return CGRect(
                x: startPoint.x,
                y: startPoint.y,
                width: max(44, textSize.width),
                height: max(fontSize * 1.3, textSize.height)
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
}

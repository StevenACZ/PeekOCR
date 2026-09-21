import CoreGraphics

enum ArrowGeometry {
    static func path(from start: CGPoint, to end: CGPoint, width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite,
            length.isFinite, length > 0, width.isFinite, width > 0
        else { return path }

        let headLength = min(width * 3, length * 0.65)
        let headRadius = headLength * 0.5
        let shaftRadius = min(width * 0.5, headRadius * 0.5)
        let shoulder = length - headLength
        path.move(to: CGPoint(x: 0, y: -shaftRadius))
        path.addLine(to: CGPoint(x: shoulder, y: -shaftRadius))
        path.addLine(to: CGPoint(x: shoulder, y: -headRadius))
        path.addLine(to: CGPoint(x: length, y: 0))
        path.addLine(to: CGPoint(x: shoulder, y: headRadius))
        path.addLine(to: CGPoint(x: shoulder, y: shaftRadius))
        path.addLine(to: CGPoint(x: 0, y: shaftRadius))
        path.addArc(center: .zero, radius: shaftRadius, startAngle: .pi / 2, endAngle: .pi * 1.5, clockwise: false)
        path.closeSubpath()

        var transform = CGAffineTransform(a: dx / length, b: dy / length, c: -dy / length, d: dx / length, tx: start.x, ty: start.y)
        return path.copy(using: &transform) ?? CGMutablePath()
    }
}

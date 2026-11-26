import CoreGraphics
import Foundation

/// Outlines for the non-circular dot shapes, with rounded corners so they
/// read as soft.
enum ShapePaths {
    /// Line width as a share of the shape's width, for shapes drawn as a
    /// line rather than filled.
    static func strokeRatio(for shape: DotShape) -> CGFloat? {
        switch shape {
        case .ring: 0.16
        case .squiggle: 0.14
        case .spiral: 0.1
        default: nil
        }
    }

    static func path(for shape: DotShape, in rect: CGRect) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        switch shape {
        case .circle, .ring:
            return CGPath(ellipseIn: rect, transform: nil)
        case .square:
            let inset = rect.insetBy(dx: radius * 0.15, dy: radius * 0.15)
            return CGPath(roundedRect: inset, cornerWidth: radius * 0.35, cornerHeight: radius * 0.35, transform: nil)
        case .diamond:
            let points = [
                CGPoint(x: center.x, y: rect.maxY), CGPoint(x: rect.maxX - radius * 0.2, y: center.y),
                CGPoint(x: center.x, y: rect.minY), CGPoint(x: rect.minX + radius * 0.2, y: center.y),
            ]
            return roundedPolygon(points, cornerRadius: radius * 0.15)
        case .triangle:
            // Lowered and enlarged so it fills the canvas like the other shapes.
            let lowered = CGPoint(x: center.x, y: center.y - radius * 0.2)
            return roundedPolygon(star(center: lowered, points: 3, outer: radius * 1.2, inner: nil), cornerRadius: radius * 0.2)
        case .star:
            return roundedPolygon(star(center: center, points: 5, outer: radius, inner: radius * 0.45), cornerRadius: radius * 0.08)
        case .sparkle:
            return roundedPolygon(star(center: center, points: 4, outer: radius, inner: radius * 0.3), cornerRadius: radius * 0.06)
        case .hexagon:
            return roundedPolygon(star(center: center, points: 6, outer: radius, inner: nil), cornerRadius: radius * 0.15)
        case .heart:
            return heart(in: rect)
        case .moon:
            return crescent(center: center, radius: radius)
        case .flower:
            return flower(center: center, radius: radius)
        case .pebble, .capsule, .plus, .squiggle, .petal, .spiral, .cluster:
            return AbstractShapePaths.path(for: shape, center: center, radius: radius)
        }
    }

    private static func heart(in rect: CGRect) -> CGPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let path = CGMutablePath()
        path.move(to: point(0.5, 0.05))
        path.addCurve(to: point(0.03, 0.62), control1: point(0.32, 0.2), control2: point(0.03, 0.4))
        path.addCurve(to: point(0.5, 0.76), control1: point(0.03, 0.88), control2: point(0.38, 1.0))
        path.addCurve(to: point(0.97, 0.62), control1: point(0.62, 1.0), control2: point(0.97, 0.88))
        path.addCurve(to: point(0.5, 0.05), control1: point(0.97, 0.4), control2: point(0.68, 0.2))
        path.closeSubpath()
        return path
    }

    /// The outer circle minus a second circle through the two horn tips.
    private static func crescent(center: CGPoint, radius: CGFloat) -> CGPath {
        let tipAngle = CGFloat.pi / 3
        let shifted = CGPoint(x: center.x + radius * 0.15, y: center.y)
        let tipX = shifted.x + radius * cos(tipAngle)
        let tipY = radius * sin(tipAngle)
        let innerRadius = radius * 0.9
        let innerCenter = CGPoint(x: tipX - sqrt(innerRadius * innerRadius - tipY * tipY), y: center.y)
        let innerAngle = atan2(tipY, tipX - innerCenter.x)

        let path = CGMutablePath()
        path.addArc(center: shifted, radius: radius, startAngle: tipAngle, endAngle: 2 * .pi - tipAngle, clockwise: false)
        path.addArc(center: innerCenter, radius: innerRadius, startAngle: -innerAngle, endAngle: innerAngle, clockwise: true)
        path.closeSubpath()
        return path
    }

    private static func flower(center: CGPoint, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let petal = CGRect(x: -radius * 0.28, y: radius * 0.05, width: radius * 0.56, height: radius * 0.95)
        for index in 0..<5 {
            let turn = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: 2 * .pi * CGFloat(index) / 5)
            path.addEllipse(in: petal, transform: turn)
        }
        path.addEllipse(in: CGRect(x: center.x - radius * 0.3, y: center.y - radius * 0.3, width: radius * 0.6, height: radius * 0.6))
        return path
    }

    /// Corner points of a regular polygon (no inner radius) or star, top point first.
    private static func star(center: CGPoint, points: Int, outer: CGFloat, inner: CGFloat?) -> [CGPoint] {
        let corners = inner == nil ? points : points * 2
        return (0..<corners).map { index in
            let radius = index.isMultiple(of: 2) ? outer : inner ?? outer
            let angle = CGFloat.pi / 2 + 2 * .pi * CGFloat(index) / CGFloat(corners)
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    private static func roundedPolygon(_ points: [CGPoint], cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2))
        for (index, point) in points.enumerated() {
            path.addArc(tangent1End: point, tangent2End: points[(index + 1) % points.count], radius: cornerRadius)
        }
        path.closeSubpath()
        return path
    }
}

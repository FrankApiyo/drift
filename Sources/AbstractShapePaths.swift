import CoreGraphics
import Foundation

/// Outlines for the abstract shapes. Each fits a circle of `radius` around `center`.
enum AbstractShapePaths {
    static func path(for shape: DotShape, center: CGPoint, radius: CGFloat) -> CGPath {
        switch shape {
        case .pebble: return pebble(center: center, radius: radius)
        case .capsule: return capsule(center: center, radius: radius)
        case .plus: return plus(center: center, radius: radius)
        case .squiggle: return squiggle(center: center, radius: radius)
        case .petal: return petal(center: center, radius: radius)
        case .spiral: return spiral(center: center, radius: radius)
        case .cluster: return cluster(center: center, radius: radius)
        default: return CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                 width: radius * 2, height: radius * 2), transform: nil)
        }
    }

    /// A smooth closed curve through uneven points, like a river stone.
    private static func pebble(center: CGPoint, radius: CGFloat) -> CGPath {
        let reaches: [CGFloat] = [0.95, 0.82, 0.9, 0.78, 0.88, 0.8, 0.93]
        let points = reaches.enumerated().map { index, reach in
            let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(reaches.count)
            return CGPoint(x: center.x + radius * reach * cos(angle), y: center.y + radius * reach * 0.85 * sin(angle))
        }
        let path = CGMutablePath()
        path.move(to: midpoint(points[points.count - 1], points[0]))
        for (index, point) in points.enumerated() {
            path.addQuadCurve(to: midpoint(point, points[(index + 1) % points.count]), control: point)
        }
        path.closeSubpath()
        return path
    }

    private static func capsule(center: CGPoint, radius: CGFloat) -> CGPath {
        let rect = CGRect(x: center.x - radius * 0.95, y: center.y - radius * 0.42, width: radius * 1.9, height: radius * 0.84)
        return CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil)
    }

    private static func plus(center: CGPoint, radius: CGFloat) -> CGPath {
        let long = radius * 1.8, thick = radius * 0.6, corner = radius * 0.24
        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(x: center.x - long / 2, y: center.y - thick / 2, width: long, height: thick),
                            cornerWidth: corner, cornerHeight: corner)
        path.addRoundedRect(in: CGRect(x: center.x - thick / 2, y: center.y - long / 2, width: thick, height: long),
                            cornerWidth: corner, cornerHeight: corner)
        return path
    }

    /// An open wave, drawn as a line.
    private static func squiggle(center: CGPoint, radius: CGFloat) -> CGPath {
        let samples = 40
        let points = (0...samples).map { step -> CGPoint in
            let t = CGFloat(step) / CGFloat(samples)
            return CGPoint(x: center.x + radius * 0.85 * (2 * t - 1), y: center.y + radius * 0.32 * sin(3 * .pi * t))
        }
        let path = CGMutablePath()
        path.addLines(between: points)
        return path
    }

    /// A leaf pointed at both ends, tip up.
    private static func petal(center: CGPoint, radius: CGFloat) -> CGPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: center.x + x * radius, y: center.y + y * radius)
        }
        let path = CGMutablePath()
        path.move(to: point(0, -0.95))
        path.addCurve(to: point(0, 0.95), control1: point(0.8, -0.45), control2: point(0.5, 0.65))
        path.addCurve(to: point(0, -0.95), control1: point(-0.5, 0.65), control2: point(-0.8, -0.45))
        path.closeSubpath()
        return path
    }

    /// An open coil, drawn as a line.
    private static func spiral(center: CGPoint, radius: CGFloat) -> CGPath {
        let samples = 90
        let turns: CGFloat = 2.25
        let points = (0...samples).map { step -> CGPoint in
            let t = CGFloat(step) / CGFloat(samples)
            let angle = 2 * .pi * turns * t
            let reach = radius * 0.85 * t
            return CGPoint(x: center.x + reach * cos(angle), y: center.y + reach * sin(angle))
        }
        let path = CGMutablePath()
        path.addLines(between: points)
        return path
    }

    /// Three small dots in a triangle.
    private static func cluster(center: CGPoint, radius: CGFloat) -> CGPath {
        let dot = radius * 0.4
        let path = CGMutablePath()
        for index in 0..<3 {
            let angle = CGFloat.pi / 2 + 2 * .pi * CGFloat(index) / 3
            let spot = CGPoint(x: center.x + radius * 0.52 * cos(angle), y: center.y + radius * 0.52 * sin(angle))
            path.addEllipse(in: CGRect(x: spot.x - dot, y: spot.y - dot, width: dot * 2, height: dot * 2))
        }
        return path
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

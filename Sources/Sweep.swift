import CoreGraphics
import Foundation

/// How a new mood washes across the desktop. One Sweep is shared by every
/// screen so the front carries across displays.
struct Sweep {
    enum Direction: CaseIterable {
        case leftToRight, rightToLeft, bottomToTop, topToBottom, outFromCentre
    }

    /// Seconds for the front to cross the whole desktop.
    static let span: TimeInterval = 15
    static let jitter: TimeInterval = 1.5

    /// Global desktop coordinates, y up, like screen frames.
    let desktop: CGRect
    let direction: Direction

    init(desktop: CGRect, direction: Direction = .leftToRight) {
        self.desktop = desktop
        self.direction = direction
    }

    static func random<R: RandomNumberGenerator>(desktop: CGRect, using rng: inout R) -> Sweep {
        Sweep(desktop: desktop, direction: Direction.allCases.randomElement(using: &rng) ?? .leftToRight)
    }

    func heading(_ newDirection: Direction) -> Sweep {
        Sweep(desktop: desktop, direction: newDirection)
    }

    /// 0 where the front starts, 1 where it ends.
    func progress(at point: CGPoint) -> Double {
        guard !desktop.isNull, desktop.width > 0, desktop.height > 0 else { return 0 }
        let across = Double((point.x - desktop.minX) / desktop.width)
        let up = Double((point.y - desktop.minY) / desktop.height)
        let raw: Double
        switch direction {
        case .leftToRight: raw = across
        case .rightToLeft: raw = 1 - across
        case .bottomToTop: raw = up
        case .topToBottom: raw = 1 - up
        case .outFromCentre:
            let dx = Double(point.x - desktop.midX), dy = Double(point.y - desktop.midY)
            let halfDiagonal = Double(hypot(desktop.width, desktop.height)) / 2
            raw = (dx * dx + dy * dy).squareRoot() / halfDiagonal
        }
        return min(max(raw, 0), 1)
    }

    func delay<R: RandomNumberGenerator>(at point: CGPoint, using rng: inout R) -> TimeInterval {
        max(progress(at: point) * Self.span + .random(in: -Self.jitter...Self.jitter, using: &rng), 0)
    }
}

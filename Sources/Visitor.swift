import CoreGraphics
import Foundation

/// A rare one-off passer-by that isn't a dot.
enum VisitorKind: Equatable {
    case shootingStar, lantern

    static let chance = 1.0 / 15

    var durations: ClosedRange<TimeInterval> {
        self == .shootingStar ? 8...10 : 60...90
    }

    /// Called once per mood change, which comes every 2–5 minutes, so a
    /// visitor appears about once an hour: a shooting star at night, a lantern by day.
    static func roll<R: RandomNumberGenerator>(at date: Date, calendar: Calendar, using rng: inout R) -> VisitorKind? {
        guard Double.random(in: 0..<1, using: &rng) < chance else { return nil }
        return isNight(hour: calendar.component(.hour, from: date)) ? .shootingStar : .lantern
    }

    static func isNight(hour: Int) -> Bool {
        hour >= 20 || hour < 6
    }
}

/// A visitor's route across one screen: a quadratic curve in layer
/// coordinates (y = 0 at the bottom).
struct VisitorPath {
    static let lanternSize: CGFloat = 40

    let start: CGPoint
    let control: CGPoint
    let end: CGPoint
    let duration: TimeInterval

    static func random<R: RandomNumberGenerator>(for kind: VisitorKind, area: CGSize, using rng: inout R) -> VisitorPath {
        let duration = TimeInterval.random(in: kind.durations, using: &rng)
        return kind == .shootingStar
            ? shootingStar(area: area, duration: duration, using: &rng)
            : lantern(area: area, duration: duration, using: &rng)
    }

    /// A shallow downward glide across part of the upper screen.
    private static func shootingStar<R: RandomNumberGenerator>(
        area: CGSize, duration: TimeInterval, using rng: inout R
    ) -> VisitorPath {
        let travel = area.width * .random(in: 0.3...0.45, using: &rng)
        let drop = travel * .random(in: 0.12...0.3, using: &rng)
        let startX = area.width * .random(in: 0.1...0.9, using: &rng)
        let heading: CGFloat = startX > area.width / 2 ? -1 : 1
        let start = CGPoint(x: startX, y: area.height * .random(in: 0.6...0.9, using: &rng))
        let end = CGPoint(x: startX + heading * travel, y: start.y - drop)
        let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y + drop * 0.3, area.height))
        return VisitorPath(start: start, control: control, end: end, duration: duration)
    }

    /// A slow rise from below the screen to above it, leaning a little sideways.
    private static func lantern<R: RandomNumberGenerator>(
        area: CGSize, duration: TimeInterval, using rng: inout R
    ) -> VisitorPath {
        let startX = area.width * .random(in: 0.15...0.85, using: &rng)
        let lean = area.width * .random(in: -0.08...0.08, using: &rng)
        let start = CGPoint(x: startX, y: -lanternSize)
        let end = CGPoint(x: startX + lean, y: area.height + lanternSize)
        let control = CGPoint(x: startX - lean, y: area.height / 2)
        return VisitorPath(start: start, control: control, end: end, duration: duration)
    }
}

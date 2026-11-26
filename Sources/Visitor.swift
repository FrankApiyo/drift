import Foundation

/// A rare one-off passer-by that isn't a dot.
enum VisitorKind: Equatable {
    case shootingStar, lantern

    // CONTRACT STUB: look engine replaces. Called once per mood change; returns
    // a visitor about once an hour (shooting star at night, lantern by day).
    static func roll<R: RandomNumberGenerator>(at date: Date, calendar: Calendar, using rng: inout R) -> VisitorKind? {
        nil
    }
}

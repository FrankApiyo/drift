import CoreGraphics

/// How a new mood washes across the desktop. One Sweep is shared by every
/// screen so the front carries across displays.
struct Sweep {
    let desktop: CGRect

    // CONTRACT STUB: look engine replaces (direction, timing).
    static func random<R: RandomNumberGenerator>(desktop: CGRect, using rng: inout R) -> Sweep {
        Sweep(desktop: desktop)
    }
}

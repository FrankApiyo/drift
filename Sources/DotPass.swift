import CoreGraphics
import Foundation

/// The random values for one trip of a dot across the screen.
/// A dot draws a fresh pass each time it wraps to the opposite edge.
struct DotPass {
    enum Direction { case up, down }

    enum Turn: Equatable {
        case still
        /// A slow full turn.
        case spin(period: TimeInterval, clockwise: Bool)
        /// A gentle sway either side of upright, in radians.
        case rock(amplitude: Double, period: TimeInterval)

        var style: TurnStyle {
            switch self {
            case .still: .still
            case .spin: .spin
            case .rock: .rock
            }
        }
    }

    static let crossingSeconds: ClosedRange<Double> = 15...40
    static let wobbleAmplitudes: ClosedRange<CGFloat> = 3...12
    static let wobblePeriods: ClosedRange<Double> = 6...14
    /// Seconds per full turn.
    static let spinPeriods: ClosedRange<Double> = 20...60
    static let confettiSpinPeriods: ClosedRange<Double> = 8...16
    static let rockAngles: ClosedRange<Double> = (15 * .pi / 180)...(25 * .pi / 180)
    static let rockPeriods: ClosedRange<Double> = 7...12
    /// Seconds for a firefly to brighten and dim once.
    static let glowPeriods: ClosedRange<Double> = 5...9
    /// The dimmest a firefly gets, as a share of its alpha, so nothing blinks.
    static let glowFloor: Float = 0.4
    static let shoalPeriod: TimeInterval = 9
    static let snowSizeFactor: CGFloat = 0.6
    static let snowSwayFactor: CGFloat = 1.8
    static let snowSwayPeriodFactor = 1.4

    let direction: Direction
    let x: CGFloat
    let diameter: CGFloat
    let look: DotLook
    let alpha: Float
    /// Speed at the Normal setting, including the mood's pace; the Speed menu scales it.
    let pointsPerSecond: CGFloat
    let wobbleAmplitude: CGFloat
    let wobblePeriod: TimeInterval
    let turn: Turn
    /// The mood motion the pass was drawn for, which a restyle keeps.
    let motion: MotionStyle
    /// Fireflies brighten and dim over this many seconds; nil for steady dots.
    let glowPeriod: TimeInterval?

    var wobbles: Bool { wobbleAmplitude > 0 && wobblePeriod > 0 }
    /// Shoal dots line their sway up to a shared clock.
    var wobblesInUnison: Bool { motion == .shoal }
    var glows: Bool { (glowPeriod ?? 0) > 0 }

    static func random<R: RandomNumberGenerator>(
        _ setup: PassSetup, mood: Mood, oddOneOutChance: Double, using rng: inout R
    ) -> DotPass {
        let tier = setup.tier
        let isSnow = mood.motion == .snow
        let diameter = CGFloat.random(in: tier.diameters, using: &rng) * (isSnow ? snowSizeFactor : 1)
        let crossing = Double.random(in: crossingSeconds, using: &rng) * tier.crossingFactor / mood.pace
        let x = setup.randomX(using: &rng)
        let look = mood.randomLook(
            oddOneOutChance: oddOneOutChance, desktopFraction: setup.desktopFraction(ofX: x),
            softness: tier.softness, using: &rng)
        let sway = tier.wobbleFactor * (isSnow ? snowSwayFactor : 1)
        let wobblePeriod = mood.motion == .shoal
            ? shoalPeriod
            : Double.random(in: wobblePeriods, using: &rng) * (isSnow ? snowSwayPeriodFactor : 1)
        return DotPass(
            direction: isSnow ? .down : setup.homeDirection,
            x: x,
            diameter: diameter,
            look: look,
            alpha: .random(in: tier.alphas, using: &rng),
            pointsPerSecond: (setup.area.height + diameter) / CGFloat(crossing),
            wobbleAmplitude: .random(in: wobbleAmplitudes, using: &rng) * sway,
            wobblePeriod: wobblePeriod,
            turn: randomTurn(for: look.shape, motion: mood.motion, using: &rng),
            motion: mood.motion,
            glowPeriod: mood.motion == .fireflies ? .random(in: glowPeriods, using: &rng) : nil
        )
    }

    /// The shape's own turn style, except that confetti tumbles every shape
    /// that isn't round.
    static func effectiveTurnStyle(for shape: DotShape, motion: MotionStyle) -> TurnStyle {
        switch (shape.turnStyle, motion) {
        case (.still, _): .still
        case (_, .confetti): .spin
        case let (style, _): style
        }
    }

    private static func randomTurn<R: RandomNumberGenerator>(
        for shape: DotShape, motion: MotionStyle, using rng: inout R
    ) -> Turn {
        switch effectiveTurnStyle(for: shape, motion: motion) {
        case .still:
            return .still
        case .spin:
            let periods = motion == .confetti ? confettiSpinPeriods : spinPeriods
            return .spin(period: .random(in: periods, using: &rng), clockwise: .random(using: &rng))
        case .rock:
            return .rock(amplitude: .random(in: rockAngles, using: &rng), period: .random(in: rockPeriods, using: &rng))
        }
    }

    /// Keeps the turn, which only changes at a wrap. A new shape that turns
    /// another way waits for the wrap too; until then the dot keeps its
    /// shape and takes only the new look's colours.
    func restyled(_ newLook: DotLook) -> DotPass {
        let suits = turn.style == Self.effectiveTurnStyle(for: newLook.shape, motion: motion)
        let shown = suits
            ? newLook
            : DotLook(shape: look.shape, color: newLook.color, accent: newLook.accent, softness: newLook.softness)
        return DotPass(
            direction: direction, x: x, diameter: diameter, look: shown, alpha: alpha,
            pointsPerSecond: pointsPerSecond, wobbleAmplitude: wobbleAmplitude, wobblePeriod: wobblePeriod,
            turn: turn, motion: motion, glowPeriod: glowPeriod)
    }

    /// Off-screen y where the dot enters. Layer coordinates put y = 0 at the bottom.
    func startY(areaHeight: CGFloat) -> CGFloat {
        direction == .up ? -diameter / 2 : areaHeight + diameter / 2
    }

    /// Off-screen y where the dot leaves.
    func endY(areaHeight: CGFloat) -> CGFloat {
        direction == .up ? areaHeight + diameter / 2 : -diameter / 2
    }

    func duration(fromY y: CGFloat, areaHeight: CGFloat, speedFactor: Double) -> TimeInterval {
        let remaining = abs(endY(areaHeight: areaHeight) - y)
        return Double(remaining / pointsPerSecond) / speedFactor
    }
}

/// How a shape turns: round shapes don't, symmetric ones spin, and ones with
/// an up rock gently so they never end upside down.
enum TurnStyle {
    case still, spin, rock
}

extension DotShape {
    var turnStyle: TurnStyle {
        switch self {
        case .circle, .ring:
            .still
        case .star, .sparkle, .flower, .hexagon, .square, .diamond, .plus, .spiral, .cluster:
            .spin
        case .heart, .moon, .triangle, .petal, .capsule, .squiggle, .pebble:
            .rock
        }
    }
}

/// A linear move that Core Animation is running, kept so the dot's position
/// can be worked out when it is paused.
struct Trip {
    let fromY: CGFloat
    let toY: CGFloat
    let startTime: TimeInterval
    let duration: TimeInterval

    func y(at time: TimeInterval) -> CGFloat {
        let progress = duration > 0 ? min(max((time - startTime) / duration, 0), 1) : 1
        return fromY + (toY - fromY) * CGFloat(progress)
    }
}

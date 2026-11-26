import CoreGraphics
import Foundation

/// The random values for one trip of a dot across the screen.
/// A dot draws a fresh pass each time it wraps to the opposite edge.
struct DotPass {
    enum Direction { case up, down }

    static let crossingSeconds: ClosedRange<Double> = 15...40
    static let diameters: ClosedRange<CGFloat> = 6...22
    static let alphas: ClosedRange<Float> = 0.35...0.8
    static let wobbleAmplitudes: ClosedRange<CGFloat> = 3...12
    static let wobblePeriods: ClosedRange<Double> = 6...14
    /// Seconds per full turn.
    static let spinPeriods: ClosedRange<Double> = 20...60

    let direction: Direction
    let x: CGFloat
    let diameter: CGFloat
    let look: DotLook
    let alpha: Float
    /// Speed at the Normal setting, including the mood's pace; the Speed menu scales it.
    let pointsPerSecond: CGFloat
    let wobbleAmplitude: CGFloat
    let wobblePeriod: TimeInterval
    let spinPeriod: TimeInterval
    let spinsClockwise: Bool

    static func random<R: RandomNumberGenerator>(
        direction: Direction, area: CGSize, mood: Mood, oddOneOutChance: Double, using rng: inout R
    ) -> DotPass {
        let diameter = CGFloat.random(in: diameters, using: &rng)
        let crossing = Double.random(in: crossingSeconds, using: &rng) / mood.pace
        return DotPass(
            direction: direction,
            x: .random(in: 0...max(area.width, 0), using: &rng),
            diameter: diameter,
            look: mood.randomLook(oddOneOutChance: oddOneOutChance, using: &rng),
            alpha: .random(in: alphas, using: &rng),
            pointsPerSecond: (area.height + diameter) / CGFloat(crossing),
            wobbleAmplitude: .random(in: wobbleAmplitudes, using: &rng),
            wobblePeriod: .random(in: wobblePeriods, using: &rng),
            spinPeriod: .random(in: spinPeriods, using: &rng),
            spinsClockwise: .random(using: &rng)
        )
    }

    func restyled(_ newLook: DotLook) -> DotPass {
        DotPass(
            direction: direction, x: x, diameter: diameter, look: newLook, alpha: alpha,
            pointsPerSecond: pointsPerSecond, wobbleAmplitude: wobbleAmplitude, wobblePeriod: wobblePeriod,
            spinPeriod: spinPeriod, spinsClockwise: spinsClockwise)
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

import QuartzCore

/// One soft dot. It keeps its direction for life and draws a new random pass
/// each time it leaves the screen.
///
/// Core Animation runs the motion in the render server. This object only wakes
/// up when a pass ends (`animationDidStop`), the mood changes, or it is paused
/// or resumed.
final class Dot: NSObject, CAAnimationDelegate {
    let layer = CALayer()

    private let direction: DotPass.Direction
    private let area: CGSize
    private var speedFactor: Double
    private var mood: Mood
    private var pass: DotPass
    private var trip: Trip?
    private var tripID = 0
    private var isRunning = false

    private static let tripKey = "tripID"
    private static let rotationKey = "transform.rotation.z"
    private static let motionKeys = ["drift", "wobble", "spin"]
    private static let wobbleSamples = 24
    /// Slow motion looks the same at 30 fps, so don't ask ProMotion screens for 120.
    private static let frameRates = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)

    init(area: CGSize, scale: CGFloat, speedFactor: Double, mood: Mood) {
        self.area = area
        self.speedFactor = speedFactor
        self.mood = mood
        direction = Bool.random() ? .up : .down
        pass = Self.randomPass(direction: direction, area: area, mood: mood)
        super.init()
        layer.contentsScale = scale
        layer.contentsGravity = .resize
        // The first pass starts mid-screen so dots don't all arrive from the edges at launch.
        show(pass, atY: .random(in: 0...max(area.height, 0)))
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        beginTrip(fromY: layer.position.y)
    }

    /// Freezes the dot where it is and removes its animations, so nothing is
    /// left for the render server to animate.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        let presentation = layer.presentation()
        let x = presentation?.position.x ?? layer.position.x
        let y = trip?.y(at: CACurrentMediaTime()) ?? layer.position.y
        let angle = presentation?.value(forKeyPath: Self.rotationKey) ?? layer.value(forKeyPath: Self.rotationKey)
        trip = nil
        withoutImplicitAnimation {
            layer.position = CGPoint(x: x, y: y)
            layer.setValue(angle, forKeyPath: Self.rotationKey)
            // A mood fade lasts under half a minute, so let it finish rather
            // than snap the frozen dot to its new look.
            Self.motionKeys.forEach(layer.removeAnimation(forKey:))
        }
    }

    func setSpeedFactor(_ factor: Double) {
        speedFactor = factor
        guard isRunning else { return }
        stop()
        start()
    }

    /// Cross-fades to a look from the new mood after `delay`. The mood's pace
    /// takes over at the next wrap, so speed never changes mid-trip.
    func adopt(_ newMood: Mood, after delay: TimeInterval, fadingOver duration: TimeInterval) {
        mood = newMood
        var rng = SystemRandomNumberGenerator()
        pass = pass.restyled(newMood.randomLook(oddOneOutChance: Mood.oddOneOutChance, using: &rng))
        let image = DotImages.image(for: pass.look)

        let fade = CABasicAnimation(keyPath: "contents")
        fade.fromValue = layer.contents
        fade.toValue = image
        fade.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
        fade.duration = duration
        fade.fillMode = .backwards
        fade.preferredFrameRateRange = Self.frameRates

        withoutImplicitAnimation {
            layer.contents = image
            layer.add(fade, forKey: "restyle")
        }
    }

    func animationDidStop(_ anim: CAAnimation, finished: Bool) {
        // Removed or replaced animations report finished == false; a stale
        // finish can still arrive after a pause and resume, hence the ID check.
        guard finished, isRunning, anim.value(forKey: Self.tripKey) as? Int == tripID else { return }
        pass = Self.randomPass(direction: direction, area: area, mood: mood)
        show(pass, atY: pass.startY(areaHeight: area.height))
        beginTrip(fromY: layer.position.y)
    }

    private func beginTrip(fromY y: CGFloat) {
        let toY = pass.endY(areaHeight: area.height)
        let duration = max(pass.duration(fromY: y, areaHeight: area.height, speedFactor: speedFactor), 0.01)
        tripID += 1

        let drift = CABasicAnimation(keyPath: "position.y")
        drift.fromValue = y
        drift.toValue = toY
        drift.duration = duration
        drift.delegate = self
        drift.preferredFrameRateRange = Self.frameRates
        drift.setValue(tripID, forKey: Self.tripKey)

        withoutImplicitAnimation {
            layer.position.y = toY
            layer.add(drift, forKey: "drift")
            layer.add(makeWobble(), forKey: "wobble")
            layer.add(makeSpin(), forKey: "spin")
        }
        trip = Trip(fromY: y, toY: toY, startTime: CACurrentMediaTime(), duration: duration)
    }

    /// A sideways sine sway added on top of the dot's x. It starts at zero
    /// offset, so resuming from a pause doesn't make the dot jump.
    private func makeWobble() -> CAKeyframeAnimation {
        let amplitude = pass.wobbleAmplitude
        let steps = CGFloat(Self.wobbleSamples)
        let wobble = CAKeyframeAnimation(keyPath: "position.x")
        wobble.values = (0...Self.wobbleSamples).map { amplitude * sin(2 * .pi * CGFloat($0) / steps) }
        wobble.isAdditive = true
        wobble.duration = pass.wobblePeriod
        wobble.repeatCount = .infinity
        wobble.preferredFrameRateRange = Self.frameRates
        return wobble
    }

    /// A slow full turn from wherever the dot is facing, so resuming doesn't snap it upright.
    private func makeSpin() -> CABasicAnimation {
        let start = (layer.value(forKeyPath: Self.rotationKey) as? NSNumber)?.doubleValue ?? 0
        let turn = pass.spinsClockwise ? -2 * Double.pi : 2 * Double.pi
        let spin = CABasicAnimation(keyPath: Self.rotationKey)
        spin.fromValue = start
        spin.toValue = start + turn
        spin.duration = pass.spinPeriod
        spin.repeatCount = .infinity
        spin.preferredFrameRateRange = Self.frameRates
        return spin
    }

    private func show(_ pass: DotPass, atY y: CGFloat) {
        withoutImplicitAnimation {
            layer.removeAnimation(forKey: "restyle")
            layer.bounds = CGRect(x: 0, y: 0, width: pass.diameter, height: pass.diameter)
            layer.position = CGPoint(x: pass.x, y: y)
            layer.opacity = pass.alpha
            layer.contents = DotImages.image(for: pass.look)
        }
    }

    private func withoutImplicitAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }

    private static func randomPass(direction: DotPass.Direction, area: CGSize, mood: Mood) -> DotPass {
        var rng = SystemRandomNumberGenerator()
        return DotPass.random(
            direction: direction, area: area, mood: mood,
            oddOneOutChance: Mood.oddOneOutChance, using: &rng)
    }
}

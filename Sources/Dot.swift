import QuartzCore

/// One soft dot. It keeps its depth tier and home direction for life and
/// draws a new random pass each time it leaves the screen.
///
/// Core Animation runs the motion in the render server. This object only wakes
/// up when a pass ends (`animationDidStop`), the mood or a setting changes, or
/// it is paused or resumed.
final class Dot: NSObject, CAAnimationDelegate {
    let layer = CALayer()

    private var setup: PassSetup
    private var speedFactor: Double
    private var reduceMotion: Bool
    private var mood: Mood
    private var pass: DotPass
    private var trip: Trip?
    private var tripID = 0
    private var isRunning = false

    private static let tripKey = "tripID"

    init(setup: PassSetup, scale: CGFloat, speedFactor: Double, mood: Mood, reduceMotion: Bool) {
        self.setup = setup
        self.speedFactor = speedFactor
        self.reduceMotion = reduceMotion
        self.mood = mood
        pass = Self.randomPass(setup, mood: mood)
        super.init()
        layer.contentsScale = scale
        layer.contentsGravity = .resize
        layer.zPosition = setup.tier.zPosition
        // The first pass starts mid-screen so dots don't all arrive from the edges at launch.
        show(pass, atY: .random(in: 0...max(setup.area.height, 0)))
    }

    /// Where the dot is drawn now, in its screen's layer coordinates.
    var currentPosition: CGPoint {
        CGPoint(x: layer.presentation()?.position.x ?? layer.position.x,
                y: trip?.y(at: CACurrentMediaTime()) ?? layer.position.y)
    }

    private var currentAngle: Double {
        let angle = layer.presentation()?.value(forKeyPath: DotMotion.rotationKey)
            ?? layer.value(forKeyPath: DotMotion.rotationKey)
        return (angle as? NSNumber)?.doubleValue ?? 0
    }

    /// Reduce Motion drifts no faster than the Slower setting.
    private var effectiveSpeed: Double {
        reduceMotion ? min(speedFactor, DriftSpeed.slower.factor) : speedFactor
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        beginTrip(fromY: layer.position.y)
    }

    /// Freezes the dot where it is and removes its motion, so nothing is
    /// left for the render server to animate.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        let position = currentPosition
        let angle = currentAngle
        let opacity = layer.presentation()?.opacity ?? layer.opacity
        trip = nil
        CATransaction.withoutActions {
            layer.position = position
            layer.setValue(angle, forKeyPath: DotMotion.rotationKey)
            layer.opacity = opacity
            DotMotion.keys.forEach(layer.removeAnimation(forKey:))
        }
    }

    func setSpeedFactor(_ factor: Double) {
        speedFactor = factor
        restartIfRunning()
    }

    func setReduceMotion(_ reduce: Bool) {
        reduceMotion = reduce
        restartIfRunning()
    }

    /// Takes effect at the next wrap.
    func setColumn(_ column: Int, of columns: Int) {
        setup = setup.with(column: column, of: columns)
    }

    /// Cross-fades to a look from the new mood after `delay`, swelling a
    /// little as it changes, from whatever is on screen now. The mood's pace
    /// and motion take over at the next wrap, so speed never changes mid-trip;
    /// only a turn that doesn't suit the new shape changes.
    func adopt(_ newMood: Mood, desktop: CGRect, after delay: TimeInterval, fadingOver duration: TimeInterval) {
        mood = newMood
        setup = setup.with(desktop: desktop)
        var rng = SystemRandomNumberGenerator()
        let look = newMood.randomLook(
            oddOneOutChance: Mood.oddOneOutChance, desktopFraction: setup.desktopFraction(ofX: pass.x),
            softness: setup.tier.softness, using: &rng)
        let restyled = pass.restyled(look, using: &rng)
        let turnChanges = restyled.turn != pass.turn
        pass = restyled
        let image = DotImages.image(for: look)
        let begin = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
        let shown = layer.presentation()
        let fade = DotMotion.restyle(from: shown?.contents ?? layer.contents, to: image, beginTime: begin, duration: duration)
        let swell = DotMotion.swell(from: shown?.bounds.size ?? layer.bounds.size, to: layer.bounds.size,
                                    beginTime: begin, duration: duration)

        CATransaction.withoutActions {
            layer.contents = image
            layer.add(fade, forKey: DotMotion.restyleKey)
            layer.add(swell, forKey: DotMotion.swellKey)
        }
        if turnChanges, isRunning, !reduceMotion { startTurn(at: begin) }
    }

    func animationDidStop(_ anim: CAAnimation, finished: Bool) {
        // Removed or replaced animations report finished == false; a stale
        // finish can still arrive after a pause and resume, hence the ID check.
        guard finished, isRunning, anim.value(forKey: Self.tripKey) as? Int == tripID else { return }
        pass = Self.randomPass(setup, mood: mood)
        show(pass, atY: pass.startY(areaHeight: setup.area.height))
        beginTrip(fromY: layer.position.y)
    }

    private func restartIfRunning() {
        guard isRunning else { return }
        stop()
        start()
    }

    private func beginTrip(fromY y: CGFloat) {
        let toY = pass.endY(areaHeight: setup.area.height)
        let duration = max(pass.duration(fromY: y, areaHeight: setup.area.height, speedFactor: effectiveSpeed), 0.01)
        tripID += 1

        let drift = DotMotion.drift(fromY: y, toY: toY, duration: duration)
        drift.delegate = self
        drift.setValue(tripID, forKey: Self.tripKey)
        let needed = DotMotion.neededKeys(for: pass, reduceMotion: reduceMotion)
        let extras = needed.compactMap { key in extraMotion(forKey: key).map { (key, $0) } }

        CATransaction.withoutActions {
            layer.position.y = toY
            DotMotion.keys.subtracting(needed).forEach(layer.removeAnimation(forKey:))
            layer.add(drift, forKey: DotMotion.driftKey)
            extras.forEach { key, animation in layer.add(animation, forKey: key) }
        }
        trip = Trip(fromY: y, toY: toY, startTime: CACurrentMediaTime(), duration: duration)
    }

    /// Switches to the pass's turn as the new look arrives, from wherever the
    /// dot faces now: a spin carries on from that angle, and anything else
    /// first settles upright.
    private func startTurn(at begin: CFTimeInterval) {
        let angle = currentAngle
        let spins = pass.turn.style == .spin
        CATransaction.withoutActions {
            layer.setValue(spins ? angle : 0, forKeyPath: DotMotion.rotationKey)
            [DotMotion.turnKey, DotMotion.settleKey].forEach(layer.removeAnimation(forKey:))
            if !spins { layer.add(DotMotion.settle(from: angle, beginTime: begin), forKey: DotMotion.settleKey) }
            if let turn = DotMotion.turn(for: pass, on: layer) {
                turn.beginTime = begin
                layer.add(turn, forKey: DotMotion.turnKey)
            }
        }
    }

    private func extraMotion(forKey key: String) -> CAAnimation? {
        switch key {
        case DotMotion.wobbleKey: DotMotion.wobble(for: pass, on: layer)
        case DotMotion.turnKey: DotMotion.turn(for: pass, on: layer)
        case DotMotion.glowKey: DotMotion.glow(for: pass, from: layer.opacity, on: layer)
        default: nil
        }
    }

    private func show(_ pass: DotPass, atY y: CGFloat) {
        CATransaction.withoutActions {
            layer.removeAnimation(forKey: DotMotion.restyleKey)
            layer.removeAnimation(forKey: DotMotion.swellKey)
            layer.bounds = CGRect(x: 0, y: 0, width: pass.diameter, height: pass.diameter)
            layer.position = CGPoint(x: pass.x, y: y)
            layer.opacity = pass.alpha
            layer.contents = DotImages.image(for: pass.look)
            // Off screen, so shapes with an up can be set upright unseen.
            if case .spin = pass.turn {} else { layer.setValue(0, forKeyPath: DotMotion.rotationKey) }
        }
    }

    private static func randomPass(_ setup: PassSetup, mood: Mood) -> DotPass {
        var rng = SystemRandomNumberGenerator()
        return DotPass.random(setup, mood: mood, oddOneOutChance: Mood.oddOneOutChance, using: &rng)
    }
}

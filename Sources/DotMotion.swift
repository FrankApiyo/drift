import QuartzCore

/// Builds the animations that move and restyle a dot. The render server runs
/// them; the app only builds them at wraps, setting changes and mood changes.
enum DotMotion {
    static let rotationKey = "transform.rotation.z"
    static let driftKey = "drift"
    static let wobbleKey = "wobble"
    static let turnKey = "turn"
    static let glowKey = "glow"
    static let settleKey = "settle"
    static let restyleKey = "restyle"
    static let swellKey = "swell"
    /// Slow motion looks the same at 30 fps, so don't ask ProMotion screens for 120.
    static let frameRates = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
    static let swellScale: CGFloat = 1.15
    static let settleSeconds: TimeInterval = 3

    private typealias Builder = (DotPass, CALayer) -> CAAnimation?

    /// Every motion a trip can run besides its drift and settle. Reduce
    /// Motion keeps the glow, which doesn't move the dot.
    private static let builders: [(key: String, keptByReduceMotion: Bool, build: Builder)] = [
        (glowKey, true, glow),
        (wobbleKey, false, wobble),
        (turnKey, false, { pass, _ in turn(for: pass) }),
    ]

    /// What `Dot.stop()` and each new trip remove. A mood's restyle and swell
    /// are left to finish rather than snap.
    static let keys = Set([driftKey, settleKey] + builders.map(\.key))

    /// The motion a trip runs on top of its drift.
    static func motions(for pass: DotPass, on layer: CALayer, reduceMotion: Bool) -> [(key: String, animation: CAAnimation)] {
        builders
            .filter { !reduceMotion || $0.keptByReduceMotion }
            .compactMap { motion in motion.build(pass, layer).map { (motion.key, $0) } }
    }

    static func now(on layer: CALayer) -> CFTimeInterval {
        layer.convertTime(CACurrentMediaTime(), from: nil)
    }

    static func rotation(of layer: CALayer) -> Double {
        (layer.value(forKeyPath: rotationKey) as? NSNumber)?.doubleValue ?? 0
    }

    static func drift(fromY: CGFloat, toY: CGFloat, duration: TimeInterval) -> CABasicAnimation {
        let drift = CABasicAnimation(keyPath: "position.y")
        drift.fromValue = fromY
        drift.toValue = toY
        drift.duration = duration
        drift.preferredFrameRateRange = frameRates
        return drift
    }

    /// A sideways sway added on top of the dot's x. It starts at zero offset,
    /// so resuming doesn't make the dot jump; a shoal waits for the shared
    /// clock's next beat so every dot sways in step.
    static func wobble(for pass: DotPass, on layer: CALayer) -> CAAnimation? {
        guard pass.wobbles else { return nil }
        let wobble = sway(keyPath: "position.x", amplitude: Double(pass.wobbleAmplitude), period: pass.wobblePeriod)
        if pass.wobblesInUnison {
            let nextBeat = (CACurrentMediaTime() / pass.wobblePeriod).rounded(.up) * pass.wobblePeriod
            wobble.beginTime = layer.convertTime(nextBeat, from: nil)
        }
        return wobble
    }

    /// Spins or rocks on top of the layer's own rotation, so a spin carries
    /// on from wherever the dot faces and a rock sways around a settle.
    static func turn(for pass: DotPass) -> CAAnimation? {
        switch pass.turn {
        case .still:
            return nil
        case let .spin(period, clockwise):
            let spin = CABasicAnimation(keyPath: rotationKey)
            spin.fromValue = 0
            spin.toValue = (clockwise ? -2 : 2) * Double.pi
            spin.isAdditive = true
            spin.duration = period
            spin.repeatCount = .infinity
            spin.preferredFrameRateRange = frameRates
            return spin
        case let .rock(amplitude, period):
            return sway(keyPath: rotationKey, amplitude: amplitude, period: period)
        }
    }

    /// A firefly brightens and dims between its alpha and the glow floor,
    /// starting from the layer's opacity after a random wait, so fireflies
    /// glow out of step.
    static func glow(for pass: DotPass, on layer: CALayer) -> CAAnimation? {
        guard pass.glows, let period = pass.glowPeriod else { return nil }
        let opacity = layer.opacity
        let dimmest = pass.alpha * DotPass.glowFloor
        let glow = CABasicAnimation(keyPath: "opacity")
        glow.fromValue = opacity
        glow.toValue = opacity - dimmest > pass.alpha - opacity ? dimmest : pass.alpha
        glow.duration = period / 2
        glow.autoreverses = true
        glow.repeatCount = .infinity
        glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glow.beginTime = now(on: layer) + .random(in: 0..<period)
        glow.preferredFrameRateRange = frameRates
        return glow
    }

    static func restyle(from oldImage: Any?, to newImage: CGImage?, beginTime: CFTimeInterval,
                        duration: TimeInterval) -> CABasicAnimation {
        let fade = CABasicAnimation(keyPath: "contents")
        fade.fromValue = oldImage
        fade.toValue = newImage
        fade.beginTime = beginTime
        fade.duration = duration
        fade.fillMode = .backwards
        fade.preferredFrameRateRange = frameRates
        return fade
    }

    /// Grows a little and settles to `size` while the look changes, starting
    /// from `current` so a swell already under way doesn't snap. It animates
    /// bounds rather than transform so it never fights the turn.
    static func swell(from current: CGSize, to size: CGSize, beginTime: CFTimeInterval,
                      duration: TimeInterval) -> CAKeyframeAnimation {
        let grown = CGSize(width: size.width * swellScale, height: size.height * swellScale)
        let swell = CAKeyframeAnimation(keyPath: "bounds.size")
        swell.values = [current, grown, size].map { NSValue(size: $0) }
        swell.keyTimes = [0, 0.4, 1]
        swell.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 2)
        swell.beginTime = beginTime
        swell.duration = duration
        swell.fillMode = .backwards
        swell.preferredFrameRateRange = frameRates
        return swell
    }

    /// Sets a shape that doesn't spin upright and returns a settle that eases
    /// there now from its tilt, so it never snaps; nil if nothing needs it.
    static func standUpright(_ layer: CALayer, for pass: DotPass) -> CAAnimation? {
        guard pass.turn.style != .spin else { return nil }
        let angle = remainder(rotation(of: layer), 2 * .pi)
        CATransaction.withoutActions { layer.setValue(0, forKeyPath: rotationKey) }
        return angle == 0 ? nil : settle(from: angle, on: layer)
    }

    /// Eases from `angle` to the nearest upright, starting now. It adds onto
    /// the layer's own rotation, which should be upright, so it combines with
    /// a turn whichever was added first.
    static func settle(from angle: Double, on layer: CALayer) -> CABasicAnimation {
        let settle = CABasicAnimation(keyPath: rotationKey)
        settle.fromValue = remainder(angle, 2 * .pi)
        settle.toValue = 0
        settle.isAdditive = true
        settle.beginTime = now(on: layer)
        settle.duration = settleSeconds
        settle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        settle.preferredFrameRateRange = frameRates
        return settle
    }

    /// Zero, out to +amplitude, across to −amplitude and back to zero. The
    /// eased segments meet with matching speed, so it reads as a smooth sine.
    private static func sway(keyPath: String, amplitude: Double, period: TimeInterval) -> CAKeyframeAnimation {
        let sway = CAKeyframeAnimation(keyPath: keyPath)
        sway.values = [0, amplitude, -amplitude, 0]
        sway.keyTimes = [0, 0.25, 0.75, 1]
        sway.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeIn),
        ]
        sway.isAdditive = true
        sway.duration = period
        sway.repeatCount = .infinity
        sway.preferredFrameRateRange = frameRates
        return sway
    }
}

extension CATransaction {
    static func withoutActions(_ changes: () -> Void) {
        begin()
        setDisableActions(true)
        changes()
        commit()
    }
}

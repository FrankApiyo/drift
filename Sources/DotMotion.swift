import QuartzCore

/// Builds the animations that move and restyle a dot. The render server runs
/// them; the app only builds them at wraps, setting changes and mood changes.
enum DotMotion {
    static let rotationKey = "transform.rotation.z"
    static let driftKey = "drift"
    static let wobbleKey = "wobble"
    static let turnKey = "turn"
    static let glowKey = "glow"
    static let restyleKey = "restyle"
    static let swellKey = "swell"
    /// What `Dot.stop()` removes. A mood's restyle and swell last under half
    /// a minute, so they are left to finish rather than snap.
    static let keys = [driftKey, wobbleKey, turnKey, glowKey]
    /// Slow motion looks the same at 30 fps, so don't ask ProMotion screens for 120.
    static let frameRates = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
    static let swellScale: CGFloat = 1.15

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
        guard pass.wobbleAmplitude > 0, pass.wobblePeriod > 0 else { return nil }
        let wobble = sway(keyPath: "position.x", amplitude: Double(pass.wobbleAmplitude), period: pass.wobblePeriod)
        if pass.wobblesInUnison {
            let nextBeat = (CACurrentMediaTime() / pass.wobblePeriod).rounded(.up) * pass.wobblePeriod
            wobble.beginTime = layer.convertTime(nextBeat, from: nil)
        }
        return wobble
    }

    /// Spins from wherever the dot faces, so resuming doesn't snap it upright,
    /// or rocks either side of that angle.
    static func turn(for pass: DotPass, on layer: CALayer) -> CAAnimation? {
        switch pass.turn {
        case .still:
            return nil
        case let .spin(period, clockwise):
            let start = (layer.value(forKeyPath: rotationKey) as? NSNumber)?.doubleValue ?? 0
            let spin = CABasicAnimation(keyPath: rotationKey)
            spin.fromValue = start
            spin.toValue = start + (clockwise ? -2 : 2) * Double.pi
            spin.duration = period
            spin.repeatCount = .infinity
            spin.preferredFrameRateRange = frameRates
            return spin
        case let .rock(amplitude, period):
            return sway(keyPath: rotationKey, amplitude: amplitude, period: period)
        }
    }

    /// A firefly brightens and dims between its alpha and the glow floor,
    /// starting from `opacity` after a random wait, so fireflies glow out of step.
    static func glow(for pass: DotPass, from opacity: Float, on layer: CALayer) -> CAAnimation? {
        guard let period = pass.glowPeriod, period > 0 else { return nil }
        let dimmest = pass.alpha * DotPass.glowFloor
        let glow = CABasicAnimation(keyPath: "opacity")
        glow.fromValue = opacity
        glow.toValue = opacity - dimmest > pass.alpha - opacity ? dimmest : pass.alpha
        glow.duration = period / 2
        glow.autoreverses = true
        glow.repeatCount = .infinity
        glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glow.beginTime = layer.convertTime(CACurrentMediaTime() + .random(in: 0..<period), from: nil)
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

    /// Grows a little and settles while the look changes. It animates
    /// bounds rather than transform so it never fights the turn.
    static func swell(size: CGSize, beginTime: CFTimeInterval, duration: TimeInterval) -> CAKeyframeAnimation {
        let grown = CGSize(width: size.width * swellScale, height: size.height * swellScale)
        let swell = CAKeyframeAnimation(keyPath: "bounds.size")
        swell.values = [size, grown, size].map { NSValue(size: $0) }
        swell.keyTimes = [0, 0.4, 1]
        swell.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 2)
        swell.beginTime = beginTime
        swell.duration = duration
        swell.preferredFrameRateRange = frameRates
        return swell
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

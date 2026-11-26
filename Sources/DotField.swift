import QuartzCore

/// All the dots on one screen, inside a container layer whose opacity sets
/// how visible they are.
final class DotField {
    private let container = CALayer()
    private let screenFrame: CGRect
    private let scale: CGFloat
    private var speedFactor: Double
    private var mood: Mood
    private var reduceMotion: Bool
    /// The union of every screen, for spectrum colours; known once a sweep arrives.
    private var desktop: CGRect
    private var dots: [Dot] = []
    private var visitor: VisitorFlight?
    private var isRunning = false
    /// The opacity setting, which a fade returns to.
    private var opacity: Float = 1
    private var isFadedOut = false

    private static let moodFadeDurations: ClosedRange<TimeInterval> = 3...8
    private static let opacityChangeSeconds: TimeInterval = 0.25
    private static let fadeKey = "fade"

    /// `screenFrame` is in global desktop coordinates, so sweeps and spectrum
    /// colours line up across displays.
    init(screenFrame: CGRect, scale: CGFloat, count: Int, speedFactor: Double, mood: Mood, reduceMotion: Bool) {
        self.screenFrame = screenFrame
        self.scale = scale
        self.speedFactor = speedFactor
        self.mood = mood
        self.reduceMotion = reduceMotion
        desktop = screenFrame
        container.frame = CGRect(origin: .zero, size: screenFrame.size)
        container.contentsScale = scale
        // Group opacity would flatten every dot into a screen-sized offscreen
        // buffer each frame. Dots rarely overlap, so per-dot opacity looks the same.
        container.allowsGroupOpacity = false
        setCount(count)
    }

    func attach(to host: CALayer) {
        host.addSublayer(container)
    }

    func setRunning(_ running: Bool) {
        guard running != isRunning else { return }
        isRunning = running
        dots.forEach { running ? $0.start() : $0.stop() }
        if !running { landVisitor() }
    }

    func setCount(_ count: Int) {
        let kept = Array(dots.prefix(count))
        dots.dropFirst(count).forEach { dot in
            dot.stop()
            dot.layer.removeFromSuperlayer()
        }
        kept.enumerated().forEach { index, dot in dot.setColumn(index, of: count) }
        let added = (kept.count..<max(count, kept.count)).map { index in
            Dot(setup: newSetup(index: index, of: count), scale: scale, speedFactor: speedFactor,
                mood: mood, reduceMotion: reduceMotion)
        }
        added.forEach { dot in
            container.addSublayer(dot.layer)
            if isRunning { dot.start() }
        }
        dots = kept + added
    }

    func setSpeedFactor(_ factor: Double) {
        speedFactor = factor
        dots.forEach { $0.setSpeedFactor(factor) }
    }

    /// Restarts each running dot from where it is, without spin, rocking or
    /// wobble and no faster than the Slower setting.
    func setReduceMotion(_ reduce: Bool) {
        guard reduce != reduceMotion else { return }
        reduceMotion = reduce
        dots.forEach { $0.setReduceMotion(reduce) }
        if reduce, visitor?.kind == .shootingStar { landVisitor() }
    }

    /// Fades the whole field out, or back to its opacity setting, from
    /// wherever it is now.
    func fade(toVisible visible: Bool, duration: TimeInterval) {
        isFadedOut = !visible
        animateOpacity(to: visible ? opacity : 0, over: duration)
    }

    /// False while paused, or for a shooting star under Reduce Motion.
    func canShow(_ kind: VisitorKind) -> Bool {
        isRunning && !(reduceMotion && kind == .shootingStar)
    }

    func showVisitor(_ kind: VisitorKind) {
        guard canShow(kind), let flight = VisitorFlight(kind: kind, scale: scale) else { return }
        landVisitor()
        flight.launch(in: container, area: screenFrame.size)
        visitor = flight
    }

    /// The same Sweep is passed to every screen's field, so the new colours
    /// wash across all displays as one front.
    func setMood(_ newMood: Mood, sweep: Sweep) {
        mood = newMood
        if !sweep.desktop.isNull, !sweep.desktop.isEmpty { desktop = sweep.desktop }
        let front = newMood.isSpectrum ? sweep.heading(.leftToRight) : sweep
        var rng = SystemRandomNumberGenerator()
        dots.forEach { dot in
            let local = dot.currentPosition
            let global = CGPoint(x: screenFrame.minX + local.x, y: screenFrame.minY + local.y)
            dot.adopt(
                newMood, desktop: desktop,
                after: front.delay(at: global, using: &rng),
                fadingOver: .random(in: Self.moodFadeDurations, using: &rng))
        }
    }

    /// While faded out, the new value waits for the next fade back in.
    func setOpacity(_ newOpacity: Float) {
        opacity = newOpacity
        guard !isFadedOut else { return }
        // Before the first frame there is nothing on screen to fade from.
        let isShown = container.presentation() != nil
        animateOpacity(to: newOpacity, over: isShown ? Self.opacityChangeSeconds : 0)
    }

    /// Stops every animation, which also releases the dots, since each
    /// running animation holds its dot as delegate.
    func tearDown() {
        setRunning(false)
        landVisitor()
        container.removeFromSuperlayer()
    }

    private func animateOpacity(to target: Float, over duration: TimeInterval) {
        let current = container.presentation()?.opacity ?? container.opacity
        guard duration > 0 else {
            CATransaction.withoutActions {
                container.removeAnimation(forKey: Self.fadeKey)
                container.opacity = target
            }
            return
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = current
        fade.toValue = target
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fade.preferredFrameRateRange = DotMotion.frameRates
        CATransaction.withoutActions {
            container.opacity = target
            container.add(fade, forKey: Self.fadeKey)
        }
    }

    private func landVisitor() {
        visitor?.land()
        visitor = nil
    }

    private func newSetup(index: Int, of count: Int) -> PassSetup {
        PassSetup(
            tier: .forDot(index: index), homeDirection: Bool.random() ? .up : .down,
            column: index, columns: count, screenFrame: screenFrame, desktop: desktop)
    }
}

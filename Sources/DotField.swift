import QuartzCore

/// All the dots on one screen, inside a container layer whose opacity sets
/// how visible they are.
final class DotField {
    private let container = CALayer()
    private let area: CGSize
    private let scale: CGFloat
    private var speedFactor: Double
    private var mood: Mood
    private var dots: [Dot] = []
    private var isRunning = false

    /// A new mood ripples across the screen instead of landing all at once.
    private static let moodRippleDelays: ClosedRange<TimeInterval> = 0...20
    private static let moodFadeDurations: ClosedRange<TimeInterval> = 3...8

    // CONTRACT: screenFrame is in global desktop coordinates (for sweeps across displays).
    init(screenFrame: CGRect, scale: CGFloat, count: Int, speedFactor: Double, mood: Mood, reduceMotion: Bool) {
        let area = screenFrame.size
        self.area = area
        self.scale = scale
        self.speedFactor = speedFactor
        self.mood = mood
        container.frame = CGRect(origin: .zero, size: area)
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
    }

    func setCount(_ count: Int) {
        let removed = dots.dropFirst(count)
        removed.forEach { dot in
            dot.stop()
            dot.layer.removeFromSuperlayer()
        }
        let added = (0..<max(count - dots.count, 0)).map { _ in
            Dot(area: area, scale: scale, speedFactor: speedFactor, mood: mood)
        }
        added.forEach { dot in
            container.addSublayer(dot.layer)
            if isRunning { dot.start() }
        }
        dots = Array(dots.prefix(count)) + added
    }

    func setSpeedFactor(_ factor: Double) {
        speedFactor = factor
        dots.forEach { $0.setSpeedFactor(factor) }
    }

    // CONTRACT STUB: look engine replaces. Only animates while running.
    func setReduceMotion(_ reduceMotion: Bool) {}

    // CONTRACT STUB: look engine replaces. Fades the whole field out or back
    // to its opacity setting (container opacity animation, no group opacity).
    func fade(toVisible visible: Bool, duration: TimeInterval) {}

    // CONTRACT STUB: look engine replaces. One short-lived extra layer.
    func showVisitor(_ kind: VisitorKind) {}

    // CONTRACT: the same Sweep is passed to every screen's field.
    func setMood(_ newMood: Mood, sweep: Sweep) {
        mood = newMood
        dots.forEach { dot in
            dot.adopt(
                newMood,
                after: .random(in: Self.moodRippleDelays),
                fadingOver: .random(in: Self.moodFadeDurations))
        }
    }

    func setOpacity(_ opacity: Float) {
        container.opacity = opacity
    }

    /// Stops every animation, which also releases the dots, since each
    /// running animation holds its dot as delegate.
    func tearDown() {
        setRunning(false)
        container.removeFromSuperlayer()
    }
}

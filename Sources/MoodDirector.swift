import AppKit

/// Changes the mood every few minutes, now and then bringing a visitor or a
/// rare event, and remembers which rare things have been seen.
final class MoodDirector {
    private(set) var mood = Mood.calm
    private(set) var sightings = Sightings.load()
    private var spectrumDay = SpectrumDay.load()
    private var focusClock = FocusClock()
    private var timer: Timer?
    private let isVisiblyAnimating: () -> Bool
    private let windows: () -> [OverlayWindow]

    init(isVisiblyAnimating: @escaping () -> Bool, windows: @escaping () -> [OverlayWindow]) {
        self.isVisiblyAnimating = isVisiblyAnimating
        self.windows = windows
    }

    func start() {
        scheduleChange()
    }

    func changeNow() {
        guard isVisiblyAnimating() else { return }
        timer?.invalidate()
        changeMood()
    }

    func unpausedChanged(_ unpaused: Bool) {
        focusClock = focusClock.running(unpaused, at: Date())
    }

    func woke() {
        focusClock = focusClock.restarted(at: Date())
    }

    /// A single one-shot timer minutes apart; the generous tolerance lets
    /// macOS fold the wake-up into other work.
    private func scheduleChange() {
        let timer = Timer(timeInterval: .random(in: Mood.changeIntervals), repeats: false) { [weak self] _ in
            self?.changeMood()
        }
        timer.tolerance = 30
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func changeMood() {
        let now = Date()
        focusClock = focusClock.checkingActivity(idleFor: Self.secondsSinceInput(), at: now)
        // While paused nobody is watching, so save the surprise.
        if isVisiblyAnimating() {
            applyNextMood(at: now, calendar: .current)
        }
        scheduleChange()
    }

    private func applyNextMood(at now: Date, calendar: Calendar) {
        var rng = SystemRandomNumberGenerator()
        let context = MoodContext(
            date: now, calendar: calendar,
            focusedFor: focusClock.elapsed(at: now),
            spectrumAvailable: spectrumDay.isAvailable(on: now, calendar: calendar),
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        mood = Mood.next(after: mood, context: context, using: &rng)

        DotImages.removeAll()
        let desktop = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let sweep = Sweep.random(desktop: desktop, using: &rng)
        windows().forEach { $0.field.setMood(mood, sweep: sweep) }

        noteRareMood(at: now)
        if let visitor = VisitorKind.roll(at: now, calendar: calendar, using: &rng),
            let window = windows().filter({ $0.isOnScreen && $0.field.canShow(visitor) }).randomElement(using: &rng)
        {
            window.field.showVisitor(visitor)
            record(visitor.rareEvent, at: now)
        }
    }

    private func noteRareMood(at now: Date) {
        focusClock = focusClock.afterMood(event: mood.event, at: now)
        if let event = mood.event {
            record(event, at: now)
        }
        if mood.isSpectrum {
            spectrumDay = spectrumDay.recording(now)
            spectrumDay.save()
            record(.spectrum, at: now)
        }
    }

    private func record(_ event: RareEvent, at date: Date) {
        let updated = sightings.recording(event, at: date)
        guard updated != sightings else { return }
        sightings = updated
        updated.save()
    }

    /// Reads the system's idle time, which needs no Input Monitoring permission.
    private static func secondsSinceInput() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}

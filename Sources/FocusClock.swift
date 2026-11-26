import Foundation

/// How long the dots have been moving without a break while someone is at
/// the Mac. Any pause, wake or idle spell starts it again from zero.
struct FocusClock: Equatable {
    /// Without input for this long, nobody counts as focused.
    static let idleLimit: TimeInterval = 300

    private let startedAt: Date?

    init() {
        startedAt = nil
    }

    private init(startedAt: Date?) {
        self.startedAt = startedAt
    }

    func elapsed(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return max(date.timeIntervalSince(startedAt), 0)
    }

    func running(_ running: Bool, at date: Date) -> FocusClock {
        guard running else { return FocusClock() }
        return startedAt == nil ? FocusClock(startedAt: date) : self
    }

    func restarted(at date: Date) -> FocusClock {
        startedAt == nil ? self : FocusClock(startedAt: date)
    }

    func checkingActivity(idleFor idle: TimeInterval, at date: Date) -> FocusClock {
        idle < Self.idleLimit ? self : restarted(at: date)
    }

    /// Golden hour rewards a long focus, so it starts the count again.
    func afterMood(event: RareEvent?, at date: Date) -> FocusClock {
        event == .goldenHour ? restarted(at: date) : self
    }
}

import Foundation

/// Remembers when a spectrum mood was last shown, so there is at most one a day.
struct SpectrumDay: Equatable {
    private let lastShown: Date?

    init() {
        lastShown = nil
    }

    private init(lastShown: Date?) {
        self.lastShown = lastShown
    }

    func isAvailable(on date: Date, calendar: Calendar) -> Bool {
        guard let lastShown else { return true }
        return !calendar.isDate(lastShown, inSameDayAs: date)
    }

    func recording(_ date: Date) -> SpectrumDay {
        SpectrumDay(lastShown: date)
    }

    static func load(from defaults: UserDefaults = .standard) -> SpectrumDay {
        SpectrumDay(lastShown: defaults.object(forKey: key) as? Date)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(lastShown, forKey: Self.key)
    }

    private static let key = "lastSpectrumDay"
}

import Foundation

/// The first time each rare event was seen, for the menu's Seen list.
struct Sightings: Equatable {
    private let dates: [RareEvent: Date]

    init() {
        dates = [:]
    }

    private init(dates: [RareEvent: Date]) {
        self.dates = dates
    }

    func firstSeen(_ event: RareEvent) -> Date? {
        dates[event]
    }

    func recording(_ event: RareEvent, at date: Date) -> Sightings {
        guard dates[event] == nil else { return self }
        return Sightings(dates: dates.merging([event: date]) { first, _ in first })
    }

    func menuTitle(for event: RareEvent, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        guard let date = dates[event] else { return "???" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(event.title) — \(formatter.string(from: date))"
    }

    static func load(from defaults: UserDefaults = .standard) -> Sightings {
        let stored = defaults.dictionary(forKey: key) ?? [:]
        let pairs = stored.compactMap { name, value -> (RareEvent, Date)? in
            guard let event = RareEvent(rawValue: name), let date = value as? Date else { return nil }
            return (event, date)
        }
        return Sightings(dates: Dictionary(pairs) { first, _ in first })
    }

    func save(to defaults: UserDefaults = .standard) {
        let stored = Dictionary(uniqueKeysWithValues: dates.map { ($0.key.rawValue, $0.value) })
        defaults.set(stored, forKey: Self.key)
    }

    private static let key = "sightings"
}

extension VisitorKind {
    var rareEvent: RareEvent {
        switch self {
        case .shootingStar: .shootingStar
        case .lantern: .lantern
        }
    }
}

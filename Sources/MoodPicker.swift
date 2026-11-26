import Foundation

extension Mood {
    static let motionChance = 0.2
    static let spectrumChance = 1.0 / 40
    static let holidayChance = 1.0 / 3
    static let fullMoonChance = 1.0 / 3
    static let goldenHourFocus: TimeInterval = 90 * 60
    static let timedPaletteWeight = 3.0
    static let specialMotions: [MotionStyle] = [.fireflies, .snow, .shoal, .confetti]
    static let snowShapes: [DotShape] = [.circle, .sparkle, .flower, .hexagon, .plus]

    /// Picks the next mood from time of day, the calendar, focus time,
    /// whether a spectrum is still due today, and Reduce Motion.
    static func next<R: RandomNumberGenerator>(after previous: Mood, context: MoodContext, using rng: inout R) -> Mood {
        let mood = special(context: context, using: &rng) ?? ordinary(after: previous, context: context, using: &rng)
        return context.reduceMotion ? mood.restrained(using: &rng) : mood
    }

    private static func special<R: RandomNumberGenerator>(context: MoodContext, using rng: inout R) -> Mood? {
        if context.focusedFor >= goldenHourFocus {
            return Mood(palette: .gold, shapes: [.star, .sparkle], pace: 0.8, event: .goldenHour)
        }
        if context.spectrumAvailable, !context.reduceMotion, chance(spectrumChance, &rng) {
            let shapes = Array([DotShape.circle, .sparkle, .flower, .petal].shuffled(using: &rng).prefix(2))
            return Mood(palette: .spectrum, shapes: shapes, pace: 0.9, event: .spectrum, isSpectrum: true)
        }
        if let holiday = Holiday.on(context.date, calendar: context.calendar), chance(holidayChance, &rng) {
            return holiday.mood(using: &rng)
        }
        if MoonPhase.isFullMoonEvening(context.date, calendar: context.calendar), chance(fullMoonChance, &rng) {
            return Mood(palette: .frost, shapes: [.moon, .sparkle], pace: 0.8, event: .fullMoon)
        }
        return nil
    }

    private static func ordinary<R: RandomNumberGenerator>(
        after previous: Mood, context: MoodContext, using rng: inout R
    ) -> Mood {
        let isBright = !context.reduceMotion && chance(brightChance, &rng)
        let hour = context.calendar.component(.hour, from: context.date)
        let weighted = isBright
            ? Palette.bright.map { ($0, 1.0) }
            : Palette.soft.map { ($0, 1.0) } + Palette.timed(atHour: hour).map { ($0, timedPaletteWeight) }
        let palette = pick(weighted.filter { $0.0 != previous.palette }, using: &rng) ?? previous.palette
        let plain = Mood(palette: palette, shapes: randomShapes(using: &rng), pace: .random(in: paces, using: &rng))
        guard !context.reduceMotion, chance(motionChance, &rng),
              let motion = specialMotions.randomElement(using: &rng)
        else { return plain }
        return plain.moving(motion, avoiding: previous.palette, using: &rng)
    }

    private func moving<R: RandomNumberGenerator>(
        _ motion: MotionStyle, avoiding previous: Palette, using rng: inout R
    ) -> Mood {
        switch motion {
        case .snow:
            let count = Int.random(in: Self.shapeCounts, using: &rng)
            let flakes = Array(Self.snowShapes.shuffled(using: &rng).prefix(count))
            return Mood(palette: .frost, shapes: flakes, pace: pace, motion: .snow)
        case .confetti:
            let bright = Palette.bright.filter { $0 != previous }.randomElement(using: &rng) ?? .neon
            return Mood(palette: bright, shapes: DotShape.allCases, pace: pace, motion: .confetti)
        case .drift, .fireflies, .shoal:
            return Mood(palette: palette, shapes: shapes, pace: pace, motion: motion)
        }
    }

    /// Soft colours and plain drift, keeping the shapes and any event.
    private func restrained<R: RandomNumberGenerator>(using rng: inout R) -> Mood {
        let calmer = palette.isBright ? Palette.soft.randomElement(using: &rng) ?? .ocean : palette
        return Mood(palette: calmer, shapes: shapes, pace: min(pace, 1), event: event)
    }

    private static func chance<R: RandomNumberGenerator>(_ probability: Double, _ rng: inout R) -> Bool {
        Double.random(in: 0..<1, using: &rng) < probability
    }

    private static func pick<R: RandomNumberGenerator>(_ weighted: [(Palette, Double)], using rng: inout R) -> Palette? {
        let total = weighted.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var remaining = Double.random(in: 0..<total, using: &rng)
        for (palette, weight) in weighted {
            if remaining < weight { return palette }
            remaining -= weight
        }
        return weighted.last?.0
    }
}

/// Fixed dates that bring their own mood now and then.
enum Holiday {
    case valentines, halloween, newYear, winterSolstice

    /// Dates are Gregorian whatever the user's calendar; only its time zone counts.
    static func on(_ date: Date, calendar: Calendar) -> Holiday? {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.month, .day], from: date)
        switch (parts.month, parts.day) {
        case (2, 14): return .valentines
        case (10, 31): return .halloween
        case (1, 1): return .newYear
        case (12, 21): return .winterSolstice
        default: return nil
        }
    }

    func mood<R: RandomNumberGenerator>(using rng: inout R) -> Mood {
        switch self {
        case .valentines:
            return Mood(palette: .rose, shapes: [.heart], pace: 0.9, event: .valentines)
        case .halloween:
            return Mood(palette: .amber, shapes: [.moon], pace: 0.8, event: .halloween)
        case .newYear:
            let bright = Palette.bright.randomElement(using: &rng) ?? .citrus
            return Mood(palette: bright, shapes: DotShape.allCases, pace: 1.1, motion: .confetti, event: .newYear)
        case .winterSolstice:
            return Mood(palette: .frost, shapes: [.sparkle, .flower, .hexagon], pace: 0.8, motion: .snow,
                        event: .winterSolstice)
        }
    }
}

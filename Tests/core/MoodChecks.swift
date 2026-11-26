// Checks for mood selection by time, calendar, focus and Reduce Motion, and
// for visitors. Called from main.swift, which owns `check`, `rng` and `day`.
import CoreGraphics
import Foundation

func checkMoodSelectionAndVisitors() {
    // MARK: - Moon phase

    for full in [day(2024, 1, 25, 18), day(2025, 3, 14, 7), day(2026, 11, 24, 12), day(2023, 8, 31, 2)] {
        check(MoonPhase.isFull(at: full), "full moon on \(full), age \(MoonPhase.age(at: full))")
    }
    for notFull in [day(2024, 1, 11, 12), day(2025, 3, 29, 12), day(2026, 11, 17, 12), day(2026, 12, 9, 12)] {
        check(!MoonPhase.isFull(at: notFull), "no full moon on \(notFull), age \(MoonPhase.age(at: notFull))")
    }
    check(MoonPhase.isFullMoonEvening(day(2026, 11, 24, 18), calendar: utc), "18:00 on a full moon is evening")
    check(MoonPhase.isFullMoonEvening(day(2026, 11, 24, 23, 59), calendar: utc), "23:59 on a full moon is evening")
    check(!MoonPhase.isFullMoonEvening(day(2026, 11, 24, 12), calendar: utc), "midday isn't a full moon evening")
    check(!MoonPhase.isFullMoonEvening(day(2026, 11, 17, 21), calendar: utc), "an ordinary night isn't a full moon evening")

    // MARK: - Mood.next

    func context(
        _ date: Date, focusedFor: TimeInterval = 0, spectrum: Bool = false, reduceMotion: Bool = false
    ) -> MoodContext {
        MoodContext(date: date, calendar: utc, focusedFor: focusedFor, spectrumAvailable: spectrum, reduceMotion: reduceMotion)
    }

    func draw(_ count: Int, _ context: MoodContext, after start: Mood = .calm) -> [Mood] {
        var last = start
        return (0..<count).map { _ in
            last = Mood.next(after: last, context: context, using: &rng)
            return last
        }
    }

    let ordinaryDay = day(2026, 3, 10, 14)
    check(!MoonPhase.isFull(at: ordinaryDay), "the ordinary test day has no full moon")

    func paletteShare(_ name: String, in moods: [Mood]) -> Double {
        let soft = moods.filter { !$0.palette.isBright && $0.event == nil && $0.motion == .drift }
        return Double(soft.filter { $0.palette.name == name }.count) / Double(max(soft.count, 1))
    }
    /// How much more often a timed palette comes up than an average ordinary soft one.
    func weighting(_ name: String, in moods: [Mood]) -> Double {
        let others = Palette.soft.map { paletteShare($0.name, in: moods) }
        return paletteShare(name, in: moods) / (others.reduce(0, +) / Double(others.count))
    }
    let afternoon = draw(6000, context(ordinaryDay))
    let dawn = draw(6000, context(day(2026, 3, 10, 6)))
    let night = draw(6000, context(day(2026, 3, 10, 22)))
    let lateNight = draw(2000, context(day(2026, 3, 10, 3)))
    check(paletteShare("Dawn", in: afternoon) == 0 && paletteShare("Night", in: afternoon) == 0,
          "no Dawn or Night in the afternoon")
    check(weighting("Dawn", in: dawn) > 2.2, "Dawn is weighted up at 06:00, got \(weighting("Dawn", in: dawn))×")
    check(paletteShare("Night", in: dawn) == 0, "no Night at dawn")
    check(weighting("Night", in: night) > 2.2, "Night is weighted up at 22:00, got \(weighting("Night", in: night))×")
    check(weighting("Night", in: lateNight) > 2.2, "Night is weighted up at 03:00, got \(weighting("Night", in: lateNight))×")
    check(paletteShare("Dawn", in: night) == 0, "no Dawn at night")
    check(afternoon.allSatisfy { $0.event == nil && !$0.isSpectrum }, "an ordinary afternoon has no events")
    check(zip([Mood.calm] + afternoon, afternoon).allSatisfy { $0.palette != $1.palette || $1.motion == .snow },
          "each mood brings a new palette unless snow asks for Frost")

    let motions = afternoon.filter { $0.motion != .drift }
    check(near(Double(motions.count) / Double(afternoon.count), Mood.motionChance, within: 0.03),
          "about 1 in 5 moods move specially, got \(Double(motions.count) / Double(afternoon.count))")
    for style in [MotionStyle.fireflies, .snow, .shoal, .confetti] {
        check(motions.contains { $0.motion == style }, "\(style) comes up")
    }
    check(motions.filter { $0.motion == .snow }.allSatisfy { $0.palette == .frost }, "snow is Frost")
    check(motions.filter { $0.motion == .confetti }.allSatisfy { $0.palette.isBright && Set($0.shapes) == allShapes },
          "confetti is bright with every shape")

    func eventShare(_ event: RareEvent, in moods: [Mood]) -> Double {
        Double(moods.filter { $0.event == event }.count) / Double(moods.count)
    }
    let holidays: [(Date, RareEvent)] = [
        (day(2026, 2, 14, 10), .valentines), (day(2026, 10, 31, 10), .halloween),
        (day(2027, 1, 1, 10), .newYear), (day(2026, 12, 21, 10), .winterSolstice),
    ]
    for (date, event) in holidays {
        let moods = draw(3000, context(date))
        check(near(eventShare(event, in: moods), 1.0 / 3, within: 0.05), "\(event) is about 1 in 3 on its day, got \(eventShare(event, in: moods))")
        check(moods.allSatisfy { $0.event == nil || $0.event == event }, "only \(event) on its day")
        // Other events may fall three days later (24 December 2026 is a full moon), so only this one is ruled out.
        check(draw(300, context(date.addingTimeInterval(86400 * 3))).allSatisfy { $0.event != event }, "no \(event) three days later")
        let special = moods.filter { $0.event == event }
        switch event {
        case .valentines:
            check(special.allSatisfy { $0.shapes == [.heart] }, "Valentine's Day is hearts")
        case .halloween:
            check(special.allSatisfy { $0.shapes == [.moon] && $0.palette == .amber }, "Halloween is amber moons")
        case .newYear:
            check(special.allSatisfy { $0.motion == .confetti && $0.palette.isBright && Set($0.shapes) == allShapes },
                  "New Year is bright confetti in every shape")
        default:
            check(special.allSatisfy {
                $0.motion == .snow && $0.palette == .frost && Set($0.shapes) == [.sparkle, .flower, .hexagon]
            }, "the solstice is Frost snow in sparkles, flowers and hexagons")
        }
    }

    var persian = Calendar(identifier: .persian)
    persian.timeZone = utc.timeZone
    check(persian.component(.month, from: day(2026, 2, 14, 10)) != 2, "fixture: the Persian calendar's months differ")
    check(Holiday.on(day(2026, 2, 14, 10), calendar: persian) == .valentines,
          "a non-Gregorian calendar still finds Valentine's Day")
    var tokyo = utc
    tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    check(Holiday.on(day(2026, 10, 30, 20), calendar: tokyo) == .halloween, "holidays follow the calendar's time zone")

    let fullMoonNight = draw(3000, context(day(2026, 11, 24, 21)))
    check(near(eventShare(.fullMoon, in: fullMoonNight), 1.0 / 3, within: 0.05), "some full moon evening moods are the full moon")
    check(fullMoonNight.filter { $0.event == .fullMoon }.allSatisfy { $0.palette == .frost && Set($0.shapes) == [.moon, .sparkle] },
          "the full moon is Frost moons and sparkles")
    check(draw(300, context(day(2026, 11, 24, 10))).allSatisfy { $0.event == nil }, "no full moon mood in the morning")

    let golden = draw(200, context(ordinaryDay, focusedFor: 90 * 60))
    check(golden.allSatisfy { $0.event == .goldenHour && Set($0.shapes) == [.star, .sparkle] && $0.palette == .gold },
          "90 minutes of focus brings golden hour")
    check(draw(300, context(ordinaryDay, focusedFor: 89 * 60)).allSatisfy { $0.event != .goldenHour }, "not before 90 minutes")

    let rainbow = draw(16000, context(ordinaryDay, spectrum: true))
    let spectra = rainbow.filter(\.isSpectrum)
    check(near(Double(spectra.count) / Double(rainbow.count), 1.0 / 40, within: 0.008),
          "about 1 in 40 moods is a spectrum, got \(Double(spectra.count) / Double(rainbow.count))")
    check(rainbow.allSatisfy { $0.isSpectrum == ($0.event == .spectrum) }, "spectrum moods carry the spectrum event")
    check(spectra.allSatisfy { $0.palette == .spectrum && $0.motion == .drift }, "spectrum moods use the spectrum hues")
    check(!draw(4000, context(ordinaryDay, spectrum: false)).contains(where: \.isSpectrum), "no spectrum once it's been seen")

    let restrained = draw(4000, context(day(2027, 1, 1, 10), spectrum: true, reduceMotion: true))
        + draw(1000, context(day(2026, 12, 21, 10), reduceMotion: true))
    check(restrained.allSatisfy { !$0.palette.isBright }, "Reduce Motion keeps to soft palettes")
    check(restrained.allSatisfy { $0.motion == .drift }, "Reduce Motion keeps plain drift")
    check(!restrained.contains(where: \.isSpectrum), "Reduce Motion skips the spectrum")
    check(restrained.contains { $0.event == .newYear } && restrained.contains { $0.event == .winterSolstice },
          "Reduce Motion still marks the day")

    // MARK: - Names

    check(RareEvent.allCases.map(\.title) == [
        "Shooting star", "Lantern", "Spectrum", "Golden hour", "Full moon",
        "Valentine's Day", "Halloween", "New Year", "Winter solstice",
    ], "rare events have friendly titles")
    check(Mood(palette: .dusk, shapes: [.star, .heart], pace: 1).summary == "Dusk · stars, hearts", "plain summary")
    check(Mood(palette: .neon, shapes: [.ring], pace: 1, motion: .fireflies).summary == "Neon · fireflies · rings",
          "summary names the motion")
    check(Mood(palette: .rose, shapes: [.heart], pace: 1, event: .valentines).name == "Valentine's Day", "events name the mood")
    check(Mood(palette: .citrus, shapes: DotShape.allCases, pace: 1, motion: .confetti, event: .newYear).summary
          == "New Year · confetti · all shapes", "every shape reads as all shapes")
    check(Mood.calm.name == "Ocean", "ordinary moods are named for their palette")
    check(Set(DotShape.allCases.map(\.pluralName)).count == DotShape.allCases.count, "every shape has its own plural")

    // MARK: - Visitors

    var visitors = 0
    for _ in 0..<30000 {
        visitors += VisitorKind.roll(at: day(2026, 3, 10, 14), calendar: utc, using: &rng) == nil ? 0 : 1
    }
    check(near(Double(visitors) / 30000, 1.0 / 15, within: 0.01), "a visitor comes about 1 in 15 mood changes, got \(Double(visitors) / 30000)")
    for (hour, kind) in [(20, VisitorKind.shootingStar), (23, .shootingStar), (0, .shootingStar), (5, .shootingStar),
                         (6, .lantern), (12, .lantern), (19, .lantern)] {
        let seen = Set((0..<600).compactMap { _ in VisitorKind.roll(at: day(2026, 3, 10, hour, 30), calendar: utc, using: &rng) })
        check(seen == [kind], "at \(hour):30 the visitor is \(kind), got \(seen)")
    }
    for _ in 0..<200 {
        let star = VisitorPath.random(for: .shootingStar, area: area, using: &rng)
        check((8...10).contains(star.duration), "a shooting star takes 8–10 s")
        check([star.start, star.control, star.end].allSatisfy { screen.contains($0) }, "a shooting star stays on screen")
        check(abs(star.end.y - star.start.y) < abs(star.end.x - star.start.x) * 0.5, "a shooting star's arc is shallow")
        let lantern = VisitorPath.random(for: .lantern, area: area, using: &rng)
        check(lantern.duration >= 60 && lantern.duration <= 90, "a lantern takes 60–90 s")
        check(lantern.start.y < 0 && lantern.end.y > area.height, "a lantern rises from below to above the screen")
    }
}

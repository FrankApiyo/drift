// Plain assertions for Drift's pure logic. Command Line Tools ship without
// XCTest, so `./build.sh test` compiles this with the sources it covers.
import CoreGraphics
import Foundation
import QuartzCore

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    guard !condition else { return }
    failures += 1
    print("FAIL (line \(line)): \(message)")
}

func near(_ value: Double, _ target: Double, within slack: Double) -> Bool {
    abs(value - target) <= slack
}

let area = CGSize(width: 1512, height: 982)
let screen = CGRect(origin: .zero, size: area)
let tolerance = 1e-9
var rng = SplitMix64(seed: 42)

var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(identifier: "UTC")!
func day(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: hour, minute: minute))!
}

func setup(
    tier: DepthTier = .mid, direction: DotPass.Direction = .up, column: Int = 0, columns: Int = 1,
    screenFrame: CGRect = screen, desktop: CGRect = screen
) -> PassSetup {
    PassSetup(tier: tier, homeDirection: direction, column: column, columns: columns,
              screenFrame: screenFrame, desktop: desktop)
}

// MARK: - Ordinary moods and passes

/// Only `Mood.next`'s ordinary branch runs here: 14:00 brings no timed
/// palette, 10 March 2026 is no holiday, focus is short of golden hour, the
/// spectrum is used up and Reduce Motion is off. A full moon only counts in
/// the evening.
let ordinaryContext = MoodContext(
    date: day(2026, 3, 10, 14), calendar: utc, focusedFor: 0, spectrumAvailable: false, reduceMotion: false)
check(Holiday.on(ordinaryContext.date, calendar: utc) == nil
      && !MoonPhase.isFullMoonEvening(ordinaryContext.date, calendar: utc)
      && Palette.timed(atHour: 14).isEmpty, "fixture: the ordinary context has no holiday, full moon or timed palette")

/// Snow and confetti bring their own palette, and confetti every shape.
func keepsItsPalette(_ mood: Mood) -> Bool {
    mood.motion != .snow && mood.motion != .confetti
}

var mood = Mood.calm
for round in 0..<2000 {
    if round % 50 == 0 {
        let next = Mood.next(after: mood, context: ordinaryContext, using: &rng)
        check(next.event == nil, "an ordinary context brings no event")
        check(next.palette != mood.palette || next.motion == .snow, "a new mood brings a new palette")
        check(Mood.shapeCounts.contains(next.shapes.count) || next.motion == .confetti,
              "mood has \(next.shapes.count) shapes")
        check(Set(next.shapes).count == next.shapes.count, "mood shapes are distinct")
        check(Mood.paces.contains(next.pace), "mood pace \(next.pace) in range")
        // The pass checks below are for plain drift.
        if next.motion == .drift { mood = next }
    }
    for direction in [DotPass.Direction.up, .down] {
        let tier = DepthTier.allCases[round % DepthTier.allCases.count]
        let pass = DotPass.random(setup(tier: tier, direction: direction), mood: mood, oddOneOutChance: 0, using: &rng)
        let start = pass.startY(areaHeight: area.height)
        let end = pass.endY(areaHeight: area.height)
        let crossing = pass.duration(fromY: start, areaHeight: area.height, speedFactor: 1)
        let seconds = DotPass.crossingSeconds

        check(pass.direction == direction, "pass keeps the dot's direction")
        check((0...area.width).contains(pass.x), "x \(pass.x) is on screen")
        check(tier.diameters.contains(pass.diameter), "\(tier) diameter \(pass.diameter) in range")
        check(tier.alphas.contains(pass.alpha), "\(tier) alpha \(pass.alpha) in range")
        check(pass.look.softness == tier.softness, "\(tier) look has the tier's softness")
        check(mood.shapes.contains(pass.look.shape), "shape comes from the mood")
        check(mood.palette.colors.contains(pass.look.color), "colour comes from the mood")
        check(pass.look.accent.map { mood.palette.colors.contains($0) && $0 != pass.look.color } ?? true,
              "an accent is another colour from the mood")
        check(pass.glowPeriod == nil && !pass.wobblesInUnison, "a drift mood has no glow or shared sway")
        check(crossing >= seconds.lowerBound * tier.crossingFactor / mood.pace - tolerance
              && crossing <= seconds.upperBound * tier.crossingFactor / mood.pace + tolerance,
              "\(tier) crossing takes \(crossing)s at pace \(mood.pace)")
        check(abs(pass.duration(fromY: start, areaHeight: area.height, speedFactor: 2) - crossing / 2) < tolerance,
              "doubling the speed factor halves the time")
        check(pass.duration(fromY: end, areaHeight: area.height, speedFactor: 1) == 0,
              "no time left once at the far edge")

        let radius = pass.diameter / 2
        let (bottom, top) = direction == .up ? (start, end) : (end, start)
        check(bottom <= -radius && top >= area.height + radius,
              "\(direction) pass enters and leaves fully off screen")
    }
}

var ordinaryMoods: [Mood] = []
var previous = Mood.calm
for _ in 0..<4000 {
    previous = Mood.next(after: previous, context: ordinaryContext, using: &rng)
    ordinaryMoods.append(previous)
}
let paletteKeepers = ordinaryMoods.filter(keepsItsPalette)
let brightShare = Double(paletteKeepers.filter(\.palette.isBright).count) / Double(paletteKeepers.count)
let moodShapes = Set(paletteKeepers.flatMap(\.shapes))
check(abs(brightShare - Mood.brightChance) < 0.05, "bright moods come up about \(Mood.brightChance) of the time, got \(brightShare)")
check(moodShapes == Set(DotShape.allCases), "moods use every shape over time")
check(Palette.all.contains { $0.isBright } && Palette.all.contains { !$0.isBright }, "there are bright and soft palettes")
check(Set(Palette.soft.map(\.name)).isSuperset(of: ["Aurora", "Sherbet"]), "soft palettes include Aurora and Sherbet")
check(Set(Palette.bright.map(\.name)).isSuperset(of: ["Citrus", "Sunset Pop"]), "bright palettes include Citrus and Sunset Pop")
check(Set(DotShape.allCases).isSuperset(of: [.pebble, .capsule, .plus, .squiggle, .petal, .spiral, .cluster]),
      "the new abstract shapes exist")

let allShapes = Set(DotShape.allCases)
let allColors = Set(Palette.all.flatMap(\.colors))
var oddShapes = Set<DotShape>()
var accentLooks = 0
for _ in 0..<2000 {
    let look = Mood.calm.randomLook(oddOneOutChance: 1, using: &rng)
    check(allShapes.contains(look.shape) && allColors.contains(look.color), "odd one out uses a known look")
    oddShapes.insert(look.shape)
    accentLooks += Mood.calm.randomLook(oddOneOutChance: 0, using: &rng).accent == nil ? 0 : 1
}
check(oddShapes == allShapes, "odd ones out can take any shape")
let accentShare = Double(accentLooks) / 2000
check(accentShare > 0.1 && accentShare < 0.4, "two-tone looks are a minority, got \(accentShare)")

let original = DotPass.random(setup(), mood: .calm, oddOneOutChance: 0, using: &rng)
let newLook = DotLook(shape: .star, color: Palette.all[1].colors[0])
let restyled = original.restyled(newLook, using: &rng)
check(restyled.look == newLook, "restyle changes the look")
check(restyled.diameter == original.diameter && restyled.x == original.x
      && restyled.pointsPerSecond == original.pointsPerSecond, "restyle keeps size, place and speed")

let trip = Trip(fromY: 0, toY: 100, startTime: 10, duration: 20)
check(trip.y(at: 10) == 0, "trip starts at fromY")
check(trip.y(at: 20) == 50, "trip is halfway at half time")
check(trip.y(at: 40) == 100, "trip clamps at toY after it ends")
check(trip.y(at: 5) == 0, "trip clamps at fromY before it starts")
check(Trip(fromY: 3, toY: 9, startTime: 0, duration: 0).y(at: 0) == 9, "zero-length trip is already done")

// MARK: - Depth tiers

var tierCounts: [DepthTier: Int] = [:]
for index in 0..<1000 { tierCounts[DepthTier.forDot(index: index), default: 0] += 1 }
check(near(Double(tierCounts[.far, default: 0]) / 1000, 0.55, within: 0.02), "about 55% far, got \(tierCounts)")
check(near(Double(tierCounts[.mid, default: 0]) / 1000, 0.35, within: 0.02), "about 35% mid, got \(tierCounts)")
check(near(Double(tierCounts[.near, default: 0]) / 1000, 0.10, within: 0.02), "about 10% near, got \(tierCounts)")
for count in [15, 25, 40] {
    let tiers = (0..<count).map(DepthTier.forDot(index:))
    let nearCount = tiers.filter { $0 == .near }.count
    let farCount = tiers.filter { $0 == .far }.count
    check((1...Int((Double(count) * 0.15).rounded(.up))).contains(nearCount), "\(count) dots have a few near ones, got \(nearCount)")
    check(Double(farCount) >= Double(count) * 0.45, "\(count) dots are mostly far, got \(farCount)")
}
check(DepthTier.far.diameters == 4...9 && DepthTier.mid.diameters == 9...20 && DepthTier.near.diameters == 28...44,
      "tier sizes are far 4–9, mid 9–20, near 28–44")
check(DepthTier.far.crossingFactor == 1.6 && DepthTier.mid.crossingFactor == 1 && DepthTier.near.crossingFactor == 0.7,
      "far dots cross slower and near ones faster")
check(DepthTier.far.alphas.upperBound < DepthTier.mid.alphas.upperBound
      && DepthTier.near.alphas.upperBound <= 0.35, "far dots are fainter and near ones stay low")
check(DepthTier.far.wobbleFactor < DepthTier.mid.wobbleFactor, "far dots wobble less")
check(DepthTier.far.zPosition < DepthTier.mid.zPosition && DepthTier.mid.zPosition < DepthTier.near.zPosition,
      "near dots draw over far ones")
for (back, front) in [(DepthTier.far, DepthTier.mid), (.mid, .near)] {
    let between = DepthTier.zPosition(between: back, and: front)
    check(back.zPosition < between && between < front.zPosition, "a visitor can pass between \(back) and \(front) dots")
}
check(DepthTier.near.softness == .verySoft && DepthTier.far.softness == .soft && DepthTier.mid.softness == .normal,
      "far and near looks are softer")

// MARK: - Even spread

for columns in [15, 25, 40] {
    let width = area.width / CGFloat(columns)
    var lowest = CGFloat.infinity
    var highest = -CGFloat.infinity
    for column in 0..<columns {
        for _ in 0..<40 {
            let pass = DotPass.random(setup(column: column, columns: columns), mood: .calm, oddOneOutChance: 0, using: &rng)
            let offset = (pass.x - (CGFloat(column) + 0.5) * width) / (width / 2)
            check(abs(offset) <= 0.7 + 1e-9, "dot \(column) of \(columns) stays inside its column, offset \(offset)")
            lowest = min(lowest, offset)
            highest = max(highest, offset)
        }
    }
    check(lowest < -0.5 && highest > 0.5, "x jitters across most of the column, got \(lowest)...\(highest)")
}

// MARK: - Shape-aware motion

for shape in [DotShape.circle, .ring] {
    let pass = DotPass.random(setup(), mood: Mood(palette: .ocean, shapes: [shape], pace: 1), oddOneOutChance: 0, using: &rng)
    check(pass.turn == .still, "\(shape) doesn't turn")
}
for shape in [DotShape.star, .sparkle, .flower, .hexagon, .plus, .spiral, .cluster] {
    let pass = DotPass.random(setup(), mood: Mood(palette: .ocean, shapes: [shape], pace: 1), oddOneOutChance: 0, using: &rng)
    if case let .spin(period, _) = pass.turn {
        check(DotPass.spinPeriods.contains(period), "\(shape) spins slowly, period \(period)")
    } else {
        check(false, "\(shape) spins fully")
    }
}
for shape in [DotShape.heart, .moon, .triangle, .petal, .capsule, .squiggle] {
    let pass = DotPass.random(setup(), mood: Mood(palette: .ocean, shapes: [shape], pace: 1), oddOneOutChance: 0, using: &rng)
    if case let .rock(amplitude, period) = pass.turn {
        let degrees = amplitude * 180 / .pi
        check((15...25).contains(degrees), "\(shape) rocks ±\(degrees)°")
        check(DotPass.rockPeriods.contains(period), "\(shape) rocks gently, period \(period)")
    } else {
        check(false, "\(shape) rocks instead of spinning")
    }
}

// MARK: - Motion each pass needs

func drawPass(_ shape: DotShape, motion: MotionStyle = .drift) -> DotPass {
    DotPass.random(setup(), mood: Mood(palette: .meadow, shapes: [shape], pace: 1, motion: motion),
                   oddOneOutChance: 0, using: &rng)
}
let fireflyStar = drawPass(.star, motion: .fireflies)
let plainCircle = drawPass(.circle)
let plainStar = drawPass(.star)
check(fireflyStar.glowPeriod != nil && fireflyStar.wobbleAmplitude > 0 && fireflyStar.turn != .still,
      "fixture: a firefly star glows, sways and turns")
check(plainCircle.glowPeriod == nil && plainCircle.wobbleAmplitude > 0 && plainCircle.turn == .still,
      "fixture: a plain circle sways but neither glows nor turns")
func motionKeys(_ pass: DotPass, reduceMotion: Bool = false, angle: Double = 0) -> [String] {
    let layer = CALayer()
    layer.setValue(angle, forKeyPath: DotMotion.rotationKey)
    return DotMotion.motions(for: pass, on: layer, reduceMotion: reduceMotion).map(\.key)
}
check(Set(motionKeys(fireflyStar)) == [DotMotion.wobbleKey, DotMotion.turnKey, DotMotion.glowKey],
      "a firefly star needs every motion but a settle")
check(motionKeys(plainCircle) == [DotMotion.wobbleKey], "a plain circle after a firefly pass needs no glow and no turn")
check(motionKeys(plainStar, reduceMotion: true).isEmpty, "Reduce Motion needs only drift")
check(motionKeys(fireflyStar, reduceMotion: true) == [DotMotion.glowKey],
      "Reduce Motion keeps a firefly's glow, which doesn't move it")
check(motionKeys(plainStar, angle: 2.9) == [DotMotion.wobbleKey, DotMotion.turnKey], "a star spins on from any angle")
check(motionKeys(drawPass(.heart), angle: 2.9) == [DotMotion.settleKey, DotMotion.wobbleKey, DotMotion.turnKey],
      "a tilted heart settles upright under its rock")
check(motionKeys(plainCircle, reduceMotion: true, angle: 0.3) == [DotMotion.settleKey],
      "Reduce Motion still brings a tilted shape upright")
check([fireflyStar, plainCircle, plainStar].allSatisfy { Set(motionKeys($0, angle: 1)).isSubset(of: DotMotion.keys) }
      && DotMotion.keys.contains(DotMotion.driftKey), "every motion is one that stop() removes")

// MARK: - Restyled turns

let spinningStar = drawPass(.star)
let rockingHeart = drawPass(.heart)
let tumblingHeart = drawPass(.heart, motion: .confetti)
check(spinningStar.turn.style == .spin && rockingHeart.turn.style == .rock && tumblingHeart.turn.style == .spin,
      "fixture: a star spins, a heart rocks, a confetti heart spins")
func restyle(_ original: DotPass, to shape: DotShape) -> DotPass {
    original.restyled(DotLook(shape: shape, color: original.look.color), using: &rng)
}
check(restyle(spinningStar, to: .heart).turn.style == .rock, "a star that becomes a heart rocks instead of spinning")
check(restyle(spinningStar, to: .circle).turn == .still, "a star that becomes a circle stops turning")
check(restyle(spinningStar, to: .sparkle).turn == spinningStar.turn, "a star that becomes a sparkle keeps its spin")
check(restyle(rockingHeart, to: .moon).turn == rockingHeart.turn, "a heart that becomes a moon keeps its rocking")
if case let .spin(period, _) = restyle(rockingHeart, to: .star).turn {
    check(DotPass.spinPeriods.contains(period), "a restyled star spins at drift speed, period \(period)")
} else {
    check(false, "a heart that becomes a star spins")
}
check(restyle(tumblingHeart, to: .moon).turn == tumblingHeart.turn, "confetti keeps tumbling as its shape changes")

// MARK: - Special motion

let fireflies = Mood(palette: .meadow, shapes: [.circle], pace: 1, motion: .fireflies)
let snow = Mood(palette: .frost, shapes: [.sparkle], pace: 1, motion: .snow)
let shoal = Mood(palette: .ocean, shapes: [.petal], pace: 1, motion: .shoal)
let confetti = Mood(palette: .citrus, shapes: DotShape.allCases, pace: 1, motion: .confetti)
var shoalPeriods = Set<Double>()
var snowSway: CGFloat = 0
var driftSway: CGFloat = 0
for _ in 0..<300 {
    let tier = DepthTier.forDot(index: Int.random(in: 0..<100, using: &rng))
    let glow = DotPass.random(setup(tier: tier), mood: fireflies, oddOneOutChance: 0, using: &rng)
    check(glow.glowPeriod.map(DotPass.glowPeriods.contains) ?? false, "fireflies glow over 5–9 s")
    check(DotPass.glowFloor >= 0.4, "fireflies never dim below 40%")

    let flake = DotPass.random(setup(tier: tier, direction: .up), mood: snow, oddOneOutChance: 0, using: &rng)
    check(flake.direction == .down, "snow always falls")
    check(flake.diameter < tier.diameters.upperBound * 0.75, "snowflakes are small, got \(flake.diameter)")
    snowSway += flake.wobbleAmplitude
    driftSway += DotPass.random(setup(tier: tier), mood: .calm, oddOneOutChance: 0, using: &rng).wobbleAmplitude

    let fish = DotPass.random(setup(tier: tier), mood: shoal, oddOneOutChance: 0, using: &rng)
    check(fish.wobblesInUnison, "a shoal sways in unison")
    shoalPeriods.insert(fish.wobblePeriod)

    let piece = DotPass.random(setup(tier: tier), mood: confetti, oddOneOutChance: 0, using: &rng)
    if piece.look.shape == .circle || piece.look.shape == .ring {
        check(piece.turn == .still, "round confetti doesn't turn")
    } else if case let .spin(period, _) = piece.turn {
        check(DotPass.confettiSpinPeriods.contains(period), "confetti spins faster, period \(period)")
    } else {
        check(false, "confetti \(piece.look.shape) tumbles instead of rocking")
    }
}
check(shoalPeriods.count == 1, "a shoal shares one wobble period, got \(shoalPeriods)")
check(snowSway > driftSway * 1.4, "snow sways more than drift")
check(DotPass.confettiSpinPeriods.upperBound < DotPass.spinPeriods.lowerBound, "confetti spins faster than drift")

// MARK: - Spectrum colour by x

let desktop = CGRect(x: 0, y: 0, width: 3024, height: 982)
let rightScreen = CGRect(x: 1512, y: 0, width: 1512, height: 982)
let spectrum = Mood(palette: .spectrum, shapes: [.circle], pace: 1, event: .spectrum, isSpectrum: true)
check(Palette.spectrum.colors.count == 7, "the spectrum has 7 hues")
for _ in 0..<400 {
    let column = Int.random(in: 0..<25, using: &rng)
    let pass = DotPass.random(
        setup(column: column, columns: 25, screenFrame: rightScreen, desktop: desktop),
        mood: spectrum, oddOneOutChance: 1, using: &rng)
    let fraction = (rightScreen.minX + pass.x) / desktop.width
    let hue = min(Int(fraction * 7), 6)
    check(pass.look.color == Palette.spectrum.colors[hue], "spectrum colour follows global x \(fraction)")
    check(pass.look.accent == nil, "spectrum dots are one colour")
}
check(spectrum.randomLook(oddOneOutChance: 0, desktopFraction: 0, using: &rng).color == Palette.spectrum.colors[0],
      "the left edge is the first hue")
check(spectrum.randomLook(oddOneOutChance: 0, desktopFraction: 1, using: &rng).color == Palette.spectrum.colors[6],
      "the right edge is the last hue")

// MARK: - Sweep

var directions = Set<Sweep.Direction>()
for _ in 0..<500 { directions.insert(Sweep.random(desktop: desktop, using: &rng).direction) }
check(directions == Set(Sweep.Direction.allCases), "sweeps come from every direction")
check(Sweep.Direction.allCases.count == 5, "five sweep directions")

let mid = CGPoint(x: desktop.midX, y: desktop.midY)
let leftEdge = CGPoint(x: desktop.minX, y: desktop.midY)
let rightEdge = CGPoint(x: desktop.maxX, y: desktop.midY)
let bottomEdge = CGPoint(x: desktop.midX, y: desktop.minY)
let topEdge = CGPoint(x: desktop.midX, y: desktop.maxY)
let corner = CGPoint(x: desktop.maxX, y: desktop.maxY)
let expectations: [(Sweep.Direction, CGPoint, Double)] = [
    (.leftToRight, leftEdge, 0), (.leftToRight, rightEdge, 1), (.leftToRight, mid, 0.5),
    (.rightToLeft, leftEdge, 1), (.rightToLeft, rightEdge, 0),
    (.bottomToTop, bottomEdge, 0), (.bottomToTop, topEdge, 1),
    (.topToBottom, bottomEdge, 1), (.topToBottom, topEdge, 0),
    (.outFromCentre, mid, 0), (.outFromCentre, corner, 1),
]
for (direction, point, progress) in expectations {
    let sweep = Sweep(desktop: desktop, direction: direction)
    check(near(sweep.progress(at: point), progress, within: 1e-9), "\(direction) progress at \(point) is \(progress)")
    for _ in 0..<50 {
        let delay = sweep.delay(at: point, using: &rng)
        let expected = progress * Sweep.span
        check(delay >= 0 && near(delay, expected, within: Sweep.jitter + 1e-9) || delay == 0 && expected < Sweep.jitter,
              "\(direction) delay \(delay) is about \(expected)s")
    }
}
check(Sweep.span == 15 && Sweep.jitter == 1.5, "sweeps take about 15 s with 1.5 s jitter")
check(Sweep(desktop: .null, direction: .leftToRight).progress(at: .zero) == 0, "an empty desktop has no front")
check(Sweep(desktop: desktop, direction: .topToBottom).heading(.leftToRight).direction == .leftToRight,
      "a sweep can be turned to run left to right")

checkMoodSelectionAndVisitors()
checkDotMotion()

// MARK: - Settings

/// One fixed suite, cleared before and after, so at most one scratch file
/// ever sits in ~/Library/Preferences.
let suite = "drift.checks.core"
if let defaults = UserDefaults(suiteName: suite) {
    defaults.removePersistentDomain(forName: suite)
    check(Settings.load(from: defaults) == Settings(), "empty defaults load the defaults")
    check(Settings().layer == .behind, "behind windows is the default layer")
    check(Settings().pauseInLowPowerMode, "low power pause is on by default")

    let custom = Settings()
        .with(\.layer, .over)
        .with(\.count, .many)
        .with(\.speed, .slower)
        .with(\.opacity, .visible)
        .with(\.pauseInLowPowerMode, false)
    check(custom != Settings(), "with() returns a changed copy")
    custom.save(to: defaults)
    check(Settings.load(from: defaults) == custom, "settings survive a save and load")
    defaults.removePersistentDomain(forName: suite)
} else {
    check(false, "could not create a scratch UserDefaults suite")
}

print(failures == 0 ? "All checks passed" : "\(failures) check(s) failed")
exit(failures == 0 ? 0 : 1)

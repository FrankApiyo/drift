// Plain assertions for Drift's pure logic. Command Line Tools ship without
// XCTest, so `./build.sh test` compiles this with the sources it covers.
import CoreGraphics
import Foundation

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

let area = CGSize(width: 1512, height: 982)
let tolerance = 1e-9
var rng = SplitMix64(seed: 42)

var mood = Mood.calm
for round in 0..<2000 {
    if round % 50 == 0 {
        let next = Mood.random(after: mood, using: &rng)
        check(next.palette != mood.palette, "a new mood brings a new palette")
        check(Mood.shapeCounts.contains(next.shapes.count), "mood has \(next.shapes.count) shapes")
        check(Set(next.shapes).count == next.shapes.count, "mood shapes are distinct")
        check(Mood.paces.contains(next.pace), "mood pace \(next.pace) in range")
        mood = next
    }
    for direction in [DotPass.Direction.up, .down] {
        let pass = DotPass.random(direction: direction, area: area, mood: mood, oddOneOutChance: 0, using: &rng)
        let start = pass.startY(areaHeight: area.height)
        let end = pass.endY(areaHeight: area.height)
        let crossing = pass.duration(fromY: start, areaHeight: area.height, speedFactor: 1)

        check(pass.direction == direction, "pass keeps the requested direction")
        check((0...area.width).contains(pass.x), "x \(pass.x) is on screen")
        check(DotPass.diameters.contains(pass.diameter), "diameter \(pass.diameter) in range")
        check(mood.shapes.contains(pass.look.shape), "shape comes from the mood")
        check(mood.palette.colors.contains(pass.look.color), "colour comes from the mood")
        check(DotPass.alphas.contains(pass.alpha), "alpha \(pass.alpha) in range")
        check(DotPass.spinPeriods.contains(pass.spinPeriod), "spin period \(pass.spinPeriod) in range")
        check(crossing >= DotPass.crossingSeconds.lowerBound / mood.pace - tolerance
              && crossing <= DotPass.crossingSeconds.upperBound / mood.pace + tolerance,
              "crossing takes \(crossing)s at pace \(mood.pace)")
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

var brightMoods = 0
var moodShapes = Set<DotShape>()
var previous = Mood.calm
for _ in 0..<4000 {
    let next = Mood.random(after: previous, using: &rng)
    brightMoods += next.palette.isBright ? 1 : 0
    moodShapes.formUnion(next.shapes)
    previous = next
}
let brightShare = Double(brightMoods) / 4000
check(abs(brightShare - Mood.brightChance) < 0.05, "bright moods come up about \(Mood.brightChance) of the time, got \(brightShare)")
check(moodShapes == Set(DotShape.allCases), "moods use every shape over time")
check(Palette.all.contains { $0.isBright } && Palette.all.contains { !$0.isBright }, "there are bright and soft palettes")

let allShapes = Set(DotShape.allCases)
let allColors = Set(Palette.all.flatMap(\.colors))
var oddShapes = Set<DotShape>()
for _ in 0..<2000 {
    let look = Mood.calm.randomLook(oddOneOutChance: 1, using: &rng)
    check(allShapes.contains(look.shape) && allColors.contains(look.color), "odd one out uses a known look")
    oddShapes.insert(look.shape)
}
check(oddShapes == allShapes, "odd ones out can take any shape")

let original = DotPass.random(direction: .up, area: area, mood: .calm, oddOneOutChance: 0, using: &rng)
let newLook = DotLook(shape: .star, color: Palette.all[1].colors[0])
let restyled = original.restyled(newLook)
check(restyled.look == newLook, "restyle changes the look")
check(restyled.diameter == original.diameter && restyled.x == original.x
      && restyled.pointsPerSecond == original.pointsPerSecond, "restyle keeps size, place and speed")

let trip = Trip(fromY: 0, toY: 100, startTime: 10, duration: 20)
check(trip.y(at: 10) == 0, "trip starts at fromY")
check(trip.y(at: 20) == 50, "trip is halfway at half time")
check(trip.y(at: 40) == 100, "trip clamps at toY after it ends")
check(trip.y(at: 5) == 0, "trip clamps at fromY before it starts")
check(Trip(fromY: 3, toY: 9, startTime: 0, duration: 0).y(at: 0) == 9, "zero-length trip is already done")

let suite = "drift.checks.\(UUID().uuidString)"
if let defaults = UserDefaults(suiteName: suite) {
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

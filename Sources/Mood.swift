import Foundation

enum DotShape: CaseIterable, Hashable {
    case circle, ring, square, diamond, triangle, star, sparkle, heart, moon, flower, hexagon
}

struct RGB: Hashable {
    let red: Double
    let green: Double
    let blue: Double
}

/// A dot's appearance; also the key for its cached image.
struct DotLook: Hashable {
    let shape: DotShape
    let color: RGB
}

struct Palette: Equatable {
    let name: String
    let colors: [RGB]
    var isBright = false

    static let all: [Palette] = soft + bright

    /// Muted sets for most moods.
    static let soft: [Palette] = [
        Palette(name: "Ocean", colors: [
            RGB(red: 0.62, green: 0.78, blue: 0.95), RGB(red: 0.50, green: 0.68, blue: 0.88),
            RGB(red: 0.55, green: 0.85, blue: 0.85), RGB(red: 0.95, green: 0.97, blue: 1.00),
        ]),
        Palette(name: "Dusk", colors: [
            RGB(red: 0.72, green: 0.66, blue: 0.90), RGB(red: 0.85, green: 0.68, blue: 0.82),
            RGB(red: 0.62, green: 0.66, blue: 0.92), RGB(red: 0.93, green: 0.80, blue: 0.86),
        ]),
        Palette(name: "Meadow", colors: [
            RGB(red: 0.62, green: 0.88, blue: 0.74), RGB(red: 0.72, green: 0.82, blue: 0.62),
            RGB(red: 0.88, green: 0.92, blue: 0.66), RGB(red: 0.96, green: 0.95, blue: 0.86),
        ]),
        Palette(name: "Ember", colors: [
            RGB(red: 0.98, green: 0.76, blue: 0.62), RGB(red: 0.96, green: 0.66, blue: 0.60),
            RGB(red: 0.95, green: 0.84, blue: 0.66), RGB(red: 0.90, green: 0.80, blue: 0.72),
        ]),
        Palette(name: "Frost", colors: [
            RGB(red: 0.92, green: 0.95, blue: 0.98), RGB(red: 0.78, green: 0.84, blue: 0.90),
            RGB(red: 0.80, green: 0.90, blue: 0.98), RGB(red: 0.86, green: 0.86, blue: 0.92),
        ]),
        Palette(name: "Bloom", colors: [
            RGB(red: 0.97, green: 0.74, blue: 0.82), RGB(red: 0.82, green: 0.72, blue: 0.95),
            RGB(red: 0.96, green: 0.88, blue: 0.62), RGB(red: 0.70, green: 0.88, blue: 0.90),
        ]),
    ]

    /// Vivid sets for the occasional lively mood.
    static let bright: [Palette] = [
        Palette(name: "Neon", colors: [
            RGB(red: 1.00, green: 0.25, blue: 0.60), RGB(red: 0.10, green: 0.90, blue: 1.00),
            RGB(red: 0.60, green: 1.00, blue: 0.20), RGB(red: 0.65, green: 0.35, blue: 1.00),
        ], isBright: true),
        Palette(name: "Carnival", colors: [
            RGB(red: 1.00, green: 0.55, blue: 0.10), RGB(red: 1.00, green: 0.85, blue: 0.10),
            RGB(red: 0.95, green: 0.20, blue: 0.30), RGB(red: 0.10, green: 0.75, blue: 0.55),
        ], isBright: true),
    ]
}

/// The look and pace the dots share for a while, until the next surprise.
struct Mood {
    static let paces: ClosedRange<Double> = 0.6...1.5
    static let shapeCounts: ClosedRange<Int> = 1...3
    static let changeIntervals: ClosedRange<TimeInterval> = 120...300
    /// How often a dot ignores the mood and borrows any shape and colour.
    static let oddOneOutChance = 0.08
    static let brightChance = 0.25

    /// The opening mood: blue and teal circles at normal pace.
    static let calm = Mood(palette: Palette.all[0], shapes: [.circle], pace: 1)

    let palette: Palette
    let shapes: [DotShape]
    let pace: Double

    static func random<R: RandomNumberGenerator>(after previous: Mood, using rng: inout R) -> Mood {
        let pool = Double.random(in: 0..<1, using: &rng) < brightChance ? Palette.bright : Palette.soft
        let choices = pool.filter { $0 != previous.palette }
        let shapeCount = Int.random(in: shapeCounts, using: &rng)
        return Mood(
            palette: choices.randomElement(using: &rng) ?? previous.palette,
            shapes: Array(DotShape.allCases.shuffled(using: &rng).prefix(shapeCount)),
            pace: .random(in: paces, using: &rng)
        )
    }

    func randomLook<R: RandomNumberGenerator>(oddOneOutChance: Double, using rng: inout R) -> DotLook {
        let isOddOneOut = Double.random(in: 0..<1, using: &rng) < oddOneOutChance
        let shapes = isOddOneOut ? DotShape.allCases : self.shapes
        let colors = isOddOneOut ? Palette.all.flatMap(\.colors) : palette.colors
        return DotLook(
            shape: shapes.randomElement(using: &rng) ?? .circle,
            color: colors.randomElement(using: &rng) ?? RGB(red: 1, green: 1, blue: 1)
        )
    }
}

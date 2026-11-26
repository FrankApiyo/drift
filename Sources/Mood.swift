import Foundation

enum DotShape: CaseIterable, Hashable {
    case circle, ring, square, diamond, triangle, star, sparkle, heart, moon, flower, hexagon
    case pebble, capsule, plus, squiggle, petal, spiral, cluster

    var pluralName: String {
        switch self {
        case .circle: "circles"
        case .ring: "rings"
        case .square: "squares"
        case .diamond: "diamonds"
        case .triangle: "triangles"
        case .star: "stars"
        case .sparkle: "sparkles"
        case .heart: "hearts"
        case .moon: "moons"
        case .flower: "flowers"
        case .hexagon: "hexagons"
        case .pebble: "pebbles"
        case .capsule: "capsules"
        case .plus: "pluses"
        case .squiggle: "squiggles"
        case .petal: "petals"
        case .spiral: "spirals"
        case .cluster: "clusters"
        }
    }
}

struct RGB: Hashable {
    let red: Double
    let green: Double
    let blue: Double
}

/// How far a dot's glow spreads; deeper tiers are drawn softer.
enum Softness: Hashable {
    case normal, soft, verySoft
}

/// A dot's appearance; also the key for its cached image.
struct DotLook: Hashable {
    let shape: DotShape
    let color: RGB
    /// A second colour washed across the shape, so it shimmers as it turns.
    var accent: RGB?
    var softness = Softness.normal
}

struct Palette: Equatable {
    let name: String
    let colors: [RGB]
    var isBright = false

    static let all: [Palette] = soft + bright

    static let ocean = Palette(name: "Ocean", colors: [
        RGB(red: 0.62, green: 0.78, blue: 0.95), RGB(red: 0.50, green: 0.68, blue: 0.88),
        RGB(red: 0.55, green: 0.85, blue: 0.85), RGB(red: 0.95, green: 0.97, blue: 1.00),
    ])
    static let dusk = Palette(name: "Dusk", colors: [
        RGB(red: 0.72, green: 0.66, blue: 0.90), RGB(red: 0.85, green: 0.68, blue: 0.82),
        RGB(red: 0.62, green: 0.66, blue: 0.92), RGB(red: 0.93, green: 0.80, blue: 0.86),
    ])
    static let meadow = Palette(name: "Meadow", colors: [
        RGB(red: 0.62, green: 0.88, blue: 0.74), RGB(red: 0.72, green: 0.82, blue: 0.62),
        RGB(red: 0.88, green: 0.92, blue: 0.66), RGB(red: 0.96, green: 0.95, blue: 0.86),
    ])
    static let ember = Palette(name: "Ember", colors: [
        RGB(red: 0.98, green: 0.76, blue: 0.62), RGB(red: 0.96, green: 0.66, blue: 0.60),
        RGB(red: 0.95, green: 0.84, blue: 0.66), RGB(red: 0.90, green: 0.80, blue: 0.72),
    ])
    static let frost = Palette(name: "Frost", colors: [
        RGB(red: 0.92, green: 0.95, blue: 0.98), RGB(red: 0.78, green: 0.84, blue: 0.90),
        RGB(red: 0.80, green: 0.90, blue: 0.98), RGB(red: 0.86, green: 0.86, blue: 0.92),
    ])
    static let bloom = Palette(name: "Bloom", colors: [
        RGB(red: 0.97, green: 0.74, blue: 0.82), RGB(red: 0.82, green: 0.72, blue: 0.95),
        RGB(red: 0.96, green: 0.88, blue: 0.62), RGB(red: 0.70, green: 0.88, blue: 0.90),
    ])
    static let aurora = Palette(name: "Aurora", colors: [
        RGB(red: 0.45, green: 0.80, blue: 0.78), RGB(red: 0.66, green: 0.92, blue: 0.80),
        RGB(red: 0.76, green: 0.70, blue: 0.94), RGB(red: 0.58, green: 0.86, blue: 0.90),
    ])
    static let sherbet = Palette(name: "Sherbet", colors: [
        RGB(red: 0.99, green: 0.78, blue: 0.60), RGB(red: 0.95, green: 0.68, blue: 0.76),
        RGB(red: 0.80, green: 0.92, blue: 0.58), RGB(red: 0.99, green: 0.86, blue: 0.74),
    ])

    static let neon = Palette(name: "Neon", colors: [
        RGB(red: 1.00, green: 0.25, blue: 0.60), RGB(red: 0.10, green: 0.90, blue: 1.00),
        RGB(red: 0.60, green: 1.00, blue: 0.20), RGB(red: 0.65, green: 0.35, blue: 1.00),
    ], isBright: true)
    static let carnival = Palette(name: "Carnival", colors: [
        RGB(red: 1.00, green: 0.55, blue: 0.10), RGB(red: 1.00, green: 0.85, blue: 0.10),
        RGB(red: 0.95, green: 0.20, blue: 0.30), RGB(red: 0.10, green: 0.75, blue: 0.55),
    ], isBright: true)
    static let citrus = Palette(name: "Citrus", colors: [
        RGB(red: 1.00, green: 0.82, blue: 0.10), RGB(red: 0.62, green: 0.90, blue: 0.15),
        RGB(red: 1.00, green: 0.58, blue: 0.12), RGB(red: 0.95, green: 0.95, blue: 0.35),
    ], isBright: true)
    static let sunsetPop = Palette(name: "Sunset Pop", colors: [
        RGB(red: 1.00, green: 0.42, blue: 0.35), RGB(red: 1.00, green: 0.70, blue: 0.20),
        RGB(red: 0.92, green: 0.30, blue: 0.62), RGB(red: 0.55, green: 0.35, blue: 0.95),
    ], isBright: true)

    /// Muted sets for most moods.
    static let soft: [Palette] = [ocean, dusk, meadow, ember, frost, bloom, aurora, sherbet]
    /// Vivid sets for the occasional lively mood.
    static let bright: [Palette] = [neon, carnival, citrus, sunsetPop]
}

/// The look and pace the dots share for a while, until the next surprise.
struct Mood {
    static let paces: ClosedRange<Double> = 0.6...1.5
    static let shapeCounts: ClosedRange<Int> = 1...3
    static let changeIntervals: ClosedRange<TimeInterval> = 120...300
    /// How often a dot ignores the mood and borrows any shape and colour.
    static let oddOneOutChance = 0.08
    static let brightChance = 0.25
    static let accentChance = 0.25

    /// The opening mood: blue and teal circles at normal pace.
    static let calm = Mood(palette: .ocean, shapes: [.circle], pace: 1)

    let palette: Palette
    let shapes: [DotShape]
    let pace: Double
    var motion = MotionStyle.drift
    var event: RareEvent?
    var isSpectrum = false

    var name: String { event?.title ?? palette.name }

    /// For example "Dusk · stars, hearts" or "Neon · fireflies · rings".
    var summary: String {
        let shapeNames = Set(shapes) == Set(DotShape.allCases)
            ? "all shapes"
            : shapes.map(\.pluralName).joined(separator: ", ")
        let motionName = motion == .drift ? [] : [motion.name]
        return ([name] + motionName + [shapeNames]).joined(separator: " · ")
    }

    static func random<R: RandomNumberGenerator>(after previous: Mood, using rng: inout R) -> Mood {
        let pool = Double.random(in: 0..<1, using: &rng) < brightChance ? Palette.bright : Palette.soft
        let choices = pool.filter { $0 != previous.palette }
        return Mood(
            palette: choices.randomElement(using: &rng) ?? previous.palette,
            shapes: randomShapes(using: &rng),
            pace: .random(in: paces, using: &rng)
        )
    }

    static func randomShapes<R: RandomNumberGenerator>(using rng: inout R) -> [DotShape] {
        let count = Int.random(in: shapeCounts, using: &rng)
        return Array(DotShape.allCases.shuffled(using: &rng).prefix(count))
    }

    /// `desktopFraction` is how far across the whole desktop the dot sits,
    /// which picks a spectrum mood's hue.
    func randomLook<R: RandomNumberGenerator>(
        oddOneOutChance: Double, desktopFraction: Double = 0, softness: Softness = .normal, using rng: inout R
    ) -> DotLook {
        if isSpectrum {
            return DotLook(shape: shapes.randomElement(using: &rng) ?? .circle,
                           color: hue(at: desktopFraction), softness: softness)
        }
        let isOddOneOut = Double.random(in: 0..<1, using: &rng) < oddOneOutChance
        let shapes = isOddOneOut ? DotShape.allCases : self.shapes
        let colors = isOddOneOut ? Palette.all.flatMap(\.colors) : palette.colors
        let index = colors.indices.randomElement(using: &rng)
        let color = index.map { colors[$0] } ?? RGB(red: 1, green: 1, blue: 1)
        let hasAccent = Double.random(in: 0..<1, using: &rng) < Self.accentChance
        return DotLook(
            shape: shapes.randomElement(using: &rng) ?? .circle,
            color: color,
            accent: hasAccent ? index.flatMap { Self.accent(after: $0, in: colors) } : nil,
            softness: softness
        )
    }

    /// Each colour's accent is fixed, which keeps the image cache small.
    private static func accent(after index: Int, in colors: [RGB]) -> RGB? {
        let next = colors[(index + 1) % colors.count]
        return next == colors[index] ? nil : next
    }

    private func hue(at fraction: Double) -> RGB {
        let colors = palette.colors
        guard !colors.isEmpty else { return RGB(red: 1, green: 1, blue: 1) }
        let index = Int(min(max(fraction, 0), 1) * Double(colors.count))
        return colors[min(index, colors.count - 1)]
    }
}

/// How dots move during a mood. Takes effect at each dot's next wrap.
enum MotionStyle: Equatable {
    case drift, fireflies, snow, shoal, confetti

    var name: String {
        switch self {
        case .drift: "drift"
        case .fireflies: "fireflies"
        case .snow: "snow"
        case .shoal: "shoal"
        case .confetti: "confetti"
        }
    }
}

/// Rare, collectable moments listed in the menu's Seen submenu.
enum RareEvent: String, CaseIterable {
    case shootingStar, lantern, spectrum, goldenHour, fullMoon, valentines, halloween, newYear, winterSolstice

    var title: String {
        switch self {
        case .shootingStar: "Shooting star"
        case .lantern: "Lantern"
        case .spectrum: "Spectrum"
        case .goldenHour: "Golden hour"
        case .fullMoon: "Full moon"
        case .valentines: "Valentine's Day"
        case .halloween: "Halloween"
        case .newYear: "New Year"
        case .winterSolstice: "Winter solstice"
        }
    }
}

/// What the app knows when choosing the next mood.
struct MoodContext {
    let date: Date
    let calendar: Calendar
    /// Seconds of continuous, unpaused use with recent user activity.
    let focusedFor: TimeInterval
    /// False once a spectrum mood has been shown today.
    let spectrumAvailable: Bool
    let reduceMotion: Bool
}

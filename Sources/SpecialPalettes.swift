/// Palettes kept out of the ordinary rotation: some belong to an hour of the
/// day, the rest to a rare event.
extension Palette {
    static let dawn = Palette(name: "Dawn", colors: [
        RGB(red: 0.99, green: 0.80, blue: 0.70), RGB(red: 0.98, green: 0.88, blue: 0.62),
        RGB(red: 0.97, green: 0.74, blue: 0.70), RGB(red: 1.00, green: 0.93, blue: 0.80),
    ])
    static let night = Palette(name: "Night", colors: [
        RGB(red: 0.45, green: 0.48, blue: 0.82), RGB(red: 0.80, green: 0.82, blue: 0.88),
        RGB(red: 0.56, green: 0.54, blue: 0.86), RGB(red: 0.90, green: 0.91, blue: 0.95),
    ])
    static let gold = Palette(name: "Gold", colors: [
        RGB(red: 1.00, green: 0.84, blue: 0.48), RGB(red: 0.98, green: 0.76, blue: 0.40),
        RGB(red: 1.00, green: 0.90, blue: 0.64),
    ])
    static let amber = Palette(name: "Amber", colors: [
        RGB(red: 1.00, green: 0.70, blue: 0.30), RGB(red: 0.96, green: 0.60, blue: 0.24),
        RGB(red: 1.00, green: 0.80, blue: 0.46),
    ])
    static let rose = Palette(name: "Rose", colors: [
        RGB(red: 0.98, green: 0.62, blue: 0.72), RGB(red: 0.95, green: 0.48, blue: 0.60),
        RGB(red: 1.00, green: 0.78, blue: 0.84),
    ])
    /// Seven soft rainbow hues, left to right across the desktop.
    static let spectrum = Palette(name: "Spectrum", colors: [
        RGB(red: 0.98, green: 0.62, blue: 0.62), RGB(red: 0.99, green: 0.76, blue: 0.56),
        RGB(red: 0.98, green: 0.92, blue: 0.60), RGB(red: 0.66, green: 0.90, blue: 0.64),
        RGB(red: 0.58, green: 0.82, blue: 0.96), RGB(red: 0.66, green: 0.66, blue: 0.96),
        RGB(red: 0.84, green: 0.66, blue: 0.94),
    ])

    /// Palettes that join the soft pool only during their hours.
    static func timed(atHour hour: Int) -> [Palette] {
        switch hour {
        case 5...8: [dawn]
        case 21...23, 0...4: [night]
        default: []
        }
    }
}

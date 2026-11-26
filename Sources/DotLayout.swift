import CoreGraphics

/// How far away a dot seems. A dot keeps its tier for life.
enum DepthTier: CaseIterable {
    case far, mid, near

    var diameters: ClosedRange<CGFloat> {
        switch self {
        case .far: 4...9
        case .mid: 9...20
        case .near: 28...44
        }
    }

    /// Multiplies the crossing time: distant dots seem to move slower.
    var crossingFactor: Double {
        switch self {
        case .far: 1.6
        case .mid: 1
        case .near: 0.7
        }
    }

    /// Near dots are big, so they stay faint enough not to distract.
    var alphas: ClosedRange<Float> {
        switch self {
        case .far: 0.25...0.5
        case .mid: 0.35...0.8
        case .near: 0.15...0.3
        }
    }

    var wobbleFactor: CGFloat {
        switch self {
        case .far: 0.5
        case .mid: 1
        case .near: 1.2
        }
    }

    var softness: Softness {
        switch self {
        case .far: .soft
        case .mid: .normal
        case .near: .verySoft
        }
    }

    var zPosition: CGFloat {
        switch self {
        case .far: -1
        case .mid: 0
        case .near: 1
        }
    }

    /// Halfway between two tiers, for a layer that passes in front of one
    /// tier's dots and behind the other's.
    static func zPosition(between back: DepthTier, and front: DepthTier) -> CGFloat {
        (back.zPosition + front.zPosition) / 2
    }

    /// About 55% far, 35% mid and 10% near. A golden-ratio sequence rather
    /// than a coin flip, so even 15 dots get a near one or two and never a crowd.
    static func forDot(index: Int) -> DepthTier {
        let golden = 0.618_033_988_749_895
        let position = (0.5 + Double(index) * golden).truncatingRemainder(dividingBy: 1)
        switch position {
        case ..<0.55: return .far
        case ..<0.90: return .mid
        default: return .near
        }
    }
}

/// What a dot keeps between passes: its tier, home direction, column, and
/// where its screen sits on the desktop.
struct PassSetup {
    /// How far a dot may stray from its column's centre, as a share of half the column.
    static let columnJitter: CGFloat = 0.7

    let tier: DepthTier
    let homeDirection: DotPass.Direction
    let column: Int
    let columns: Int
    /// Global desktop coordinates.
    let screenFrame: CGRect
    let desktop: CGRect

    var area: CGSize { screenFrame.size }

    func with(column newColumn: Int, of newColumns: Int) -> PassSetup {
        PassSetup(tier: tier, homeDirection: homeDirection, column: newColumn, columns: newColumns,
                  screenFrame: screenFrame, desktop: desktop)
    }

    func with(desktop newDesktop: CGRect) -> PassSetup {
        PassSetup(tier: tier, homeDirection: homeDirection, column: column, columns: columns,
                  screenFrame: screenFrame, desktop: newDesktop)
    }

    /// Dot i of n sits in a column of width ÷ n, so there are no clumps or empty bands.
    func randomX<R: RandomNumberGenerator>(using rng: inout R) -> CGFloat {
        let width = max(area.width, 0) / CGFloat(max(columns, 1))
        let centre = (CGFloat(min(max(column, 0), max(columns - 1, 0))) + 0.5) * width
        return centre + width / 2 * .random(in: -Self.columnJitter...Self.columnJitter, using: &rng)
    }

    /// How far across the whole desktop a screen x lies, from 0 to 1.
    func desktopFraction(ofX x: CGFloat) -> Double {
        guard !desktop.isNull, desktop.width > 0 else { return 0 }
        return Double((screenFrame.minX + x - desktop.minX) / desktop.width)
    }
}

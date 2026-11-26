import CoreGraphics

/// Visitor bitmaps, kept apart from `DotImages` so a mood change doesn't drop them.
enum VisitorImages {
    private static var cache: [VisitorKind: CGImage] = [:]

    static let shootingStarPixels = (width: 256, height: 32)
    static let lanternPixels = 96

    private static let starlight = RGB(red: 1.0, green: 0.97, blue: 0.9)
    private static let lanternCore = RGB(red: 1.0, green: 0.86, blue: 0.56)
    private static let lanternEdge = RGB(red: 1.0, green: 0.66, blue: 0.32)

    static func image(for kind: VisitorKind) -> CGImage? {
        if let cached = cache[kind] { return cached }
        let image = kind == .shootingStar ? renderShootingStar() : renderLantern()
        cache[kind] = image
        return image
    }

    /// A dim sparkle at the right end with a soft tail fading off to the left.
    private static func renderShootingStar() -> CGImage? {
        let (width, height) = shootingStarPixels
        return Bitmap.render(width: width, height: height) { context, space in
            let half = CGFloat(height) / 2
            let head = CGPoint(x: CGFloat(width) - half, y: half)
            let light = Bitmap.color(starlight)
            let colors = [light.copy(alpha: 0.55) ?? light, light.copy(alpha: 0) ?? light] as CFArray
            guard let fade = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }

            context.saveGState()
            context.clip(to: CGRect(x: 0, y: 0, width: head.x, height: CGFloat(height)))
            context.translateBy(x: head.x, y: head.y)
            context.scaleBy(x: 1, y: half * 0.45 / head.x)
            context.drawRadialGradient(fade, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: head.x, options: [])
            context.restoreGState()

            context.drawRadialGradient(fade, startCenter: head, startRadius: 0, endCenter: head, endRadius: half, options: [])
            context.setShadow(offset: .zero, blur: half * 0.5, color: light)
            context.setFillColor(light.copy(alpha: 0.85) ?? light)
            context.addPath(ShapePaths.path(for: .sparkle, in: CGRect(
                x: head.x - half * 0.6, y: head.y - half * 0.6, width: half * 1.2, height: half * 1.2)))
            context.fillPath()
        }
    }

    /// A warm glow, bright in the middle and fading to nothing at the edge.
    private static func renderLantern() -> CGImage? {
        let size = lanternPixels
        return Bitmap.render(width: size, height: size) { context, space in
            let colors = [
                Bitmap.color(lanternCore), Bitmap.color(lanternEdge, alpha: 0.5), Bitmap.color(lanternEdge, alpha: 0),
            ] as CFArray
            guard let glow = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.3, 1]) else { return }
            let center = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
            context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center,
                                       endRadius: CGFloat(size) / 2, options: [])
        }
    }
}

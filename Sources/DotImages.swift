import CoreGraphics

/// Soft-edged dot images, drawn on first use and shared by every layer with
/// the same look, so each look costs one small bitmap.
enum DotImages {
    private static var cache: [DotLook: CGImage] = [:]

    private struct Style {
        /// Bitmap size: just enough for the tier's largest dot on a Retina screen.
        let pixelSize: Int
        /// Glow radius as a share of the canvas.
        let glow: CGFloat
        let bodyAlpha: CGFloat
        /// Where a soft circle's solid core gives way to its fade.
        let coreStop: CGFloat
    }

    static func image(for look: DotLook) -> CGImage? {
        if let cached = cache[look] { return cached }
        let image = render(look)
        cache[look] = image
        return image
    }

    /// Called on each mood change so the cache holds roughly one mood's looks.
    /// Layers still showing an old image keep it alive until they wrap.
    static func removeAll() {
        cache.removeAll()
    }

    private static func style(for softness: Softness) -> Style {
        switch softness {
        case .soft: Style(pixelSize: 32, glow: 0.15, bodyAlpha: 0.8, coreStop: 0.35)
        case .normal: Style(pixelSize: 64, glow: 0.12, bodyAlpha: 0.85, coreStop: 0.45)
        case .verySoft: Style(pixelSize: 96, glow: 0.18, bodyAlpha: 0.7, coreStop: 0.2)
        }
    }

    private static func render(_ look: DotLook) -> CGImage? {
        let style = style(for: look.softness)
        return Bitmap.render(width: style.pixelSize, height: style.pixelSize) { context, space in
            let canvas = CGRect(x: 0, y: 0, width: style.pixelSize, height: style.pixelSize)
            let color = Bitmap.color(look.color)
            if look.shape == .circle {
                drawSoftCircle(color, style: style, in: context, canvas: canvas, space: space)
            } else {
                drawGlowingShape(look.shape, color, style: style, in: context, canvas: canvas)
            }
            if let accent = look.accent {
                washAccent(Bitmap.color(accent), over: color, in: context, canvas: canvas, space: space)
            }
        }
    }

    private static func drawSoftCircle(
        _ color: CGColor, style: Style, in context: CGContext, canvas: CGRect, space: CGColorSpace
    ) {
        let colors = [color, color.copy(alpha: style.bodyAlpha) ?? color, color.copy(alpha: 0) ?? color] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, style.coreStop, 1])
        else { return }
        let center = CGPoint(x: canvas.midX, y: canvas.midY)
        context.drawRadialGradient(
            gradient, startCenter: center, startRadius: 0,
            endCenter: center, endRadius: canvas.width / 2, options: [])
    }

    /// Other shapes get their soft edge from a same-coloured glow around a
    /// slightly translucent fill.
    private static func drawGlowingShape(
        _ shape: DotShape, _ color: CGColor, style: Style, in context: CGContext, canvas: CGRect
    ) {
        let glow = canvas.width * style.glow
        let bounds = canvas.insetBy(dx: glow * 1.4, dy: glow * 1.4)
        let body = color.copy(alpha: style.bodyAlpha) ?? color
        context.setShadow(offset: .zero, blur: glow, color: color)

        if let ratio = ShapePaths.strokeRatio(for: shape) {
            let lineWidth = bounds.width * ratio
            let outline = shape == .ring ? bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2) : bounds
            context.setStrokeColor(body)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.addPath(ShapePaths.path(for: shape, in: outline))
            context.strokePath()
        } else {
            context.setFillColor(body)
            context.addPath(ShapePaths.path(for: shape, in: bounds))
            context.fillPath()
        }
    }

    /// Recolours what is already drawn with a diagonal blend into the accent,
    /// keeping its alpha, so the glow stays soft.
    private static func washAccent(
        _ accent: CGColor, over color: CGColor, in context: CGContext, canvas: CGRect, space: CGColorSpace
    ) {
        guard let gradient = CGGradient(colorsSpace: space, colors: [color, accent] as CFArray, locations: [0.25, 0.75])
        else { return }
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setBlendMode(.sourceAtop)
        context.drawLinearGradient(
            gradient, start: CGPoint(x: canvas.minX, y: canvas.minY), end: CGPoint(x: canvas.maxX, y: canvas.maxY),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
}

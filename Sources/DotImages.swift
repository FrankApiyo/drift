import CoreGraphics

/// Soft-edged dot images, drawn on first use and shared by every layer with
/// the same look, so each shape and colour costs one small bitmap.
enum DotImages {
    private static var cache: [DotLook: CGImage] = [:]
    /// Big enough to stay smooth at the largest dot size on a Retina screen.
    private static let pixelSize = 64

    static func image(for look: DotLook) -> CGImage? {
        if let cached = cache[look] { return cached }
        let image = render(look)
        cache[look] = image
        return image
    }

    private static func render(_ look: DotLook) -> CGImage? {
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8,
                bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        let color = CGColor(srgbRed: look.color.red, green: look.color.green, blue: look.color.blue, alpha: 1)
        let canvas = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        if look.shape == .circle {
            drawSoftCircle(color, in: context, canvas: canvas, space: space)
        } else {
            drawGlowingShape(look.shape, color, in: context, canvas: canvas)
        }
        return context.makeImage()
    }

    private static func drawSoftCircle(_ color: CGColor, in context: CGContext, canvas: CGRect, space: CGColorSpace) {
        let colors = [color, color.copy(alpha: 0.85) ?? color, color.copy(alpha: 0) ?? color] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 1]) else { return }
        let center = CGPoint(x: canvas.midX, y: canvas.midY)
        context.drawRadialGradient(
            gradient, startCenter: center, startRadius: 0,
            endCenter: center, endRadius: canvas.width / 2, options: [])
    }

    /// Other shapes get their soft edge from a same-coloured glow around a
    /// slightly translucent fill.
    private static func drawGlowingShape(_ shape: DotShape, _ color: CGColor, in context: CGContext, canvas: CGRect) {
        let glow = canvas.width * 0.12
        let bounds = canvas.insetBy(dx: glow * 1.5, dy: glow * 1.5)
        let body = color.copy(alpha: 0.85) ?? color
        context.setShadow(offset: .zero, blur: glow, color: color)

        if shape == .ring {
            let lineWidth = bounds.width * 0.16
            context.setStrokeColor(body)
            context.setLineWidth(lineWidth)
            context.addPath(ShapePaths.path(for: .ring, in: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)))
            context.strokePath()
        } else {
            context.setFillColor(body)
            context.addPath(ShapePaths.path(for: shape, in: bounds))
            context.fillPath()
        }
    }
}

import CoreGraphics

/// Draws a small premultiplied sRGB bitmap once, for layers to share.
enum Bitmap {
    static func render(width: Int, height: Int, _ draw: (CGContext, CGColorSpace) -> Void) -> CGImage? {
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        draw(context, space)
        return context.makeImage()
    }

    static func color(_ rgb: RGB, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha)
    }
}

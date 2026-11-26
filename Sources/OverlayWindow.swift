import AppKit

/// A transparent, borderless, click-through window covering one screen.
final class OverlayWindow: NSWindow {
    let field: DotField

    /// Just above the wallpaper, below the desktop icons.
    private static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
    /// Dots over windows sit on top of your work, so they are drawn fainter.
    private static let overWindowsDimming: Float = 0.5

    init(screen: NSScreen, settings: Settings, mood: Mood) {
        let frame = screen.frame
        field = DotField(
            area: frame.size, scale: screen.backingScaleFactor,
            count: settings.count.dots, speedFactor: settings.speed.factor, mood: mood)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        // Clicks pass through, but a window on top still gets mouse-moved
        // events for cursor tracking. It never shows a cursor, so opt out.
        disableCursorRects()
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        // A layer-hosting view: AppKit never draws into it, so there is no
        // screen-sized backing bitmap, only the small dot layers.
        let rootLayer = CALayer()
        rootLayer.contentsScale = screen.backingScaleFactor
        let host = NSView(frame: NSRect(origin: .zero, size: frame.size))
        host.layer = rootLayer
        host.wantsLayer = true
        contentView = host
        field.attach(to: rootLayer)

        setFrame(frame, display: false)
        apply(layer: settings.layer, opacity: settings.opacity)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func apply(layer mode: LayerMode, opacity: DotOpacity) {
        level = mode == .behind ? Self.desktopLevel : .statusBar
        field.setOpacity(opacity.value * (mode == .over ? Self.overWindowsDimming : 1))
    }

    override func close() {
        field.tearDown()
        super.close()
    }
}

import AppKit

/// A transparent, borderless, click-through window covering one screen.
final class OverlayWindow: NSWindow {
    let field: DotField
    /// Called when the window comes into view or goes out of it, e.g. behind a full-screen app.
    var onVisibilityChange: (() -> Void)?
    private var occlusionObserver: NSObjectProtocol?
    private var hasReportedOcclusion = false

    /// Just above the wallpaper, below the desktop icons.
    private static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
    /// Dots over windows sit on top of your work, so they are drawn fainter.
    private static let overWindowsDimming: Float = 0.5
    private static let occlusionSettleDelay: TimeInterval = 1

    init(screen: NSScreen, settings: Settings, mood: Mood) {
        let frame = screen.frame
        field = DotField(
            screenFrame: frame, scale: screen.backingScaleFactor,
            count: settings.count.dots, speedFactor: settings.speed.factor, mood: mood,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
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
        // Not on full-screen spaces. Kept out of screen sharing and screenshots,
        // though some capture tools on macOS 15 and later still show it.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        sharingType = .none

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
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: self, queue: .main
        ) { [weak self] _ in self?.reportOcclusion() }
    }

    /// Counted as visible until its occlusion is reported, so a new window
    /// doesn't briefly read as hidden and dim the menu bar icon.
    var isOnScreen: Bool {
        !hasReportedOcclusion || occlusionState.contains(.visible)
    }

    /// A window that starts out hidden, e.g. over a full-screen app, may never
    /// get an occlusion change, so its state is read once the window server
    /// has had time to place it.
    func present() {
        orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.occlusionSettleDelay) { [weak self] in
            self?.reportOcclusion()
        }
    }

    private func reportOcclusion() {
        hasReportedOcclusion = true
        onVisibilityChange?()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func apply(layer mode: LayerMode, opacity: DotOpacity) {
        level = mode == .behind ? Self.desktopLevel : .statusBar
        field.setOpacity(opacity.value * (mode == .over ? Self.overWindowsDimming : 1))
    }

    override func close() {
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
        occlusionObserver = nil
        onVisibilityChange = nil
        field.tearDown()
        super.close()
    }
}

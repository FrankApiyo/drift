import AppKit

/// A one-time note under the menu bar icon on first launch. It doesn't
/// activate Drift, so whatever app is in front keeps the keyboard.
final class Welcome: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let onClose: () -> Void
    private var outsideClicks: Any?

    init(layer: LayerMode, launchAtLogin: LaunchAtLoginToggle, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = WelcomeViewController(layer: layer, launchAtLogin: launchAtLogin)
    }

    func show(below button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func close() {
        popover.performClose(nil)
    }

    func popoverDidShow(_ notification: Notification) {
        // A transient popover only notices outside clicks once its app is
        // active, which Drift isn't. Mouse monitors need no permission, but
        // they only see other apps' clicks.
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in self?.popover.performClose(nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
        // Released on the next turn of the run loop, not inside the popover's own callback.
        let onClose = onClose
        DispatchQueue.main.async { onClose() }
    }
}

/// Reads and flips the Launch at Login state for the welcome checkbox.
struct LaunchAtLoginToggle {
    let isEnabled: () -> Bool
    let toggle: () -> Void
}

private final class WelcomeViewController: NSViewController {
    private let layer: LayerMode
    private let launchAtLogin: LaunchAtLoginToggle
    private lazy var checkbox = FirstClickCheckbox(
        checkboxWithTitle: "Launch at Login", target: self, action: #selector(toggleLaunchAtLogin))

    init(layer: LayerMode, launchAtLogin: LaunchAtLoginToggle) {
        self.layer = layer
        self.launchAtLogin = launchAtLogin
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("WelcomeViewController is created in code only")
    }

    override func loadView() {
        let place = layer == .behind ? "behind" : "over"
        let lines = [
            NSTextField(labelWithString: "Drift lives here."),
            NSTextField(labelWithString: "Shapes float \(place) your windows."),
        ]
        lines[0].font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        checkbox.state = launchAtLogin.isEnabled() ? .on : .off

        let stack = NSStackView(views: lines + [checkbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(12, after: lines[1])
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        view = stack
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        checkbox.state = launchAtLogin.isEnabled() ? .on : .off
    }
}

/// Drift is never the active app, so the first click must reach the checkbox
/// rather than only bring the popover forward.
private final class FirstClickCheckbox: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

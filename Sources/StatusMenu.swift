import AppKit

protocol MenuController: AnyObject {
    var settings: Settings { get }
    var isUserPaused: Bool { get }
    var isAnimating: Bool { get }
    var hasPauseShortcut: Bool { get }
    var isLaunchAtLoginEnabled: Bool { get }
    var moodSummary: String { get }
    var sightings: Sightings { get }
    func togglePause()
    func newMood()
    func update(_ settings: Settings)
    func toggleLaunchAtLogin()
}

/// The menu bar icon and its menu. Items are rebuilt each time the menu opens,
/// so their checkmarks always match the current state.
final class StatusMenu: NSObject, NSMenuDelegate {
    /// Matches the hot key registered in HotKey.pauseToggle.
    private static let pauseKey = "d"
    private static let pauseModifiers: NSEvent.ModifierFlags = [.control, .option, .command]

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var controller: MenuController?

    init(controller: MenuController) {
        self.controller = controller
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        if let image = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "Drift") {
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "Drift"
        }
        show(pauseReason: nil)
    }

    var button: NSStatusBarButton? { statusItem.button }

    /// The hot key can fire while the menu is open, which would leave its Pause item stale.
    func closeMenu() {
        statusItem.menu?.cancelTracking()
    }

    func show(pauseReason: PauseReason?) {
        statusItem.button?.appearsDisabled = pauseReason != nil
        statusItem.button?.toolTip = RunState.tooltip(for: pauseReason)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let controller else { return }
        let settings = controller.settings
        let change = { [weak controller] (apply: (Settings) -> Settings) in
            guard let controller else { return }
            controller.update(apply(controller.settings))
        }

        menu.items = [
            InfoItem("Now: \(controller.moodSummary)", enabled: false),
            ActionItem("New Mood", enabled: controller.isAnimating) { controller.newMood() },
            ActionItem(
                controller.isUserPaused ? "Resume" : "Pause",
                key: controller.hasPauseShortcut ? Self.pauseKey : "", modifiers: Self.pauseModifiers
            ) { controller.togglePause() },
            .separator(),
            choices("Layer", current: settings.layer) { value in change { $0.with(\.layer, value) } },
            choices("Number of dots", current: settings.count) { value in change { $0.with(\.count, value) } },
            choices("Speed", current: settings.speed) { value in change { $0.with(\.speed, value) } },
            choices("Opacity", current: settings.opacity) { value in change { $0.with(\.opacity, value) } },
            .separator(),
            seen(controller.sightings),
            .separator(),
            ActionItem("Pause in Low Power Mode", checked: settings.pauseInLowPowerMode) {
                change { $0.with(\.pauseInLowPowerMode, !$0.pauseInLowPowerMode) }
            },
            ActionItem("Launch at Login", checked: controller.isLaunchAtLoginEnabled) {
                controller.toggleLaunchAtLogin()
            },
            .separator(),
            ActionItem("Quit Drift", key: "q") { NSApp.terminate(nil) },
        ]
    }

    private func choices<C: MenuChoice>(
        _ title: String, current: C, pick: @escaping (C) -> Void
    ) -> NSMenuItem {
        let submenu = NSMenu()
        submenu.items = C.allCases.map { choice in
            ActionItem(choice.title, checked: choice == current) { pick(choice) }
        }
        return InfoItem(title, submenu: submenu)
    }

    private func seen(_ sightings: Sightings) -> NSMenuItem {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.items = RareEvent.allCases.map { event in
            InfoItem(sightings.menuTitle(for: event), enabled: sightings.firstSeen(event) != nil)
        }
        return InfoItem("Seen", submenu: submenu)
    }
}

/// A menu item with no action: a label, or the parent of a submenu.
private final class InfoItem: NSMenuItem {
    init(_ title: String, enabled: Bool = true, submenu: NSMenu? = nil) {
        super.init(title: title, action: nil, keyEquivalent: "")
        isEnabled = enabled
        self.submenu = submenu
    }

    required init(coder: NSCoder) {
        fatalError("InfoItem is created in code only")
    }
}

/// A menu item that runs a closure when picked.
private final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(
        _ title: String, checked: Bool = false, enabled: Bool = true, key: String = "",
        modifiers: NSEvent.ModifierFlags = .command, handler: @escaping () -> Void
    ) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
        state = checked ? .on : .off
        isEnabled = enabled
        keyEquivalentModifierMask = modifiers
    }

    required init(coder: NSCoder) {
        fatalError("ActionItem is created in code only")
    }

    @objc private func fire() {
        handler()
    }
}

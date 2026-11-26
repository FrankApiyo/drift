import AppKit

protocol MenuController: AnyObject {
    var settings: Settings { get }
    var isUserPaused: Bool { get }
    var isLaunchAtLoginEnabled: Bool { get }
    func togglePause()
    func update(_ settings: Settings)
    func toggleLaunchAtLogin()
}

/// The menu bar icon and its menu. Items are rebuilt each time the menu opens,
/// so their checkmarks always match the current state.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var controller: MenuController?

    init(controller: MenuController) {
        self.controller = controller
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        if let image = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "Drift") {
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "Drift"
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let controller else { return }
        let settings = controller.settings
        let change = { [weak controller] (apply: (Settings) -> Settings) in
            guard let controller else { return }
            controller.update(apply(controller.settings))
        }

        menu.items = [
            ActionItem(controller.isUserPaused ? "Resume" : "Pause") { controller.togglePause() },
            .separator(),
            choices("Layer", current: settings.layer) { value in change { $0.with(\.layer, value) } },
            choices("Number of dots", current: settings.count) { value in change { $0.with(\.count, value) } },
            choices("Speed", current: settings.speed) { value in change { $0.with(\.speed, value) } },
            choices("Opacity", current: settings.opacity) { value in change { $0.with(\.opacity, value) } },
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
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }
}

/// A menu item that runs a closure when picked.
private final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, checked: Bool = false, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) {
        fatalError("ActionItem is created in code only")
    }

    @objc private func fire() {
        handler()
    }
}

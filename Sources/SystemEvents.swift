import AppKit

/// What the app does when the system around it changes.
struct SystemEventHandlers {
    let pause: (SystemPause, Bool) -> Void
    let powerStateChanged: () -> Void
    let screensChanged: () -> Void
    let woke: () -> Void
    let reduceMotionChanged: () -> Void
}

/// Watches sleep, lock, user switching, power, screens and accessibility
/// settings, all through notifications, so nothing polls.
final class SystemEvents: NSObject {
    private let handlers: SystemEventHandlers
    private var workspaceObservers: [NSObjectProtocol] = []
    private var defaultObservers: [NSObjectProtocol] = []

    init(handlers: SystemEventHandlers) {
        self.handlers = handlers
        super.init()
        observeWorkspace()
        observeProcess()
        observeLock()
    }

    deinit {
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        defaultObservers.forEach(NotificationCenter.default.removeObserver)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func observeWorkspace() {
        let workspace = NSWorkspace.shared.notificationCenter
        let pauses: [(Notification.Name, SystemPause, Bool)] = [
            (NSWorkspace.screensDidSleepNotification, .displaysAsleep, true),
            (NSWorkspace.screensDidWakeNotification, .displaysAsleep, false),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionInactive, true),
            (NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive, false),
        ]
        let pause = handlers.pause
        let pauseObservers = pauses.map { name, reason, active in
            workspace.addObserver(forName: name, object: nil, queue: .main) { _ in pause(reason, active) }
        }
        let woke = handlers.woke
        let reduceMotionChanged = handlers.reduceMotionChanged
        workspaceObservers = pauseObservers + [
            workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                woke()
            },
            workspace.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
            ) { _ in reduceMotionChanged() },
        ]
    }

    private func observeProcess() {
        let center = NotificationCenter.default
        let powerStateChanged = handlers.powerStateChanged
        let screensChanged = handlers.screensChanged
        defaultObservers = [
            center.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in
                powerStateChanged()
            },
            center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { _ in screensChanged() },
        ]
    }

    private func observeLock() {
        // Distributed notifications are held back while an app is inactive,
        // which Drift nearly always is, unless delivery is immediate.
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(
            self, selector: #selector(screenLocked), name: .init("com.apple.screenIsLocked"),
            object: nil, suspensionBehavior: .deliverImmediately)
        distributed.addObserver(
            self, selector: #selector(screenUnlocked), name: .init("com.apple.screenIsUnlocked"),
            object: nil, suspensionBehavior: .deliverImmediately)
    }

    @objc private func screenLocked() {
        handlers.pause(.screenLocked, true)
    }

    @objc private func screenUnlocked() {
        handlers.pause(.screenLocked, false)
    }
}

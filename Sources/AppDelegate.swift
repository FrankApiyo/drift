import AppKit

/// Owns one overlay window per screen, decides when the dots should move, and
/// changes the mood every few minutes.
final class AppDelegate: NSObject, NSApplicationDelegate, MenuController {
    private(set) var settings = Settings.load()
    private(set) var isUserPaused = false

    private enum SystemPause { case displaysAsleep, sessionInactive, screenLocked }

    private var systemPauses: Set<SystemPause> = []
    private var mood = Mood.calm
    private var moodTimer: Timer?
    private var windows: [OverlayWindow] = []
    private var statusMenu: StatusMenu?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu = StatusMenu(controller: self)
        rebuildWindows()
        observeSystemEvents()
        scheduleMoodChange()
    }

    // MARK: - MenuController

    var isLaunchAtLoginEnabled: Bool { LoginItem.isEnabled }

    func togglePause() {
        isUserPaused.toggle()
        updateRunning()
    }

    func update(_ newSettings: Settings) {
        let old = settings
        settings = newSettings
        newSettings.save()

        if newSettings.layer != old.layer || newSettings.opacity != old.opacity {
            windows.forEach { $0.apply(layer: newSettings.layer, opacity: newSettings.opacity) }
        }
        if newSettings.count != old.count {
            windows.forEach { $0.field.setCount(newSettings.count.dots) }
        }
        if newSettings.speed != old.speed {
            windows.forEach { $0.field.setSpeedFactor(newSettings.speed.factor) }
        }
        if newSettings.pauseInLowPowerMode != old.pauseInLowPowerMode {
            updateRunning()
        }
    }

    func toggleLaunchAtLogin() {
        do {
            try LoginItem.toggle()
        } catch {
            showLoginItemError(error)
        }
    }

    // MARK: - Running state

    private var shouldAnimate: Bool {
        let lowPowerPause = settings.pauseInLowPowerMode && ProcessInfo.processInfo.isLowPowerModeEnabled
        return !isUserPaused && systemPauses.isEmpty && !lowPowerPause
    }

    private func updateRunning() {
        let running = shouldAnimate
        windows.forEach { $0.field.setRunning(running) }
    }

    private func setSystemPause(_ reason: SystemPause, active: Bool) {
        if active {
            systemPauses.insert(reason)
        } else {
            systemPauses.remove(reason)
        }
        updateRunning()
    }

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { OverlayWindow(screen: $0, settings: settings, mood: mood) }
        windows.forEach { $0.orderFrontRegardless() }
        updateRunning()
    }

    // MARK: - Moods

    /// A single one-shot timer minutes apart; the generous tolerance lets
    /// macOS fold the wake-up into other work.
    private func scheduleMoodChange() {
        let timer = Timer(timeInterval: .random(in: Mood.changeIntervals), repeats: false) { [weak self] _ in
            self?.changeMood()
        }
        timer.tolerance = 30
        RunLoop.main.add(timer, forMode: .common)
        moodTimer = timer
    }

    private func changeMood() {
        // While paused nobody is watching, so save the surprise.
        if shouldAnimate {
            var rng = SystemRandomNumberGenerator()
            mood = Mood.random(after: mood, using: &rng)
            windows.forEach { $0.field.setMood(mood) }
        }
        scheduleMoodChange()
    }

    // MARK: - System events

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        let pauses: [(Notification.Name, SystemPause, Bool)] = [
            (NSWorkspace.screensDidSleepNotification, .displaysAsleep, true),
            (NSWorkspace.screensDidWakeNotification, .displaysAsleep, false),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionInactive, true),
            (NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive, false),
        ]
        let pauseObservers = pauses.map { name, reason, active in
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.setSystemPause(reason, active: active)
            }
        }
        let center = NotificationCenter.default
        observers = pauseObservers + [
            center.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) {
                [weak self] _ in self?.updateRunning()
            },
            center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.rebuildWindows() },
        ]

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
        setSystemPause(.screenLocked, active: true)
    }

    @objc private func screenUnlocked() {
        setSystemPause(.screenLocked, active: false)
    }

    private func showLoginItemError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn't change Launch at Login"
        alert.informativeText = error.localizedDescription
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        alert.runModal()
    }
}

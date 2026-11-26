import AppKit

/// Owns one overlay window per screen and decides when the dots should move.
final class AppDelegate: NSObject, NSApplicationDelegate, MenuController {
    private static let launchFade: TimeInterval = 3
    private static let pauseFade: TimeInterval = 1.5

    private(set) var settings = Settings.load()
    private(set) var isUserPaused = false

    private var systemPauses: Set<SystemPause> = []
    private var windows: [OverlayWindow] = []
    private var statusMenu: StatusMenu?
    private var systemEvents: SystemEvents?
    private var hotKey: HotKey?
    private var welcome: Welcome?
    /// Set while a pause fades the dots out; they keep moving until it ends.
    private var pauseFadeTimer: Timer?
    private lazy var moods = MoodDirector(
        isVisiblyAnimating: { [unowned self] in runState.isVisiblyAnimating },
        windows: { [unowned self] in windows })

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu = StatusMenu(controller: self)
        rebuildWindows()
        systemEvents = SystemEvents(handlers: systemEventHandlers())
        hotKey = HotKey.pauseToggle { [weak self] in
            self?.statusMenu?.closeMenu()
            self?.togglePause()
        }
        moods.start()
        if !settings.hasWelcomed {
            showWelcomeSoon()
        }
    }

    // MARK: - MenuController

    var isLaunchAtLoginEnabled: Bool { LoginItem.isEnabled }
    var isVisiblyAnimating: Bool { runState.isVisiblyAnimating }
    var hasPauseShortcut: Bool { hotKey != nil }
    var moodSummary: String { moods.mood.summary }
    var sightings: Sightings { moods.sightings }

    func togglePause() {
        isUserPaused.toggle()
        pauseFadeTimer?.invalidate()
        pauseFadeTimer = isUserPaused ? oneShot(after: Self.pauseFade) { [weak self] in self?.pauseFadeEnded() } : nil
        windows.forEach { $0.field.fade(toVisible: !isUserPaused, duration: Self.pauseFade) }
        updateRunning()
    }

    func newMood() {
        moods.changeNow()
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

    private var runState: RunState {
        RunState(
            isUserPaused: isUserPaused,
            isFadingOut: pauseFadeTimer != nil,
            systemPauses: systemPauses,
            lowPowerPause: settings.pauseInLowPowerMode && ProcessInfo.processInfo.isLowPowerModeEnabled,
            anyWindowVisible: windows.contains(where: \.isOnScreen))
    }

    /// Each screen moves only while it is in view; system pauses stop motion at once.
    private func updateRunning() {
        let state = runState
        windows.forEach { $0.field.setRunning(state.motionAllowed && $0.isOnScreen) }
        // Working in a full-screen app still counts as focus, so visibility is left out.
        moods.unpausedChanged(state.isUnpaused)
        statusMenu?.show(pauseReason: state.pauseReason)
    }

    private func pauseFadeEnded() {
        pauseFadeTimer = nil
        updateRunning()
    }

    private func setSystemPause(_ reason: SystemPause, active: Bool) {
        systemPauses = active ? systemPauses.union([reason]) : systemPauses.subtracting([reason])
        updateRunning()
    }

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { OverlayWindow(screen: $0, settings: settings, mood: moods.mood) }
        windows.forEach { window in
            window.onVisibilityChange = { [weak self] in self?.updateRunning() }
            window.field.fade(toVisible: false, duration: 0)
            if !isUserPaused {
                window.field.fade(toVisible: true, duration: Self.launchFade)
            }
            window.present()
        }
        updateRunning()
    }

    private func systemEventHandlers() -> SystemEventHandlers {
        SystemEventHandlers(
            pause: { [weak self] reason, active in self?.setSystemPause(reason, active: active) },
            powerStateChanged: { [weak self] in self?.updateRunning() },
            screensChanged: { [weak self] in self?.rebuildWindows() },
            woke: { [weak self] in self?.moods.woke() },
            reduceMotionChanged: { [weak self] in self?.applyReduceMotion() })
    }

    private func applyReduceMotion() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        windows.forEach { $0.field.setReduceMotion(reduceMotion) }
    }

    // MARK: - Welcome and errors

    /// Waits a moment so the status item has its place in the menu bar.
    private func showWelcomeSoon() {
        _ = oneShot(after: 1) { [weak self] in self?.showWelcome() }
    }

    private func showWelcome() {
        // An icon hidden by the notch or a menu bar manager waits for a later launch.
        guard welcome == nil, let button = statusMenu?.button,
            button.window?.occlusionState.contains(.visible) == true
        else { return }
        let toggle = LaunchAtLoginToggle(
            isEnabled: { LoginItem.isEnabled },
            toggle: { [weak self] in self?.toggleLaunchAtLogin() })
        let welcome = Welcome(layer: settings.layer, launchAtLogin: toggle) { [weak self] in self?.welcome = nil }
        welcome.show(below: button)
        self.welcome = welcome
        update(settings.with(\.hasWelcomed, true))
    }

    private func oneShot(after interval: TimeInterval, _ action: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: false) { _ in action() }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        return timer
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

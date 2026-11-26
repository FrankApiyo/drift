/// Something outside Drift that stops the dots on every screen.
enum SystemPause: Hashable {
    case displaysAsleep, sessionInactive, screenLocked
}

/// Why the dots aren't moving, in the order the icon reports them.
enum PauseReason: Equatable {
    case user, screenLocked, sessionInactive, displaysAsleep, lowPowerMode, outOfSight

    var label: String? {
        switch self {
        case .user: nil
        case .screenLocked: "screen locked"
        case .sessionInactive: "another user is active"
        case .displaysAsleep: "displays asleep"
        case .lowPowerMode: "Low Power Mode"
        case .outOfSight: "out of sight"
        }
    }
}

/// Whether the dots should move, and if not, why.
struct RunState: Equatable {
    let isUserPaused: Bool
    /// A user pause fades the dots out before they stop.
    let isFadingOut: Bool
    let systemPauses: Set<SystemPause>
    /// Low Power Mode is on and the setting to pause for it is too.
    let lowPowerPause: Bool
    let anyWindowVisible: Bool

    init(
        isUserPaused: Bool, isFadingOut: Bool = false, systemPauses: Set<SystemPause>,
        lowPowerPause: Bool, anyWindowVisible: Bool
    ) {
        self.isUserPaused = isUserPaused
        self.isFadingOut = isFadingOut
        self.systemPauses = systemPauses
        self.lowPowerPause = lowPowerPause
        self.anyWindowVisible = anyWindowVisible
    }

    /// Neither the user nor the system has paused Drift, though every screen
    /// may still be out of sight.
    var isUnpaused: Bool {
        !isUserPaused && systemAllowsMotion
    }

    var systemAllowsMotion: Bool {
        systemPauses.isEmpty && !lowPowerPause
    }

    /// Whether dots on a screen that is in view may move.
    var motionAllowed: Bool {
        systemAllowsMotion && (!isUserPaused || isFadingOut)
    }

    var pauseReason: PauseReason? {
        if isUserPaused { return .user }
        if systemPauses.contains(.screenLocked) { return .screenLocked }
        if systemPauses.contains(.sessionInactive) { return .sessionInactive }
        if systemPauses.contains(.displaysAsleep) { return .displaysAsleep }
        if lowPowerPause { return .lowPowerMode }
        if !anyWindowVisible { return .outOfSight }
        return nil
    }

    /// Unpaused, with at least one screen in view.
    var isVisiblyAnimating: Bool {
        pauseReason == nil
    }

    static func tooltip(for reason: PauseReason?) -> String {
        guard let reason else { return "Drift" }
        guard let label = reason.label else { return "Drift — paused" }
        return "Drift — paused (\(label))"
    }
}

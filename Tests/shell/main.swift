// Plain assertions for the app's pure logic around the dots. Listed sources come from sources.txt.
import AppKit
import Carbon.HIToolbox

var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    guard !condition else { return }
    failures += 1
    print("FAIL (line \(line)): \(message)")
}

let scratchSuite = "drift.checks.shell"

func freshDefaults() -> UserDefaults {
    let defaults = UserDefaults(suiteName: scratchSuite)!
    defaults.removePersistentDomain(forName: scratchSuite)
    return defaults
}

var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(identifier: "UTC")!

func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

// MARK: - Settings

do {
    check(Settings.load(from: freshDefaults()) == Settings(), "empty defaults load the defaults")
    check(!Settings().hasWelcomed, "a fresh install hasn't been welcomed")

    let defaults = freshDefaults()
    let fallback = Settings()
    let changed = Settings(
        layer: .over, count: .many, speed: .faster, opacity: .visible,
        pauseInLowPowerMode: false, hasWelcomed: true)
    check(
        changed.layer != fallback.layer && changed.count != fallback.count && changed.speed != fallback.speed
            && changed.opacity != fallback.opacity && changed.pauseInLowPowerMode != fallback.pauseInLowPowerMode
            && changed.hasWelcomed != fallback.hasWelcomed,
        "the saved settings differ from the defaults in every field")
    changed.save(to: defaults)
    check(Settings.load(from: defaults) == changed, "all settings survive a save and load")
}

// MARK: - Sightings

do {
    let first = day(2026, 11, 26)
    let later = day(2026, 12, 3)
    let empty = Sightings()
    check(empty.firstSeen(.fullMoon) == nil, "nothing is seen at first")

    let once = empty.recording(.fullMoon, at: first)
    check(empty.firstSeen(.fullMoon) == nil, "recording returns a copy")
    check(once.firstSeen(.fullMoon) == first, "a sighting stores its date")

    let twice = once.recording(.fullMoon, at: later)
    check(twice.firstSeen(.fullMoon) == first, "a second sighting keeps the first date")
    check(twice == once, "a repeat sighting changes nothing")

    let both = twice.recording(.lantern, at: later)
    check(both.firstSeen(.lantern) == later, "another event records its own date")
    check(both.firstSeen(.fullMoon) == first, "other events keep their dates")

    let defaults = freshDefaults()
    check(Sightings.load(from: defaults) == Sightings(), "empty defaults load no sightings")
    both.save(to: defaults)
    check(Sightings.load(from: defaults) == both, "sightings survive a save and load")

    defaults.set(["notAnEvent": first, RareEvent.halloween.rawValue: "not a date"], forKey: "sightings")
    check(Sightings.load(from: defaults) == Sightings(), "unknown or malformed entries are ignored")

    let locale = Locale(identifier: "en_US")
    check(
        both.menuTitle(for: .fullMoon, locale: locale, timeZone: utc.timeZone) == "\(RareEvent.fullMoon.title) — Nov 26",
        "a seen event shows its title and short date")
    check(both.menuTitle(for: .halloween, locale: locale, timeZone: utc.timeZone) == "???", "an unseen event is hidden")

    check(VisitorKind.shootingStar.rareEvent == .shootingStar, "a shooting star is a rare event")
    check(VisitorKind.lantern.rareEvent == .lantern, "a lantern is a rare event")
}

// MARK: - FocusClock

do {
    let start = day(2026, 11, 26, hour: 9)
    let stopped = FocusClock()
    check(stopped.elapsed(at: start) == 0, "a stopped clock reads zero")

    let running = stopped.running(true, at: start)
    check(running.elapsed(at: start.addingTimeInterval(600)) == 600, "a running clock counts")
    check(running.running(true, at: start.addingTimeInterval(300)) == running, "staying running keeps the start")
    check(running.elapsed(at: start.addingTimeInterval(-5)) == 0, "a clock never reads negative")

    let paused = running.running(false, at: start.addingTimeInterval(600))
    check(paused.elapsed(at: start.addingTimeInterval(900)) == 0, "a pause resets the clock")
    let resumed = paused.running(true, at: start.addingTimeInterval(900))
    check(resumed.elapsed(at: start.addingTimeInterval(960)) == 60, "resuming counts from zero")

    let woke = running.restarted(at: start.addingTimeInterval(1200))
    check(woke.elapsed(at: start.addingTimeInterval(1260)) == 60, "a wake restarts a running clock")
    check(stopped.restarted(at: start) == stopped, "a restart leaves a stopped clock stopped")

    let check1 = start.addingTimeInterval(1800)
    let active = running.checkingActivity(idleFor: FocusClock.idleLimit - 1, at: check1)
    check(active.elapsed(at: check1) == 1800, "recent activity keeps counting")
    let idle = running.checkingActivity(idleFor: FocusClock.idleLimit, at: check1)
    check(idle.elapsed(at: check1) == 0, "five idle minutes reset the clock")
    check(idle.elapsed(at: check1.addingTimeInterval(30)) == 30, "the clock counts again after idling")

    let golden = running.afterMood(event: .goldenHour, at: check1)
    check(golden.elapsed(at: check1) == 0, "golden hour resets the clock")
    let other = running.afterMood(event: .fullMoon, at: check1)
    check(other.elapsed(at: check1) == 1800, "other events don't reset the clock")
    check(running.afterMood(event: nil, at: check1) == running, "ordinary moods don't reset the clock")
}

// MARK: - SpectrumDay

do {
    let morning = day(2026, 11, 26, hour: 8)
    let night = day(2026, 11, 26, hour: 23)
    let tomorrow = day(2026, 11, 27, hour: 0)
    let never = SpectrumDay()
    check(never.isAvailable(on: morning, calendar: utc), "a spectrum is available before any is shown")

    let shown = never.recording(morning)
    check(never.isAvailable(on: morning, calendar: utc), "recording returns a copy")
    check(!shown.isAvailable(on: night, calendar: utc), "only one spectrum a day")
    check(shown.isAvailable(on: tomorrow, calendar: utc), "a new day brings a new spectrum")

    let defaults = freshDefaults()
    check(SpectrumDay.load(from: defaults) == never, "empty defaults load no spectrum day")
    shown.save(to: defaults)
    check(SpectrumDay.load(from: defaults) == shown, "the spectrum day survives a save and load")
}

// MARK: - RunState

do {
    let clear = RunState(isUserPaused: false, systemPauses: [], lowPowerPause: false, anyWindowVisible: true)
    check(clear.isUnpaused && clear.isVisiblyAnimating, "nothing paused means animating")
    check(clear.pauseReason == nil, "nothing paused has no pause reason")
    check(RunState.tooltip(for: nil) == "Drift", "an animating icon is plainly named")

    let locked = RunState(isUserPaused: false, systemPauses: [.screenLocked, .displaysAsleep], lowPowerPause: false, anyWindowVisible: true)
    let user = RunState(isUserPaused: true, systemPauses: [.screenLocked], lowPowerPause: true, anyWindowVisible: false)
    check(!user.isUnpaused && !user.isVisiblyAnimating, "a user pause stops animation")
    check(user.pauseReason == .user, "a user pause names itself first")
    let userOnly = RunState(isUserPaused: true, systemPauses: [], lowPowerPause: false, anyWindowVisible: true)
    check(userOnly.systemAllowsMotion, "a user pause alone leaves the system allowing motion")
    check(!locked.isUnpaused, "a system pause counts as paused")

    let fading = RunState(isUserPaused: true, isFadingOut: true, systemPauses: [], lowPowerPause: false, anyWindowVisible: true)
    check(fading.motionAllowed, "dots keep moving while a pause fades them out")
    check(fading.pauseReason == .user, "a fading pause already reports as paused")
    check(!userOnly.motionAllowed, "dots stop once the pause fade ends")
    let fadingWhileLocked = RunState(isUserPaused: true, isFadingOut: true, systemPauses: [.screenLocked], lowPowerPause: false, anyWindowVisible: true)
    check(fadingWhileLocked.isFadingOut && !fadingWhileLocked.motionAllowed, "a system pause stops motion even while fading out")
    let fadingInLowPower = RunState(isUserPaused: true, isFadingOut: true, systemPauses: [], lowPowerPause: true, anyWindowVisible: true)
    check(fadingInLowPower.isFadingOut && !fadingInLowPower.motionAllowed, "low power stops motion even while fading out")
    check(clear.motionAllowed, "unpaused dots move")
    check(!locked.motionAllowed, "a system pause stops dots at once")
    check(RunState.tooltip(for: .user) == "Drift — paused", "a user pause has a plain tooltip")

    let lowPower = RunState(isUserPaused: false, systemPauses: [], lowPowerPause: true, anyWindowVisible: true)
    check(lowPower.pauseReason == .lowPowerMode, "low power pauses")
    check(RunState.tooltip(for: .lowPowerMode) == "Drift — paused (Low Power Mode)", "low power tooltip")

    check(locked.pauseReason == .screenLocked, "a locked screen outranks sleeping displays")
    check(RunState.tooltip(for: .screenLocked) == "Drift — paused (screen locked)", "locked screen tooltip")

    let otherUser = RunState(isUserPaused: false, systemPauses: [.sessionInactive, .displaysAsleep], lowPowerPause: false, anyWindowVisible: true)
    check(otherUser.pauseReason == .sessionInactive, "another user being active outranks sleeping displays")
    let lockedAndAway = RunState(isUserPaused: false, systemPauses: [.screenLocked, .sessionInactive], lowPowerPause: false, anyWindowVisible: true)
    check(lockedAndAway.pauseReason == .screenLocked, "a locked screen outranks another user being active")
    check(RunState.tooltip(for: .sessionInactive) == "Drift — paused (another user is active)", "another user tooltip")

    let asleep = RunState(isUserPaused: false, systemPauses: [.displaysAsleep], lowPowerPause: true, anyWindowVisible: true)
    check(asleep.pauseReason == .displaysAsleep, "sleeping displays outrank Low Power Mode")
    check(RunState.tooltip(for: .displaysAsleep) == "Drift — paused (displays asleep)", "sleeping displays tooltip")

    let lowPowerHidden = RunState(isUserPaused: false, systemPauses: [], lowPowerPause: true, anyWindowVisible: false)
    check(lowPowerHidden.pauseReason == .lowPowerMode, "Low Power Mode outranks being out of sight")

    let hidden = RunState(isUserPaused: false, systemPauses: [], lowPowerPause: false, anyWindowVisible: false)
    check(hidden.isUnpaused, "being out of sight isn't a system-wide pause")
    check(!hidden.isVisiblyAnimating, "being out of sight stops visible animation")
    check(hidden.pauseReason == .outOfSight, "being out of sight still counts as paused")
    check(RunState.tooltip(for: .outOfSight) == "Drift — paused (out of sight)", "out of sight tooltip")
}

// MARK: - Shortcut

do {
    let pause = Shortcut.pauseToggle
    check(pause.modifiers == [.control, .option, .command], "the pause shortcut is control-option-command")
    check(
        pause.keyEquivalent == "d" && pause.keyCode == kVK_ANSI_D,
        "the hot key registers the same key the menu shows")
    check(
        pause.carbonModifiers == UInt32(controlKey | optionKey | cmdKey),
        "the hot key registers the same modifiers the menu shows")
    check(
        Shortcut(keyCode: 0, keyEquivalent: "a", modifiers: [.shift]).carbonModifiers == UInt32(shiftKey),
        "shift maps to its Carbon modifier")
}

UserDefaults(suiteName: scratchSuite)?.removePersistentDomain(forName: scratchSuite)

print(failures == 0 ? "All shell checks passed" : "\(failures) shell check(s) failed")
exit(failures == 0 ? 0 : 1)

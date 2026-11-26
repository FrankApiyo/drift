import AppKit
import Carbon.HIToolbox

/// A key combination, defined once for both the Carbon hot key and the
/// key equivalent a menu item shows.
struct Shortcut {
    let keyCode: Int
    let keyEquivalent: String
    let modifiers: NSEvent.ModifierFlags

    static let pauseToggle = Shortcut(keyCode: kVK_ANSI_D, keyEquivalent: "d", modifiers: [.control, .option, .command])

    private static let carbonEquivalents: [(NSEvent.ModifierFlags, Int)] = [
        (.control, controlKey), (.option, optionKey), (.command, cmdKey), (.shift, shiftKey),
    ]

    var carbonModifiers: UInt32 {
        UInt32(Self.carbonEquivalents.filter { modifiers.contains($0.0) }.reduce(0) { $0 | $1.1 })
    }
}

/// A system-wide keyboard shortcut. Carbon hot keys need no Accessibility or
/// Input Monitoring permission, unlike global event monitors.
final class HotKey {
    private static let signature: OSType = 0x4452_4654  // "DRFT"

    private let action: () -> Void
    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    static func pauseToggle(action: @escaping () -> Void) -> HotKey? {
        HotKey(.pauseToggle, id: 1, action: action)
    }

    init?(_ shortcut: Shortcut, id: UInt32, action: @escaping () -> Void) {
        self.action = action
        self.id = id
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(
            GetApplicationEventTarget(), Self.handle, 1, &pressed,
            Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let registered = RegisterEventHotKey(
            UInt32(shortcut.keyCode), shortcut.carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard installed == noErr, registered == noErr else {
            unregister()
            return nil
        }
    }

    deinit {
        unregister()
    }

    private func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }

    private static let handle: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }
        var pressedID = EventHotKeyID()
        let status = GetEventParameter(
            event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
            nil, MemoryLayout<EventHotKeyID>.size, nil, &pressedID)
        let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
        guard status == noErr, pressedID.signature == signature, pressedID.id == hotKey.id else {
            return OSStatus(eventNotHandledErr)
        }
        hotKey.action()
        return noErr
    }
}

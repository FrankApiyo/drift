import Foundation

/// A setting the menu shows as a submenu of checkable choices.
protocol MenuChoice: CaseIterable, Equatable, RawRepresentable where RawValue == String {
    var title: String { get }
}

enum LayerMode: String, MenuChoice {
    case behind, over
    var title: String { self == .behind ? "Behind windows" : "Over windows" }
}

enum DotCount: String, MenuChoice {
    case few, some, many
    var title: String { rawValue.capitalized }
    var dots: Int {
        switch self {
        case .few: 15
        case .some: 25
        case .many: 40
        }
    }
}

enum DriftSpeed: String, MenuChoice {
    case slower, normal, faster
    var title: String { rawValue.capitalized }
    var factor: Double {
        switch self {
        case .slower: 0.6
        case .normal: 1
        case .faster: 1.6
        }
    }
}

enum DotOpacity: String, MenuChoice {
    case subtle, medium, visible
    var title: String { rawValue.capitalized }
    var value: Float {
        switch self {
        case .subtle: 0.35
        case .medium: 0.6
        case .visible: 0.9
        }
    }
}

/// User preferences, stored in UserDefaults. Pause is deliberately not stored:
/// Drift always starts moving.
struct Settings: Equatable {
    var layer = LayerMode.behind
    var count = DotCount.some
    var speed = DriftSpeed.normal
    var opacity = DotOpacity.medium
    var pauseInLowPowerMode = true

    func with<Value>(_ key: WritableKeyPath<Settings, Value>, _ value: Value) -> Settings {
        var copy = self
        copy[keyPath: key] = value
        return copy
    }

    static func load(from defaults: UserDefaults = .standard) -> Settings {
        let fallback = Settings()
        return Settings(
            layer: choice(Key.layer, in: defaults) ?? fallback.layer,
            count: choice(Key.count, in: defaults) ?? fallback.count,
            speed: choice(Key.speed, in: defaults) ?? fallback.speed,
            opacity: choice(Key.opacity, in: defaults) ?? fallback.opacity,
            pauseInLowPowerMode: defaults.object(forKey: Key.lowPower) as? Bool ?? fallback.pauseInLowPowerMode
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(layer.rawValue, forKey: Key.layer)
        defaults.set(count.rawValue, forKey: Key.count)
        defaults.set(speed.rawValue, forKey: Key.speed)
        defaults.set(opacity.rawValue, forKey: Key.opacity)
        defaults.set(pauseInLowPowerMode, forKey: Key.lowPower)
    }

    private static func choice<C: MenuChoice>(_ key: String, in defaults: UserDefaults) -> C? {
        defaults.string(forKey: key).flatMap(C.init(rawValue:))
    }

    private enum Key {
        static let layer = "layer"
        static let count = "dotCount"
        static let speed = "speed"
        static let opacity = "opacity"
        static let lowPower = "pauseInLowPowerMode"
    }
}

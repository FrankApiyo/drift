import Foundation

/// The moon's age from a mean synodic month, accurate to about a day, which
/// is close enough to call an evening's moon full.
enum MoonPhase {
    static let synodicMonth = 29.530588853
    /// 2000-01-06 18:14 UTC.
    static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)
    static let fullAge = synodicMonth / 2
    static let fullWindow = 1.5
    static let eveningHours = 18...23

    /// Days since the last new moon.
    static func age(at date: Date) -> Double {
        let days = date.timeIntervalSince(referenceNewMoon) / 86400
        let age = days.truncatingRemainder(dividingBy: synodicMonth)
        return age < 0 ? age + synodicMonth : age
    }

    static func isFull(at date: Date) -> Bool {
        abs(age(at: date) - fullAge) <= fullWindow
    }

    static func isFullMoonEvening(_ date: Date, calendar: Calendar) -> Bool {
        eveningHours.contains(calendar.component(.hour, from: date)) && isFull(at: date)
    }
}

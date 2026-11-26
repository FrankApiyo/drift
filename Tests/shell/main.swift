// Plain assertions for the app shell's pure logic. Listed sources come from sources.txt.
import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    guard !condition else { return }
    failures += 1
    print("FAIL (line \(line)): \(message)")
}

check(Settings.load(from: UserDefaults(suiteName: "drift.shell.\(UUID().uuidString)")!) == Settings(), "shell runner wired up")

print(failures == 0 ? "All shell checks passed" : "\(failures) shell check(s) failed")
exit(failures == 0 ? 0 : 1)

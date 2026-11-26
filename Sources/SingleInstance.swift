import Darwin
import Foundation

/// Makes sure only one Drift runs per user. The first process holds an
/// exclusive lock on a file; the kernel drops the lock when that process exits
/// or crashes, so a stale lock can't block the next launch.
enum SingleInstance {
    private static var lockDescriptor: Int32 = -1

    /// Returns false only if another Drift already holds the lock. Any other
    /// failure lets Drift run, since never starting is worse than a rare duplicate.
    static func claim() -> Bool {
        guard let path = lockFilePath() else { return true }
        let descriptor = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return true }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let heldElsewhere = errno == EWOULDBLOCK
            close(descriptor)
            return !heldElsewhere
        }
        lockDescriptor = descriptor
        return true
    }

    /// In Application Support rather than the temp folder, which macOS cleans
    /// nightly and could delete from under a long-running Drift.
    private static func lockFilePath() -> String? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let folder = support.appendingPathComponent("Drift", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return folder.appendingPathComponent("drift.lock").path
    }
}

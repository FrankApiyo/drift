import Darwin
import Foundation

/// Makes sure only one Drift runs per user. The first process holds an
/// exclusive lock on a file; the kernel drops the lock when that process exits
/// or crashes, so a stale lock can't block the next launch.
enum SingleInstance {
    private static var lockDescriptor: Int32 = -1

    /// Returns false if another Drift already holds the lock.
    static func claim() -> Bool {
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("local.drift.Drift.lock")
        let descriptor = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            // Without a lock file we can't tell; better to run than to never start.
            return true
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return false
        }
        lockDescriptor = descriptor
        return true
    }
}

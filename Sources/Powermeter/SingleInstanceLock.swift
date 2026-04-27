import Darwin
import Foundation

/// Один экземпляр меню: при включении автозапуска `launchctl` может поднять второй процесс с тем же бинарником.
enum SingleInstanceLock {
    private static var fd: Int32 = -1

    static func acquireOrExit() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Powermeter", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let lockURL = base.appendingPathComponent(".instance_lock", isDirectory: false)
        let path = lockURL.path
        fd = open(path, O_RDWR | O_CREAT, 0o644)
        guard fd >= 0 else { return }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            exit(0)
        }
    }
}

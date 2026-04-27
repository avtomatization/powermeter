import Foundation

enum PowermeterLog {
    static let filePath = "/tmp/powermeter-debug.log"
    private static let lock = NSLock()

    static func clearSession() {
        lock.lock()
        defer { lock.unlock() }
        let header = "\(iso(Date())) === Powermeter log session start ===\n"
        try? header.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    static func log(_ message: String, file: StaticString = #fileID, line: UInt = #line) {
        let row = "\(iso(Date())) \(file):\(line) \(message)\n"
        lock.lock()
        defer { lock.unlock() }
        if let data = row.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: filePath),
               let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: filePath)) {
                defer { try? h.close() }
                _ = try? h.seekToEnd()
                try? h.write(contentsOf: data)
            } else {
                try? data.write(to: URL(fileURLWithPath: filePath))
            }
        }
        fputs(row, stderr)
    }

    private static func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }
}

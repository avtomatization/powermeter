import Darwin
import Foundation

/// Регистрация `~/Library/LaunchAgents/com.powermeter.menu.plist` + `launchctl`, как в `scripts/install.sh`.
enum LaunchAtLogin {
    static let label = "com.powermeter.menu"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func resolvedExecutablePath() -> String {
        let u = URL(fileURLWithPath: CommandLine.arguments[0])
        return u.resolvingSymlinksInPath().standardizedFileURL.path
    }

    static func isEnabled() -> Bool {
        guard let dict = NSDictionary(contentsOfFile: plistURL.path) as? [String: Any],
              let args = dict["ProgramArguments"] as? [String],
              let stored = args.first
        else { return false }
        if dict["RunAtLoad"] as? Bool == false { return false }
        return pathsMatch(stored, resolvedExecutablePath())
    }

    static func setEnabled(_ on: Bool) {
        if on {
            enable()
        } else {
            disable()
        }
    }

    private static func pathsMatch(_ a: String, _ b: String) -> Bool {
        let ua = URL(fileURLWithPath: a).resolvingSymlinksInPath().standardizedFileURL
        let ub = URL(fileURLWithPath: b).resolvingSymlinksInPath().standardizedFileURL
        return ua == ub
    }

    private static func enable() {
        let exe = resolvedExecutablePath()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let logDir = "\(home)/Library/Logs/Powermeter"
        let agentsDir = "\(home)/Library/LaunchAgents"
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: agentsDir, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "KeepAlive": false,
            "StandardOutPath": "\(logDir)/stdout.log",
            "StandardErrorPath": "\(logDir)/stderr.log",
        ]
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        ) else {
            PowermeterLog.log("LaunchAtLogin: failed to serialize plist")
            return
        }

        launchctlBootout()
        do {
            try data.write(to: plistURL, options: .atomic)
        } catch {
            PowermeterLog.log("LaunchAtLogin: write plist failed: \(error)")
            return
        }
        launchctlBootstrap()
        PowermeterLog.log("LaunchAtLogin enabled exe=\(exe)")
    }

    private static func disable() {
        launchctlBootout()
        try? FileManager.default.removeItem(at: plistURL)
        PowermeterLog.log("LaunchAtLogin disabled")
    }

    private static func guiTarget() -> String {
        "gui/\(getuid())"
    }

    private static func launchctlBootout() {
        let t = guiTarget()
        runLaunchctl(["bootout", t, plistURL.path])
        runLaunchctl(["bootout", t, label])
    }

    private static func launchctlBootstrap() {
        let t = guiTarget()
        runLaunchctl(["bootstrap", t, plistURL.path])
    }

    private static func runLaunchctl(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        do {
            try p.run()
            p.waitUntilExit()
            PowermeterLog.log("launchctl \(args.joined(separator: " ")) status=\(p.terminationStatus)")
        } catch {
            PowermeterLog.log("launchctl error: \(error)")
        }
    }
}

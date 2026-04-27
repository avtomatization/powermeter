import Foundation

/// SwiftPM places `Powermeter_Powermeter.bundle` next to the executable. The generated `Bundle.module` resolves it via
/// `Bundle.main.bundleURL`, which is wrong for many CLI installs (e.g. Homebrew `bin` symlink → `Cellar/.../bin`).
enum PowermeterResourceBundle {
    static let shared: Bundle = {
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let dir = exe.deletingLastPathComponent()
        let url = dir.appendingPathComponent("Powermeter_Powermeter.bundle", isDirectory: true)
        guard let b = Bundle(url: url),
              b.path(forResource: "en", ofType: "lproj") != nil
        else {
            let msg = """
            Powermeter: missing `Powermeter_Powermeter.bundle` next to the executable.
            Expected: \(url.path)
            Executable: \(exe.path)
            """
            fputs("\(msg)\n", stderr)
            fatalError(msg)
        }
        return b
    }()
}

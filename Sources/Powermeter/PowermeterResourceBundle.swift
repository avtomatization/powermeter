import Foundation

/// SwiftPM places `Powermeter_Powermeter.bundle` next to the release binary. The generated `Bundle.module` uses
/// `Bundle.main.bundleURL`, which breaks under Homebrew symlinks. We resolve from the real executable path first,
/// then fall back to a SwiftPM `.build` layout when the binary is a copy/symlink in the package root (dev workflow).
enum PowermeterResourceBundle {
    static let shared: Bundle = {
        guard let b = loadBundle() else {
            let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
            let msg = """
            Powermeter: missing `Powermeter_Powermeter.bundle`.
            Executable: \(exe.path)
            Put the bundle next to the binary, or run from `.build/<arch>-apple-macosx/release/Powermeter`.
            """
            fputs("\(msg)\n", stderr)
            fatalError(msg)
        }
        return b
    }()

    private static func loadBundle() -> Bundle? {
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let exeDir = exe.deletingLastPathComponent()
        let sibling = exeDir.appendingPathComponent("Powermeter_Powermeter.bundle", isDirectory: true)
        if let b = bundleIfValid(at: sibling) { return b }

        var dir = exeDir
        for _ in 0..<8 {
            let pkg = dir.appendingPathComponent("Package.swift")
            if FileManager.default.isReadableFile(atPath: pkg.path),
               let b = findSwiftPMResourceBundle(packageRoot: dir) {
                return b
            }
            let parent = dir.deletingLastPathComponent()
            if parent.standardizedFileURL == dir.standardizedFileURL { break }
            dir = parent
        }
        return nil
    }

    private static func bundleIfValid(at url: URL) -> Bundle? {
        guard let b = Bundle(url: url),
              b.path(forResource: "en", ofType: "lproj") != nil else { return nil }
        return b
    }

    /// `.build/<triple>/release|debug/Powermeter_Powermeter.bundle`
    private static func findSwiftPMResourceBundle(packageRoot: URL) -> Bundle? {
        let build = packageRoot.appendingPathComponent(".build")
        guard let triples = try? FileManager.default.contentsOfDirectory(
            at: build,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let sortedTriples = triples.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for config in ["release", "debug"] {
            for triple in sortedTriples {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: triple.path, isDirectory: &isDir),
                      isDir.boolValue else { continue }
                let cand = triple.appendingPathComponent(config).appendingPathComponent("Powermeter_Powermeter.bundle")
                if let b = bundleIfValid(at: cand) { return b }
            }
        }
        return nil
    }
}

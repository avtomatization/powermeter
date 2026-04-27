import Foundation

/// SwiftPM places `Powermeter_Powermeter.bundle` next to the release binary. The generated `Bundle.module` uses
/// `Bundle.main.bundleURL`, which breaks under Homebrew symlinks. We resolve from the real executable path first,
/// then fall back to a SwiftPM `.build` layout when the binary is a copy/symlink in the package root (dev workflow).
enum PowermeterResourceBundle {
    static let shared: Bundle = {
        guard let b = loadBundle() else {
            let exe = resolvedExecutableURL()
            let msg = """
            Powermeter: missing `Powermeter_Powermeter.bundle`.
            Executable: \(exe.path)
            Expected next to the binary, ../libexec/, or ../share/powermeter/ (Homebrew). See README.
            """
            fputs("\(msg)\n", stderr)
            fatalError(msg)
        }
        return b
    }()

    private static func loadBundle() -> Bundle? {
        let exe = resolvedExecutableURL()
        let exeDir = exe.deletingLastPathComponent()
        let kegRoot = exeDir.deletingLastPathComponent()

        // 1) Next to the binary (swift run, scripts/install.sh).
        // 2) `../libexec/` and `../share/powermeter/` — Homebrew formula installs the bundle here (not in `bin/`).
        let candidates: [URL] = [
            exeDir.appendingPathComponent("Powermeter_Powermeter.bundle", isDirectory: true),
            kegRoot.appendingPathComponent("libexec/Powermeter_Powermeter.bundle", isDirectory: true),
            kegRoot.appendingPathComponent("share/powermeter/Powermeter_Powermeter.bundle", isDirectory: true),
        ]
        for u in candidates {
            if let b = bundleIfValid(at: u) { return b }
        }
        if let b = findBundleUnderKeg(root: kegRoot, maxDepth: 5) { return b }

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

    /// `argv[0]` may be relative (`./.build/release/Powermeter`) or a bare name from `exec` (`Powermeter`).
    private static func resolvedExecutableURL() -> URL {
        let arg0 = CommandLine.arguments[0]
        if !arg0.contains("/") {
            if let hit = resolveInPATH(executableName: arg0) {
                return hit
            }
        }
        let base: URL
        if arg0.hasPrefix("/") {
            base = URL(fileURLWithPath: arg0)
        } else {
            let cwd = FileManager.default.currentDirectoryPath
            base = URL(fileURLWithPath: cwd, isDirectory: true).appendingPathComponent(arg0)
        }
        return base.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func resolveInPATH(executableName: String) -> URL? {
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in pathEnv.split(separator: ":") where !dir.isEmpty {
            let u = URL(fileURLWithPath: String(dir), isDirectory: true)
                .appendingPathComponent(executableName)
            if FileManager.default.isExecutableFile(atPath: u.path) {
                return u.resolvingSymlinksInPath()
            }
        }
        return nil
    }

    private static func bundleIfValid(at url: URL) -> Bundle? {
        guard let b = Bundle(url: url),
              b.path(forResource: "en", ofType: "lproj") != nil else { return nil }
        return b
    }

    /// Walk the Homebrew keg (shallow) if `bin/` / `libexec/` layout differs.
    private static func findBundleUnderKeg(root: URL, maxDepth: Int) -> Bundle? {
        guard maxDepth >= 0 else { return nil }
        let name = "Powermeter_Powermeter.bundle"
        let direct = root.appendingPathComponent(name, isDirectory: true)
        if let b = bundleIfValid(at: direct) { return b }
        guard let subs = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for sub in subs {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: sub.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if let b = findBundleUnderKeg(root: sub, maxDepth: maxDepth - 1) { return b }
        }
        return nil
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

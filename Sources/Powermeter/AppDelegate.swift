import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        SingleInstanceLock.acquireOrExit()
        NSApp.setActivationPolicy(.accessory)
    }
}

import SwiftUI

@main
struct PowermeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        MenuBarExtra {
            MenuBarDropdownContent(settings: settings)
        } label: {
            MenuBarTrayContainer(settings: settings)
        }
        .menuBarExtraStyle(.menu)
    }
}

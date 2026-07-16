import AppKit
import SwiftUI

/// Lazily creates and shows the SwiftUI settings window. In an accessory
/// (menu-bar) app we must activate the app so the window comes to the front.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: Settings.shared))
            let w = NSWindow(contentViewController: hosting)
            w.title = "marmar Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// App delegate for the standalone `--settings` mode: shows the preferences
/// window and quits when it's closed.
@MainActor
final class SettingsOnlyDelegate: NSObject, NSApplicationDelegate {
    private let controller = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

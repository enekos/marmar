import AppKit

// marmar — a lightweight, fully on-device push-to-talk dictation tool.
// Hold Right-Option, speak, release: the transcript is pasted at your cursor.
//
// Menu-bar only (no dock icon). No Xcode project needed — `swift build` plus
// build.sh assembles the .app bundle.
@main
struct Main {
    @MainActor
    static func main() {
        // Headless test/CLI path: `marmar --record [seconds]` records the mic
        // and prints the transcript, then exits (no menu bar).
        let args = CommandLine.arguments

        // `marmar --logs` prints the debug log (and its path) and exits.
        if args.contains("--logs") {
            print("log file: \(Log.path)\n")
            Log.dump()
            return
        }

        if let idx = args.firstIndex(of: "--record") {
            let seconds = (idx + 1 < args.count ? Double(args[idx + 1]) : nil) ?? 6.0
            HeadlessRecorder.run(seconds: seconds)
            return
        }

        // Login-item management (used by install.sh / uninstall.sh).
        if args.contains("--register-login") {
            let err = LoginItem.setEnabled(true)
            FileHandle.standardError.write(Data("[marmar] login item: \(err ?? LoginItem.statusText)\n".utf8))
            return
        }
        if args.contains("--unregister-login") {
            let err = LoginItem.setEnabled(false)
            FileHandle.standardError.write(Data("[marmar] login item: \(err ?? "removed")\n".utf8))
            return
        }

        // `marmar --hud-demo` shows the dictation HUD with a simulated mic
        // signal and streaming sample text — a permission-free way to preview
        // the GUI without holding the hotkey.
        if args.contains("--hud-demo") {
            let app = NSApplication.shared
            let delegate = HudDemoDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.regular)
            app.run()
            return
        }

        // `marmar --settings` opens just the preferences window (no menu bar).
        if args.contains("--settings") {
            let app = NSApplication.shared
            let delegate = SettingsOnlyDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.regular)
            app.run()
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu-bar accessory, no dock icon
        app.run()
    }
}

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
        if let idx = args.firstIndex(of: "--record") {
            let seconds = (idx + 1 < args.count ? Double(args[idx + 1]) : nil) ?? 6.0
            HeadlessRecorder.run(seconds: seconds)
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu-bar accessory, no dock icon
        app.run()
    }
}

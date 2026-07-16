import AppKit

/// Dev-only preview for `marmar --hud-demo`: shows the dictation HUD and drives
/// it with a synthetic mic level + streaming sample transcript, so the GUI can
/// be seen without microphone/accessibility permissions or the hotkey.
@MainActor
final class HudDemoDelegate: NSObject, NSApplicationDelegate {
    private let state = DictationState()
    private lazy var window = DictationWindowController(state: state)
    private var timer: Timer?
    private var tick = 0

    private let words = """
        marmar is a lightweight on device dictation tool for macOS \
        it transcribes your speech entirely on the device \
        no cloud no accounts no llm reformatting
        """.split(separator: " ").map(String.init)

    func applicationDidFinishLaunching(_ notification: Notification) {
        state.status = "Listening…"
        state.isRecording = true
        window.show()
        NSApp.activate(ignoringOtherApps: true)

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.step() }
        }
    }

    private func step() {
        tick += 1

        // Synthetic mic level: a couple of sines plus jitter, 0…1.
        let t = Double(tick) * 0.1
        let s = 0.45 + 0.3 * sin(t * 3.1) + 0.2 * sin(t * 7.7)
        let jitter = Double((tick * 2654435761) % 100) / 100.0 * 0.15
        state.pushLevel(Float(max(0, min(1, s + jitter))))

        // Stream in a new word every ~0.4s.
        if tick % 4 == 0 {
            let count = min(words.count, tick / 4)
            state.transcript = words.prefix(count).joined(separator: " ")
            if count == words.count {
                state.status = "Ready"
                state.isRecording = false
                state.level = 0
            }
        }
    }
}

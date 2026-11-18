import AppKit
import CoreGraphics

/// Inserts text into the frontmost app by putting it on the pasteboard and
/// synthesizing Cmd+V, then restoring the previous clipboard contents.
enum TextInserter {
    private static let vKeyCode: CGKeyCode = 9 // 'v'

    static func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        let keyWin = NSApp.keyWindow?.title ?? "none"
        Log.log("[paste] inserting \(text.count) chars — frontmost app=\(frontApp), our keyWindow=\(keyWin)")

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        paste()
        Log.log("[paste] Cmd+V posted")

        // Restore the user's clipboard shortly after the paste has been read by
        // the target app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pasteboard.clearContents()
            if let saved {
                pasteboard.setString(saved, forType: .string)
            }
        }
    }

    private static func paste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}

import AppKit
import SwiftUI

/// Hosts `DictationView` in a floating **non-activating** panel.
///
/// This is deliberately an `NSPanel` with `.nonactivatingPanel`: dictation
/// pastes the transcript at the cursor of whatever app is frontmost, so this
/// window must never become key/active — otherwise the paste would land here
/// instead of in the app the user is typing into.
@MainActor
final class DictationWindowController {
    private var panel: NSPanel?
    private let state: DictationState

    init(state: DictationState) {
        self.state = state
    }

    /// Show the HUD (creating it lazily). Ordered front without activating,
    /// so focus stays with the app being dictated into.
    func show() {
        let panel = ensurePanel()
        positionIfNeeded(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let hosting = NSHostingController(rootView: DictationView(state: state))
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.titled, .closable, .nonactivatingPanel, .hudWindow, .utilityWindow]
        panel.title = "marmar"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace]
        self.panel = panel
        return panel
    }

    /// Park it in the bottom-right of the main screen on first show.
    private func positionIfNeeded(_ panel: NSPanel) {
        guard !panel.isVisible, panel.frame.origin == .zero || !hasBeenPositioned else { return }
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let origin = NSPoint(
                x: visible.maxX - size.width - 24,
                y: visible.minY + 24
            )
            panel.setFrameOrigin(origin)
            hasBeenPositioned = true
        }
    }

    private var hasBeenPositioned = false
}

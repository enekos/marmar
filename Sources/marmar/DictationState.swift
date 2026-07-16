import Foundation
import Observation

/// Observable view-model backing the dictation HUD window. The `AppDelegate`
/// writes to it as dictation state changes; `DictationView` reads from it.
@MainActor
@Observable
final class DictationState {
    /// Live (while recording) or final transcript text shown in the textarea.
    var transcript: String = ""
    /// Short status line ("Listening…", "Ready", …) mirrored from the menu bar.
    var status: String = "Ready"
    /// True while the mic is actively capturing.
    var isRecording: Bool = false
    /// Smoothed mic input level, 0…1, drives the level meter.
    var level: Float = 0

    /// Feed a raw level sample; smooth it so the meter glides instead of jittering.
    func pushLevel(_ sample: Float) {
        // Fast attack, slower release for a natural-looking meter.
        let smoothing: Float = sample > level ? 0.5 : 0.15
        level += (sample - level) * smoothing
    }
}

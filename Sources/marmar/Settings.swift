import Foundation
import Observation

/// User-configurable settings, persisted in UserDefaults. `onChange` fires
/// whenever a value changes so the app can re-apply it live.
@Observable
final class Settings {
    static let shared = Settings()

    /// Preset hold-to-talk chords, mapped to CoreGraphics device-flag masks
    /// (left/right aware — see `HotKey.Mod`).
    enum HotkeyPreset: String, CaseIterable, Identifiable {
        case rightCmdShift
        case rightCmdOption
        case rightCmdControl
        case rightOption
        case rightControl

        var id: String { rawValue }

        var label: String {
            switch self {
            case .rightCmdShift:   return "Right ⌘ + Right ⇧"
            case .rightCmdOption:  return "Right ⌘ + Right ⌥"
            case .rightOption:     return "Right ⌥"
            case .rightControl:    return "Right ⌃"
            case .rightCmdControl: return "Right ⌘ + Right ⌃"
            }
        }

        var mask: UInt64 {
            switch self {
            case .rightCmdShift:   return HotKey.Mod.rightCommand | HotKey.Mod.rightShift
            case .rightCmdOption:  return HotKey.Mod.rightCommand | HotKey.Mod.rightOption
            case .rightOption:     return HotKey.Mod.rightOption
            case .rightControl:    return HotKey.Mod.rightControl
            case .rightCmdControl: return HotKey.Mod.rightCommand | HotKey.Mod.rightControl
            }
        }
    }

    // MARK: - Stored settings

    var hotkey: HotkeyPreset { didSet { persist(); notify() } }
    /// Empty string = follow the system locale.
    var localeIdentifier: String { didSet { persist(); notify() } }
    var trailingSpace: Bool { didSet { persist(); notify() } }
    var soundFeedback: Bool { didSet { persist(); notify() } }

    @ObservationIgnored
    var onChange: ((Settings) -> Void)?

    /// Resolved locale: the configured one, or the system default when unset.
    var locale: Locale {
        localeIdentifier.isEmpty ? Locale.current : Locale(identifier: localeIdentifier)
    }

    // MARK: - Persistence

    private enum Key {
        static let hotkey = "hotkey"
        static let locale = "localeIdentifier"
        static let trailingSpace = "trailingSpace"
        static let soundFeedback = "soundFeedback"
    }

    private init() {
        let d = UserDefaults.standard
        hotkey = HotkeyPreset(rawValue: d.string(forKey: Key.hotkey) ?? "") ?? .rightCmdShift
        localeIdentifier = d.string(forKey: Key.locale) ?? ""
        trailingSpace = d.object(forKey: Key.trailingSpace) as? Bool ?? true
        soundFeedback = d.object(forKey: Key.soundFeedback) as? Bool ?? true
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(hotkey.rawValue, forKey: Key.hotkey)
        d.set(localeIdentifier, forKey: Key.locale)
        d.set(trailingSpace, forKey: Key.trailingSpace)
        d.set(soundFeedback, forKey: Key.soundFeedback)
    }

    private func notify() { onChange?(self) }
}

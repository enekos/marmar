import SwiftUI
import Speech

/// A small preferences form. Hosted in an NSWindow by `SettingsWindowController`.
struct SettingsView: View {
    @Bindable var settings: Settings
    @State private var locales: [Locale] = []

    private var systemLocaleName: String {
        let id = Locale.current.identifier
        return Locale.current.localizedString(forIdentifier: id) ?? id
    }

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $settings.localeIdentifier) {
                    Text("System — \(systemLocaleName)").tag("")
                    ForEach(locales, id: \.identifier) { loc in
                        Text(Locale.current.localizedString(forIdentifier: loc.identifier) ?? loc.identifier)
                            .tag(loc.identifier)
                    }
                }
                if !locales.isEmpty && !settings.localeIdentifier.isEmpty
                    && !locales.contains(where: { $0.identifier == settings.localeIdentifier }) {
                    Text("Not available on-device; closest match will be used.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Dictation hotkey", selection: $settings.hotkey) {
                    ForEach(Settings.HotkeyPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                Text("Hold to talk, release to insert.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Add a trailing space", isOn: $settings.trailingSpace)
                Toggle("Play a sound when listening starts/stops", isOn: $settings.soundFeedback)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            let supported = await SpeechTranscriber.supportedLocales
            locales = supported.sorted {
                let a = Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier
                let b = Locale.current.localizedString(forIdentifier: $1.identifier) ?? $1.identifier
                return a.localizedCompare(b) == .orderedAscending
            }
        }
    }
}

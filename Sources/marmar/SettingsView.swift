import SwiftUI
import Speech
import AVFoundation
import ServiceManagement
import ApplicationServices
import AppKit

/// A small preferences form. Hosted in an NSWindow by `SettingsWindowController`.
struct SettingsView: View {
    @Bindable var settings: Settings
    @State private var locales: [Locale] = []

    // Live service status.
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var axTrusted = AXIsProcessTrusted()
    @State private var loginStatus = LoginItem.status
    @State private var modelText = "Checking…"
    @State private var modelReady = false

    private var systemLocaleName: String {
        let id = Locale.current.identifier
        return Locale.current.localizedString(forIdentifier: id) ?? id
    }

    var body: some View {
        Form {
            statusSection

            Section("Preferences") {
                Picker("Language", selection: $settings.localeIdentifier) {
                    Text("System — \(systemLocaleName)").tag("")
                    ForEach(locales, id: \.identifier) { loc in
                        Text(Locale.current.localizedString(forIdentifier: loc.identifier) ?? loc.identifier)
                            .tag(loc.identifier)
                    }
                }
                Picker("Dictation hotkey", selection: $settings.hotkey) {
                    ForEach(Settings.HotkeyPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                Toggle("Add a trailing space", isOn: $settings.trailingSpace)
                Toggle("Play a sound when listening starts/stops", isOn: $settings.soundFeedback)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .task { await loadLocales() }
        .task { await pollStatus() }
    }

    // MARK: - Status box

    private var statusSection: some View {
        Section("Service status") {
            StatusRow(
                label: "Microphone",
                ok: micStatus == .authorized,
                detail: micDetail,
                action: micStatus == .authorized ? nil : ("Open Settings", { openPane("Privacy_Microphone") })
            )
            StatusRow(
                label: "Accessibility",
                ok: axTrusted,
                detail: axTrusted ? "Granted" : "Required for hotkey + paste",
                action: axTrusted ? nil : ("Open Settings", { openPane("Privacy_Accessibility") })
            )
            StatusRow(
                label: "Speech model",
                ok: modelReady,
                detail: modelText,
                action: nil
            )

            Toggle("Start marmar at login", isOn: Binding(
                get: { loginStatus == .enabled },
                set: { on in
                    _ = LoginItem.setEnabled(on)
                    loginStatus = LoginItem.status
                }
            ))
            if loginStatus == .requiresApproval {
                HStack {
                    Text("Approve marmar in Login Items to finish enabling.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Login Items") {
                        NSWorkspace.shared.open(URL(string:
                            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var micDetail: String {
        switch micStatus {
        case .authorized:    return "Authorized"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not requested yet"
        @unknown default:    return "Unknown"
        }
    }

    // MARK: - Data loading

    private func loadLocales() async {
        let supported = await SpeechTranscriber.supportedLocales
        locales = supported.sorted {
            let a = Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier
            let b = Locale.current.localizedString(forIdentifier: $1.identifier) ?? $1.identifier
            return a.localizedCompare(b) == .orderedAscending
        }
    }

    /// Poll live status every ~1.5s so the box reflects changes the user makes
    /// in System Settings while this window is open.
    private func pollStatus() async {
        while !Task.isCancelled {
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            axTrusted = AXIsProcessTrusted()
            loginStatus = LoginItem.status
            await refreshModel()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }

    private func refreshModel() async {
        let installed = await SpeechTranscriber.installedLocales
        let wanted = settings.locale
        let lang = wanted.language.languageCode?.identifier
        if let match = installed.first(where: { $0.identifier == wanted.identifier })
            ?? installed.first(where: { $0.language.languageCode?.identifier == lang }) {
            modelReady = true
            let name = Locale.current.localizedString(forIdentifier: match.identifier) ?? match.identifier
            modelText = "Ready — \(name)"
        } else {
            modelReady = false
            modelText = "Downloads on first dictation"
        }
    }

    private func openPane(_ anchor: String) {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
    }
}

/// One labelled status line with a colored dot and an optional action button.
private struct StatusRow: View {
    let label: String
    let ok: Bool
    let detail: String
    let action: (String, () -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(label)
            Spacer()
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
            if let action {
                Button(action.0, action: action.1)
                    .controlSize(.small)
            }
        }
    }
}

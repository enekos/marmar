import AppKit
import AVFoundation
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKey = HotKey()
    private let dictation = DictationController()
    private let settingsWindow = SettingsWindowController()
    private let dictationState = DictationState()
    private lazy var dictationWindow = DictationWindowController(state: dictationState)
    private var statusLine = "Starting…"

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.log("[app] launched (v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"))")
        setupMenuBar()
        wireDictation()

        // Apply persisted settings now, and re-apply whenever they change.
        applySettings(Settings.shared)
        Settings.shared.onChange = { [weak self] s in
            Task { @MainActor in self?.applySettings(s) }
        }

        requestMicrophoneAccess { [weak self] granted in
            guard let self else { return }
            Log.log("[app] microphone access granted=\(granted)")
            if granted {
                self.dictation.prepare()
            } else {
                self.statusLine = "Microphone access denied"
                self.render()
            }
        }

        setupHotKey()
        setupToggleSignal()
    }

    /// SIGUSR1 toggles dictation, so external launchers (Raycast, skhd, …) can
    /// drive push-to-talk as tap-to-start/tap-to-stop: `pkill -USR1 -x marmar`.
    private func setupToggleSignal() {
        signal(SIGUSR1, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        src.setEventHandler { [weak self] in
            Task { @MainActor in self?.dictation.toggle() }
        }
        src.resume()
    }

    // MARK: - UI

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(recording: false)
        rebuildMenu()
    }

    private func setIcon(recording: Bool) {
        let name = recording ? "mic.fill" : "mic"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "marmar")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        menu.addItem(.separator())

        let hint = NSMenuItem(title: "Hold \(Settings.shared.hotkey.label) to dictate", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Toggle Dictation", action: #selector(toggleDictation), keyEquivalent: "t")
        toggle.target = self
        menu.addItem(toggle)

        let window = NSMenuItem(title: "Show Dictation Window", action: #selector(showDictationWindow), keyEquivalent: "d")
        window.target = self
        menu.addItem(window)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit marmar", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func render() {
        rebuildMenu()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func showDictationWindow() {
        dictationWindow.show()
    }

    @objc private func toggleDictation() {
        dictation.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Settings

    private func applySettings(_ s: Settings) {
        hotKey.requiredMask = s.hotkey.mask
        dictation.setLocale(s.locale)
        render() // refresh the hotkey hint in the menu
    }

    // MARK: - Wiring

    private func wireDictation() {
        dictation.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .idle: self.statusLine = "Idle"
            case .preparingModel: self.statusLine = "Downloading speech model…"
            case .ready: self.statusLine = "Ready"
            case .recording:
                self.statusLine = "Listening…"
                self.setIcon(recording: true)
                self.dictationState.transcript = ""
                self.dictationState.isRecording = true
                self.dictationWindow.show()
                if Settings.shared.soundFeedback { NSSound(named: "Tink")?.play() }
            case .transcribing:
                self.statusLine = "Transcribing…"
                self.dictationState.isRecording = false
                self.dictationState.level = 0
                if Settings.shared.soundFeedback { NSSound(named: "Pop")?.play() }
            case .unavailable(let why): self.statusLine = why
            }
            if case .recording = state {} else {
                self.setIcon(recording: false)
                self.dictationState.isRecording = false
            }
            self.dictationState.status = self.statusLine
            self.render()
        }

        dictation.onLiveText = { [weak self] text in
            guard let self else { return }
            self.dictationState.transcript = text
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            self.statusLine = trimmed.isEmpty ? "Listening…" : "“\(trimmed.suffix(40))”"
            self.render()
        }

        dictation.onLevel = { [weak self] level in
            self?.dictationState.pushLevel(level)
        }

        dictation.onFinalText = { [weak self] text in
            self?.dictationState.transcript = text
            let out = Settings.shared.trailingSpace ? text + " " : text
            TextInserter.insert(out)
        }
    }

    private func setupHotKey() {
        hotKey.onDown = { [weak self] in
            Task { @MainActor in self?.dictation.begin() }
        }
        hotKey.onUp = { [weak self] in
            Task { @MainActor in self?.dictation.end() }
        }

        if !hotKey.start() {
            // No Accessibility permission yet: prompt and inform the user.
            Log.log("[app] hotkey start failed — prompting for Accessibility")
            statusLine = "Grant Accessibility, then relaunch"
            render()
            promptForAccessibility()
        }
    }

    // MARK: - Permissions

    private func requestMicrophoneAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    private func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

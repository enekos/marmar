import Foundation
import AVFoundation

/// Ties the mic capture to the transcriber for one press-and-hold cycle.
@MainActor
final class DictationController {
    enum State {
        case idle
        case preparingModel
        case ready
        case recording
        case transcribing
        case unavailable(String)
    }

    private(set) var state: State = .idle
    private let audio = AudioCapture()
    private var transcriber: LiveTranscriber?
    private var starting = false
    private var locale = Locale.current

    /// Fired on state changes so the UI can update.
    var onStateChange: ((State) -> Void)?
    /// Fired with live (partial) transcript text while recording.
    var onLiveText: ((String) -> Void)?
    /// Fired with the final transcript when a recording completes.
    var onFinalText: ((String) -> Void)?
    /// Fired with the normalized mic input level (0…1) while recording.
    var onLevel: ((Float) -> Void)?

    private func setState(_ newState: State) {
        Log.log("[dictation] state: \(label(state)) → \(label(newState))")
        state = newState
        onStateChange?(newState)
    }

    private func label(_ s: State) -> String {
        switch s {
        case .idle: return "idle"
        case .preparingModel: return "preparingModel"
        case .ready: return "ready"
        case .recording: return "recording"
        case .transcribing: return "transcribing"
        case .unavailable(let w): return "unavailable(\(w))"
        }
    }

    /// Switch dictation language. No-op if unchanged; re-prepares otherwise.
    func setLocale(_ newLocale: Locale) {
        guard newLocale.identifier != locale.identifier else { return }
        locale = newLocale
        prepare()
    }

    /// Download the locale model up front so the first dictation is instant.
    func prepare() {
        setState(.preparingModel)
        Task {
            let t = LiveTranscriber(locale: locale)
            do {
                try await t.ensureModel()
                setState(.ready)
            } catch LiveTranscriber.TranscriberError.localeNotSupported(let id) {
                setState(.unavailable("Locale \(id) not supported on-device"))
            } catch {
                setState(.unavailable("Model unavailable: \(error.localizedDescription)"))
            }
        }
    }

    /// Hotkey pressed — begin recording.
    func begin() {
        Log.log("[dictation] begin() requested (state=\(label(state)), starting=\(starting))")
        switch state {
        case .recording, .transcribing, .preparingModel:
            Log.log("[dictation] begin() IGNORED — busy in \(label(state))")
            return
        case .unavailable(let why):
            Log.log("[dictation] begin() IGNORED — unavailable: \(why)")
            return
        default:
            break
        }
        guard !starting else {
            Log.log("[dictation] begin() IGNORED — already starting")
            return
        }
        starting = true

        let t = LiveTranscriber(locale: locale)
        t.onLiveUpdate = { [weak self] text in
            self?.onLiveText?(text)
        }
        transcriber = t
        audio.onLevel = { [weak self] level in
            self?.onLevel?(level)
        }

        Task {
            do {
                try await t.start()
                try audio.start { [weak t] buffer in
                    t?.append(buffer)
                }
                setState(.recording)
            } catch {
                Log.log("[dictation] start FAILED: \(error.localizedDescription)")
                setState(.unavailable("Recording failed: \(error.localizedDescription)"))
                _ = await t.finish()
                transcriber = nil
            }
            starting = false
        }
    }

    /// External trigger (SIGUSR1, menu item) — start recording if idle, stop if recording.
    func toggle() {
        if case .recording = state {
            end()
        } else {
            begin()
        }
    }

    /// Hotkey released — stop recording, transcribe, emit final text.
    func end() {
        Log.log("[dictation] end() requested (state=\(label(state)), starting=\(starting))")
        guard case .recording = state else {
            // If we were still starting, wait for it then stop.
            if starting {
                Task {
                    // brief spin until start() completes
                    for _ in 0..<50 where starting {
                        try? await Task.sleep(nanoseconds: 20_000_000)
                    }
                    if case .recording = state { end() }
                }
            }
            return
        }

        audio.stop()
        onLevel?(0)
        setState(.transcribing)
        guard let t = transcriber else { setState(.ready); return }

        Task {
            let text = await t.finish()
            transcriber = nil
            Log.log("[dictation] finish returned \(text.count) chars\(text.isEmpty ? " (EMPTY)" : "")")
            if !text.isEmpty {
                onFinalText?(text)
            }
            setState(.ready)
        }
    }
}

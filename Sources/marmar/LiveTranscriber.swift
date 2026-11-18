import Foundation
import AVFoundation
import Speech

/// Wraps the macOS 26 on-device SpeechAnalyzer + SpeechTranscriber pipeline for
/// streaming dictation. One instance = one recording session:
///
///   1. `ensureModel()` once at launch (downloads the locale model if missing).
///   2. `start()` when the hotkey goes down.
///   3. `append(buffer:)` for each mic buffer while held.
///   4. `finish()` on release → returns the final transcript.
///
/// The `finalizeAndFinishThroughEndOfInput()` call in `finish()` is essential:
/// without it, results never drain and the call hangs (the exact footgun the
/// Inscribe benchmark writeup calls out).
final class LiveTranscriber {
    enum TranscriberError: Error {
        case localeNotSupported(String)
        case noCompatibleAudioFormat
    }

    let locale: Locale

    /// The actual on-device locale we transcribe with — may differ from the
    /// requested one (e.g. en_DE → en_US), resolved in `ensureModel()`.
    private(set) var resolvedLocale: Locale

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var resultsTask: Task<Void, Never>?

    /// Finalized (stable) text collected so far.
    private var finalized = ""
    /// Latest volatile (in-progress) hypothesis, for live display only.
    private(set) var volatile = ""

    /// Called on the main queue whenever the live text changes.
    var onLiveUpdate: ((String) -> Void)?

    init(locale: Locale = Locale.current) {
        self.locale = locale
        self.resolvedLocale = locale
    }

    /// Pick the closest supported on-device locale: exact identifier → same
    /// language+region → same language → give up.
    private func resolveSupportedLocale() async throws -> Locale {
        let supported = await SpeechTranscriber.supportedLocales
        let lang = locale.language.languageCode?.identifier
        let region = locale.region?.identifier

        if let m = supported.first(where: { $0.identifier == locale.identifier }) { return m }
        if let lang {
            if let m = supported.first(where: {
                $0.language.languageCode?.identifier == lang && $0.region?.identifier == region
            }) { return m }

            // Same language, no region match: prefer a "primary" region
            // (US/GB for English, etc.) over an arbitrary first hit like ZA.
            let sameLang = supported.filter { $0.language.languageCode?.identifier == lang }
            let preferredRegions = ["US", "GB", "AU", "CA", "IN"]
            for pref in preferredRegions {
                if let m = sameLang.first(where: { $0.region?.identifier == pref }) { return m }
            }
            if let m = sameLang.first { return m }
        }
        throw TranscriberError.localeNotSupported(locale.identifier)
    }

    /// Ensure the on-device model for the resolved locale is installed. Safe to
    /// call repeatedly; only downloads once.
    func ensureModel() async throws {
        resolvedLocale = try await resolveSupportedLocale()

        let probe = SpeechTranscriber(
            locale: resolvedLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        let installed = await SpeechTranscriber.installedLocales
        let alreadyInstalled = installed.contains { $0.identifier == resolvedLocale.identifier }
        if !alreadyInstalled {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
                try await request.downloadAndInstall()
            }
        }
    }

    /// Begin a streaming session.
    func start() async throws {
        finalized = ""
        volatile = ""

        let transcriber = SpeechTranscriber(
            locale: resolvedLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriberError.noCompatibleAudioFormat
        }
        self.analyzerFormat = format
        self.converter = nil // rebuilt lazily once we see the input format

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputBuilder = continuation

        // Drain results in the background. Final results append to `finalized`;
        // volatile results update the live preview.
        resultsTask = Task { [weak self] in
            guard let self, let transcriber = self.transcriber else { return }
            var count = 0
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        self.finalized += text
                        self.volatile = ""
                        count += 1
                    } else {
                        self.volatile = text
                    }
                    let live = (self.finalized + self.volatile)
                    DispatchQueue.main.async { self.onLiveUpdate?(live) }
                }
                Log.log("[transcriber] results stream ended (\(count) final segments)")
            } catch {
                Log.log("[transcriber] results stream error: \(error.localizedDescription)")
            }
        }

        try await analyzer.start(inputSequence: stream)
        Log.log("[transcriber] analyzer started (locale=\(resolvedLocale.identifier))")
    }

    /// Feed one microphone buffer, converting to the analyzer's format.
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let inputBuilder, let analyzerFormat else { return }
        guard let converted = convert(buffer, to: analyzerFormat) else { return }
        inputBuilder.yield(AnalyzerInput(buffer: converted))
    }

    /// Stop input, flush the analyzer, and return the final transcript.
    ///
    /// The drain (`finalizeAndFinishThroughEndOfInput()` + waiting for the results
    /// stream to end) is capped by a timeout: if SpeechAnalyzer ever fails to
    /// terminate the stream, we still return the text we have instead of hanging
    /// forever — which would otherwise leave the controller stuck in
    /// `.transcribing` and make the hotkey appear dead.
    func finish() async -> String {
        Log.log("[transcriber] finish() begin")
        inputBuilder?.finish()

        let analyzer = self.analyzer
        let resultsTask = self.resultsTask
        let drain = Task {
            do {
                try await analyzer?.finalizeAndFinishThroughEndOfInput()
            } catch {
                Log.log("[transcriber] finalize error: \(error.localizedDescription)")
            }
            await resultsTask?.value
        }

        let timedOut = await Self.raceTimeout(seconds: 6) { await drain.value }
        if timedOut {
            Log.log("[transcriber] finish() TIMED OUT after 6s — returning partial text")
            drain.cancel()
            resultsTask?.cancel()
        }

        self.analyzer = nil
        self.transcriber = nil
        self.inputBuilder = nil
        self.resultsTask = nil

        let out = finalized.trimmingCharacters(in: .whitespacesAndNewlines)
        Log.log("[transcriber] finish() done (\(out.count) chars)")
        return out
    }

    /// Run `operation`, returning true if it exceeded `seconds` (else false).
    private static func raceTimeout(seconds: Double, _ operation: @escaping () async -> Void) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { await operation(); return false }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return true
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    // MARK: - Format conversion

    private func convert(_ buffer: AVAudioPCMBuffer, to outFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        let inFormat = buffer.format
        if inFormat == outFormat { return buffer }

        if converter == nil || converter?.inputFormat != inFormat {
            converter = AVAudioConverter(from: inFormat, to: outFormat)
        }
        guard let converter else { return nil }

        let ratio = outFormat.sampleRate / inFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else {
            return nil
        }

        var supplied = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, inStatus in
            if supplied {
                inStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inStatus.pointee = .haveData
            return buffer
        }

        if status == .error || out.frameLength == 0 { return nil }
        return out
    }
}

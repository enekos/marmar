import Foundation
import AVFoundation

/// Headless test/CLI path: record the mic for N seconds and print the
/// transcript. Exercises the exact `LiveTranscriber` + `AudioCapture` pipeline
/// the GUI uses, without needing the hotkey. Invoked via `marmar --record [sec]`.
enum HeadlessRecorder {
    static func run(seconds: Double) {
        let sem = DispatchSemaphore(value: 0)
        Task.detached {
            await record(seconds: seconds)
            sem.signal()
        }
        sem.wait()
    }

    private static func record(seconds: Double) async {
        let transcriber = LiveTranscriber(locale: Locale.current)
        let audio = AudioCapture()

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: break
        default:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else {
                FileHandle.standardError.write(Data("error: microphone access not granted\n".utf8))
                return
            }
        }

        transcriber.onLiveUpdate = { text in
            let line = "  … " + text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            FileHandle.standardError.write(Data(line.utf8))
        }

        let meter = LevelMeter()
        do {
            log("preparing model (locale \(Locale.current.identifier))…")
            try await transcriber.ensureModel()
            log("resolved locale: \(transcriber.resolvedLocale.identifier)")
            try await transcriber.start()
            try audio.start { buffer in
                meter.observe(buffer)
                transcriber.append(buffer)
            }
            log("input device format: \(audio.inputFormat)")
            log("recording \(seconds)s…")
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            audio.stop()
            log(String(format: "mic level: peak=%.4f rms=%.4f over %d buffers",
                       meter.peak, meter.rms, meter.bufferCount))
            log("finalizing…")
            let text = await transcriber.finish()
            print("=== TRANSCRIPT ===")
            print(text.isEmpty ? "(empty — no speech detected)" : text)
            print("==================")
        } catch {
            log("error: \(error)")
        }
    }

    private static func log(_ msg: String) {
        FileHandle.standardError.write(Data("[marmar] \(msg)\n".utf8))
    }
}

/// Tracks peak/RMS amplitude of incoming float PCM buffers, to tell whether the
/// mic is actually receiving signal.
final class LevelMeter {
    private(set) var peak: Float = 0
    private(set) var rms: Float = 0
    private(set) var bufferCount = 0
    private var sumSquares: Double = 0
    private var sampleCount: Double = 0

    func observe(_ buffer: AVAudioPCMBuffer) {
        bufferCount += 1
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        for ch in 0..<channels {
            let samples = data[ch]
            for i in 0..<frames {
                let v = abs(samples[i])
                if v > peak { peak = v }
                sumSquares += Double(v) * Double(v)
                sampleCount += 1
            }
        }
        if sampleCount > 0 { rms = Float((sumSquares / sampleCount).squareRoot()) }
    }
}

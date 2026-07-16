import AVFoundation

/// Captures microphone audio with AVAudioEngine and hands raw PCM buffers to a
/// callback. Buffers are in the input node's native format; the transcriber is
/// responsible for converting to whatever SpeechAnalyzer wants.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var running = false

    /// Normalized microphone input level (0…1), delivered on the main thread so
    /// the UI can drive a level meter. Fires for every captured buffer.
    var onLevel: ((Float) -> Void)?

    var inputFormat: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        guard !running else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            onBuffer(buffer)
            if let self, let level = self.level(of: buffer) {
                DispatchQueue.main.async { self.onLevel?(level) }
            }
        }
        engine.prepare()
        try engine.start()
        running = true
    }

    /// RMS loudness of a buffer mapped to a 0…1 range on a dB scale, so quiet
    /// speech still moves the meter and loud speech doesn't peg it.
    private func level(of buffer: AVAudioPCMBuffer) -> Float? {
        guard let data = buffer.floatChannelData else { return nil }
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        guard frames > 0, channels > 0 else { return nil }

        var sumSquares: Float = 0
        for ch in 0..<channels {
            let samples = data[ch]
            for i in 0..<frames {
                let s = samples[i]
                sumSquares += s * s
            }
        }
        let rms = (sumSquares / Float(frames * channels)).squareRoot()
        let db = 20 * log10(max(rms, 1e-7))          // ~ -140 (silence) … 0 (full scale)
        let normalized = (db + 60) / 60              // map -60…0 dB → 0…1
        return max(0, min(1, normalized))
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }
}

import AVFoundation

/// Captures microphone audio with AVAudioEngine and hands raw PCM buffers to a
/// callback. Buffers are in the input node's native format; the transcriber is
/// responsible for converting to whatever SpeechAnalyzer wants.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var running = false

    var inputFormat: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        guard !running else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            onBuffer(buffer)
        }
        engine.prepare()
        try engine.start()
        running = true
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }
}

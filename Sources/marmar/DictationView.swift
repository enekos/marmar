import SwiftUI

/// The dictation HUD: a live-transcript textarea plus a microphone input
/// indicator. Shown in a non-activating floating panel so it never steals key
/// focus from the app you're dictating into.
struct DictationView: View {
    @Bindable var state: DictationState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            TextEditor(text: $state.transcript)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(alignment: .topLeading) {
                    if state.transcript.isEmpty {
                        Text(state.isRecording ? "Listening…" : "Your dictation will appear here")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 120)
        }
        .padding(16)
        .frame(width: 380, height: 240)
    }

    // MARK: - Header (status + mic indicator)

    private var header: some View {
        HStack(spacing: 10) {
            RecordingDot(active: state.isRecording)
            Text(state.status)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            MicLevelMeter(level: state.level, active: state.isRecording)
        }
    }
}

/// A pulsing red dot while recording; a dim gray dot when idle.
private struct RecordingDot: View {
    let active: Bool
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(active ? Color.red : Color.secondary.opacity(0.4))
            .frame(width: 10, height: 10)
            .scaleEffect(active && pulse ? 1.35 : 1.0)
            .opacity(active && pulse ? 0.6 : 1.0)
            .animation(
                active
                    ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onChange(of: active) { _, isActive in pulse = isActive }
            .onAppear { pulse = active }
    }
}

/// A row of bars that rise and fall with the microphone input level — the
/// visible "receiving input from microphone" cue.
private struct MicLevelMeter: View {
    let level: Float          // 0…1
    let active: Bool

    private let barCount = 12

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(width: 3, height: height(for: i))
            }
        }
        .frame(height: 22, alignment: .center)
        .animation(.easeOut(duration: 0.08), value: level)
        .opacity(active ? 1 : 0.35)
    }

    /// Each bar has a rising activation threshold; taller-toward-the-center
    /// shape gives it an equalizer feel rather than a flat block.
    private func height(for index: Int) -> CGFloat {
        let fraction = Double(index) / Double(barCount - 1)
        let threshold = fraction                      // bar lights when level ≥ its position
        let base: CGFloat = 3
        guard active, Double(level) >= threshold * 0.9 else { return base }
        // Center bars a touch taller for shape.
        let center = 1 - abs(fraction - 0.5) * 1.2
        let lit = CGFloat(level) * 22 * (0.6 + 0.4 * center)
        return max(base, min(22, lit))
    }

    private func color(for index: Int) -> Color {
        guard active else { return Color.secondary.opacity(0.4) }
        let fraction = Double(index) / Double(barCount - 1)
        if Double(level) < fraction * 0.9 { return Color.secondary.opacity(0.25) }
        // green → yellow → red as the meter fills toward the right.
        switch fraction {
        case ..<0.6: return .green
        case ..<0.85: return .yellow
        default: return .red
        }
    }
}

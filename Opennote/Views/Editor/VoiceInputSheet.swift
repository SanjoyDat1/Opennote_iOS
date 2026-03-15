import SwiftUI
import Combine

// MARK: - Live Waveform View

/// Animated audio-visualiser bars.  Heights are driven by the real
/// mic amplitude (audioLevel) blended with a slow sine-wave "breath"
/// so it always looks alive even during quiet speech.
private struct LiveWaveformView: View {
    var isAnimating: Bool
    var audioLevel: Float

    private let barCount = 7
    private let minHeight: CGFloat = 5
    private let maxHeight: CGFloat = 52

    @State private var phase: Double = 0
    private let ticker = Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(Color.opennoteGreen)
                    .frame(width: 5, height: barHeight(for: i))
                    .animation(.easeInOut(duration: 0.1), value: barHeight(for: i))
            }
        }
        .frame(height: maxHeight + 8)
        .onReceive(ticker) { _ in
            guard isAnimating else { return }
            phase += 0.38
        }
        .onChange(of: isAnimating) { _, on in
            if !on { phase = 0 }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isAnimating else { return minHeight }
        // Blend sine wave + audio level so bars react to real speech volume
        let offset = Double(index) * 0.75
        let sineComponent = abs(sin(phase + offset))
        let levelBoost = Double(audioLevel) * 0.7
        let combined = sineComponent * 0.55 + levelBoost
        return minHeight + CGFloat(combined) * (maxHeight - minHeight)
    }
}

// MARK: - Voice Input Sheet

/// Compact bottom sheet for voice dictation.
/// Live partial results are streamed to `onLiveUpdate` so the journal block
/// updates in real time. The user explicitly taps Save or Cancel to finish.
struct VoiceInputSheet: View {
    @ObservedObject var service: SpeechToTextService
    var insertIntoPrompt: Bool = false
    var onLiveUpdate: ((String) -> Void)? = nil   // fired on every partial result
    let onInsert: (String) -> Void                // fired when user taps Save
    let onDismiss: () -> Void                     // fired when user taps Cancel

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────
            HStack(alignment: .center) {

                // Cancel — discard everything
                Button {
                    Haptics.impact(.light)
                    service.stopListening()
                    service.reset()
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Voice Input")
                    .font(.system(size: 17, weight: .bold))

                Spacer()

                // Save — stop recording and append to the note
                Button {
                    Haptics.impact(.medium)
                    service.stopListening()
                    let captured = service.transcribedText
                    if captured.isEmpty {
                        onDismiss()
                    } else {
                        onInsert(captured)
                    }
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.opennoteGreen)
                }
                .buttonStyle(.plain)
                // Dim while nothing has been transcribed yet
                .opacity(service.transcribedText.isEmpty ? 0.35 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: service.transcribedText.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Divider()
                .padding(.horizontal, 20)

            // ── Waveform ──────────────────────────────────────────
            VStack(spacing: 20) {
                LiveWaveformView(
                    isAnimating: service.isListening,
                    audioLevel: service.audioLevel
                )
                .frame(maxWidth: .infinity)

                // Status label
                Group {
                    if service.isListening {
                        Text("Listening…")
                            .foregroundStyle(.secondary)
                    } else if let err = service.errorMessage {
                        Text(err)
                            .foregroundStyle(.red)
                    } else if service.transcribedText.isEmpty {
                        Text("No speech detected")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Tap Save to add to your notes")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: service.isListening)
            }
            .padding(.vertical, 36)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemBackground))
        // Stream live transcript updates to the journal block
        .onChange(of: service.transcribedText) { _, newText in
            onLiveUpdate?(newText)
        }
        .onAppear {
            Task { await service.startListening() }
        }
        .onDisappear {
            service.stopListening()
        }
        .presentationDetents([.height(246)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
        .presentationBackground(.regularMaterial)
    }
}

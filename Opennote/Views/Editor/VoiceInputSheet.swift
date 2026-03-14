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
/// While active, each partial transcript is passed to `onLiveUpdate`
/// so the caller can update the journal block in real time.
struct VoiceInputSheet: View {
    @ObservedObject var service: SpeechToTextService
    var insertIntoPrompt: Bool = false
    var onLiveUpdate: ((String) -> Void)? = nil   // fired on every partial result
    let onInsert: (String) -> Void                // fired when dictation finalises
    let onDismiss: () -> Void                     // fired on Cancel

    @State private var hasAutoInserted = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────
            HStack(alignment: .center) {
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

                // Mirror of "Cancel" for optical centering
                Text("Cancel")
                    .font(.system(size: 16, weight: .regular))
                    .opacity(0)
                    .allowsHitTesting(false)
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
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tap the waveform to stop and finalise
                    guard service.isListening else { return }
                    Haptics.impact(.medium)
                    service.stopListening()
                    finalise()
                }

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
                        Text("Tap the waveform to finish")
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
        // Fire live updates every time the transcript changes
        .onChange(of: service.transcribedText) { _, newText in
            onLiveUpdate?(newText)
        }
        // When recognition auto-stops (timeout / error), finalise automatically
        .onChange(of: service.isListening) { _, isOn in
            if !isOn && !hasAutoInserted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    finalise()
                }
            }
        }
        .onAppear {
            hasAutoInserted = false
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

    private func finalise() {
        guard !hasAutoInserted else { return }
        hasAutoInserted = true
        let text = service.transcribedText
        if !text.isEmpty {
            onInsert(text)
        } else {
            onDismiss()
        }
    }
}

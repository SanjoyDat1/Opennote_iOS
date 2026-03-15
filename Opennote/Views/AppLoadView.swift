import SwiftUI

/// Cinematic splash screen — rises in, then peels away like an iOS card when the
/// user swipes up, revealing the app content behind it.
struct AppLoadView: View {
    let onComplete: () -> Void

    // MARK: - Logo
    @State private var logoOpacity: Double = 0
    @State private var logoRise: CGFloat = 50
    @State private var logoScale: CGFloat = 0.72
    @State private var floatY: CGFloat = 0
    @State private var tilt: Double = 0

    // MARK: - Glow (soft bloom — no hard ring)
    @State private var glowOpacity: Double = 0
    @State private var glowPulse: CGFloat = 1.0
    @State private var bgHaloOpacity: Double = 0

    // MARK: - Text
    @State private var titleOpacity: Double = 0
    @State private var titleRise: CGFloat = 28
    @State private var taglineOpacity: Double = 0
    @State private var taglineRise: CGFloat = 16

    // MARK: - Swipe indicator
    @State private var swipeOpacity: Double = 0
    @State private var chevronY: CGFloat = 0

    // MARK: - Swipe-to-dismiss state
    @State private var dragOffset: CGFloat = 0
    private let screenHeight = UIScreen.main.bounds.height

    /// Swipe indicator fades as the user begins dragging.
    private var indicatorOpacity: Double {
        max(0, swipeOpacity - (-dragOffset) / 110)
    }

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────────
            Color.opennoteCream.ignoresSafeArea()

            // Large soft ambient halo in the center (NOT a ring — just a glow)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.opennoteGreen.opacity(0.11), .clear],
                        center: .center, startRadius: 0, endRadius: 280
                    )
                )
                .frame(width: 620, height: 620)
                .opacity(bgHaloOpacity)
                .allowsHitTesting(false)

            // ── Main content — always centered ────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // Logo + soft glow bloom (no stroke ring)
                ZStack {
                    // Soft radial glow behind the logo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.opennoteGreen.opacity(0.30), .clear],
                                center: .center, startRadius: 0, endRadius: 90
                            )
                        )
                        .frame(width: 220, height: 220)
                        .scaleEffect(glowPulse)
                        .opacity(glowOpacity)
                        .blur(radius: 24)

                    // Paper airplane
                    Image("logo")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .foregroundStyle(Color.opennoteGreen)
                        .shadow(color: Color.opennoteGreen.opacity(0.48), radius: 22, x: 0, y: 8)
                        .offset(y: floatY)
                        .rotationEffect(.degrees(tilt))
                }
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
                .offset(y: logoRise)
                .frame(height: 210)

                // "Opennote"
                Text("Opennote")
                    .font(.system(size: 54, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .opacity(titleOpacity)
                    .offset(y: titleRise)
                    .padding(.top, 18)

                // Tagline
                Text("the notebook that thinks with you")
                    .font(.system(size: 17, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(taglineOpacity)
                    .offset(y: taglineRise)
                    .padding(.top, 10)
                    .padding(.horizontal, 44)

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)

            // ── Swipe-up indicator ────────────────────────────────────────
            VStack {
                Spacer()
                swipeUpIndicator
                    .opacity(indicatorOpacity)
                    .padding(.bottom, 54)
            }
        }
        .offset(y: dragOffset)
        .contentShape(Rectangle())
        .gesture(swipeGesture)
        .onAppear { runAnimations() }
    }

    // MARK: - Swipe indicator

    private var swipeUpIndicator: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: i == 0 ? .semibold : (i == 1 ? .medium : .regular)))
                    .foregroundStyle(Color.secondary.opacity(1.0 - Double(i) * 0.32))
                    .offset(y: chevronY * (1.0 - CGFloat(i) * 0.25))
            }
            Text("Swipe up to enter")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.top, 5)
        }
    }

    // MARK: - Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                let t = value.translation.height
                // Only upward drag (negative t) triggers lift; rubber-band resistance
                if t < 0 { dragOffset = t * 0.40 }
            }
            .onEnded { value in
                let dy = value.translation.height
                let vy = value.predictedEndTranslation.height
                if dy < -55 || vy < -170 {
                    // Dismiss — card flies off the top like a native iOS sheet
                    Haptics.impact(.medium)
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.80)) {
                        dragOffset = -screenHeight * 1.1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { onComplete() }
                } else {
                    // Snap back — spring returns the card to rest position
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Animation sequence

    private func runAnimations() {
        // Phase 1 — Logo rises in from below
        withAnimation(.spring(response: 0.75, dampingFraction: 0.68).delay(0.10)) {
            logoOpacity = 1
            logoScale = 1.0
            logoRise = 0
        }

        // Phase 2 — Background halo + logo glow
        withAnimation(.easeIn(duration: 0.75).delay(0.35)) {
            bgHaloOpacity = 1
            glowOpacity = 1.0
        }

        // Phase 3 — "Opennote" slides up
        withAnimation(.spring(response: 0.60, dampingFraction: 0.76).delay(0.72)) {
            titleOpacity = 1
            titleRise = 0
        }

        // Phase 4 — Tagline fades in
        withAnimation(.easeOut(duration: 0.52).delay(1.02)) {
            taglineOpacity = 1
            taglineRise = 0
        }

        // Phase 5 — Swipe indicator appears
        withAnimation(.easeIn(duration: 0.45).delay(1.55)) {
            swipeOpacity = 1
        }

        // Phase 6 — Idle float loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatY = -15
                tilt = 9
            }
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                glowPulse = 1.18
            }
        }

        // Phase 7 — Chevron cascade wave
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true)) {
                chevronY = -9
            }
        }
    }
}

#Preview {
    AppLoadView(onComplete: {})
}

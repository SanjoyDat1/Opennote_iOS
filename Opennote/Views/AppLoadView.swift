import SwiftUI

/// Cinematic load screen — paper airplane flies in, settles with an idle float,
/// large "Opennote" headline, tagline subheader, and swipe-up curtain to enter.
struct AppLoadView: View {
    let onComplete: () -> Void

    // MARK: - Plane flight
    @State private var planeX: CGFloat = -400
    @State private var planeY: CGFloat = 280
    @State private var planeRotation: Double = -44
    @State private var planeOpacity: Double = 0
    @State private var planeScale: CGFloat = 0.6

    // MARK: - Idle float (after landing)
    @State private var floatY: CGFloat = 0
    @State private var floatTilt: Double = 0

    // MARK: - Glow layers
    @State private var glowScale: CGFloat = 0.1
    @State private var glowOpacity: Double = 0
    @State private var bgGlowOpacity: Double = 0
    @State private var ringPulse: CGFloat = 1.0

    // MARK: - Text
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 36
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 22

    // MARK: - Swipe indicator — three staggered chevrons
    @State private var swipeOpacity: Double = 0
    @State private var c0Y: CGFloat = 0
    @State private var c1Y: CGFloat = 0
    @State private var c2Y: CGFloat = 0

    // MARK: - Particle layer
    @State private var particleDrift: CGFloat = 0

    // MARK: - Swipe-to-enter gesture
    @State private var dragOffset: CGFloat = 0

    // Fixed particle positions (deterministic — no randomness)
    private let particles: [(x: CGFloat, y: CGFloat, r: CGFloat, dir: CGFloat)] = [
        (-170, -300, 3.5, 1), ( 130, -340, 5.0, -1), ( -90, -200, 2.5,  1),
        ( 190, -220, 4.0,  1), (-210, -120, 3.0, -1), (  70, -420, 2.5,  1),
        (-150,  210, 4.5, -1), ( 210,  160, 3.5,  1), ( -70,  310, 5.0, -1),
        ( 100,  290, 2.5,  1), (-190,   90, 3.5, -1), ( 165,   95, 4.5,  1),
        ( -45,  -55, 2.5,  1), (  55,  -65, 3.5, -1), (-130,   55, 4.0,  1),
        (  85, -160, 2.5, -1), (-205, -265, 3.5,  1), ( 155, -110, 5.0, -1),
        (-105,  185, 2.5,  1), (  25,  360, 3.5,  1),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── 1. Background ──────────────────────────────────────────
                backgroundLayer(geo: geo)

                // ── 2. Floating particles ──────────────────────────────────
                particleLayer

                // ── 3. Main content ────────────────────────────────────────
                VStack(spacing: 0) {
                    Spacer()

                    // Logo + glow zone
                    ZStack {
                        // Outer ambient ring
                        Circle()
                            .strokeBorder(Color.opennoteGreen.opacity(0.14), lineWidth: 1.5)
                            .frame(width: 220, height: 220)
                            .scaleEffect(ringPulse)
                            .opacity(glowOpacity * 0.9)

                        // Inner radial glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.opennoteGreen.opacity(0.28), .clear],
                                    center: .center, startRadius: 0, endRadius: 110
                                )
                            )
                            .frame(width: 240, height: 240)
                            .scaleEffect(glowScale)
                            .opacity(glowOpacity)
                            .blur(radius: 18)

                        // Core bright glow
                        Circle()
                            .fill(Color.opennoteGreen.opacity(0.18))
                            .frame(width: 110, height: 110)
                            .scaleEffect(glowScale)
                            .opacity(glowOpacity)
                            .blur(radius: 24)

                        // Paper airplane ✈
                        Image("logo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 86, height: 86)
                            .foregroundStyle(Color.opennoteGreen)
                            .scaleEffect(planeScale)
                            .rotationEffect(.degrees(planeRotation + floatTilt))
                            .offset(x: planeX, y: planeY + floatY)
                            .opacity(planeOpacity)
                            .shadow(color: Color.opennoteGreen.opacity(0.55),
                                    radius: 28, x: 0, y: 10)
                    }
                    .frame(height: 200)

                    // "Opennote" — large serif headline
                    Text("Opennote")
                        .font(.system(size: 58, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)
                        .padding(.top, 26)

                    // Tagline — lightweight italic subheader
                    Text("The notebook that thinks with you")
                        .font(.system(size: 18, weight: .light, design: .serif))
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(taglineOpacity)
                        .offset(y: taglineOffset)
                        .padding(.top, 12)
                        .padding(.horizontal, 44)

                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity)

                // ── 4. Swipe-up indicator ─────────────────────────────────
                VStack {
                    Spacer()
                    swipeUpIndicator
                        .opacity(max(0, swipeOpacity - dragOffset / 160))
                        .padding(.bottom, 52)
                }
            }
            .offset(y: dragOffset)
            .contentShape(Rectangle())
            .gesture(swipeGesture(screenHeight: geo.size.height))
        }
        .ignoresSafeArea()
        .onAppear { runAnimations() }
    }

    // MARK: - Background

    private func backgroundLayer(geo: GeometryProxy) -> some View {
        ZStack {
            // Base warm cream
            Color.opennoteCream.ignoresSafeArea()

            // Subtle top-to-bottom depth gradient
            LinearGradient(
                colors: [
                    Color.opennoteCream,
                    Color.opennoteCream.opacity(0.92),
                    Color(red: 0.96, green: 0.98, blue: 0.95)   // very faint sage tint at bottom
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Large ambient green halo in the center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.opennoteGreen.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: geo.size.width * 0.75
                    )
                )
                .frame(width: geo.size.width * 2.2, height: geo.size.width * 2.2)
                .opacity(bgGlowOpacity)
        }
    }

    // MARK: - Particles

    private var particleLayer: some View {
        ZStack {
            ForEach(Array(particles.enumerated()), id: \.offset) { idx, p in
                Circle()
                    .fill(Color.opennoteGreen.opacity(0.12 + Double(idx % 3) * 0.04))
                    .frame(width: p.r * 2, height: p.r * 2)
                    .offset(
                        x: p.x,
                        y: p.y + particleDrift * p.dir * CGFloat(0.5 + Double(idx % 4) * 0.15)
                    )
                    .blur(radius: 0.8)
            }
        }
        .animation(
            .easeInOut(duration: 5.5).repeatForever(autoreverses: true),
            value: particleDrift
        )
    }

    // MARK: - Swipe-up indicator

    private var swipeUpIndicator: some View {
        VStack(spacing: 2) {
            // Three staggered chevrons cascading upward
            Image(systemName: "chevron.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.9))
                .offset(y: c0Y)

            Image(systemName: "chevron.up")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.55))
                .offset(y: c1Y)

            Image(systemName: "chevron.up")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.secondary.opacity(0.28))
                .offset(y: c2Y)

            Text("Swipe up to enter")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
    }

    // MARK: - Swipe gesture

    private func swipeGesture(screenHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let t = value.translation.height
                if t < 0 {
                    // Rubber-band resistance: eases as the user pulls further
                    dragOffset = t * 0.38
                }
            }
            .onEnded { value in
                let dy = value.translation.height
                let vy = value.predictedEndTranslation.height
                if dy < -65 || vy < -180 {
                    // Dismiss — curtain flies upward
                    Haptics.impact(.medium)
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.85)) {
                        dragOffset = -screenHeight * 1.15
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                        onComplete()
                    }
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Animation sequence

    private func runAnimations() {
        // ── Phase 0: Plane appears (instant) ─────────────────────────────
        planeOpacity = 1

        // ── Phase 1: Plane flies in (diagonal arc from bottom-left) ──────
        withAnimation(.spring(response: 0.92, dampingFraction: 0.68).delay(0.05)) {
            planeX = 0
            planeScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.80).delay(0.05)) {
            planeY = 0
            planeRotation = -12          // settles to gentle upward tilt
        }

        // ── Phase 2: Background halo fades in ────────────────────────────
        withAnimation(.easeIn(duration: 0.7).delay(0.55)) {
            bgGlowOpacity = 1
        }

        // ── Phase 3: Logo glow expands on landing ─────────────────────────
        withAnimation(.spring(response: 0.65, dampingFraction: 0.65).delay(0.88)) {
            glowScale = 1.0
            glowOpacity = 1.0
        }

        // ── Phase 4: "Opennote" slides up ─────────────────────────────────
        withAnimation(.spring(response: 0.58, dampingFraction: 0.78).delay(1.0)) {
            titleOpacity = 1
            titleOffset = 0
        }

        // ── Phase 5: Tagline fades in ─────────────────────────────────────
        withAnimation(.easeOut(duration: 0.55).delay(1.25)) {
            taglineOpacity = 1
            taglineOffset = 0
        }

        // ── Phase 6: Swipe indicator appears ──────────────────────────────
        withAnimation(.easeIn(duration: 0.5).delay(1.65)) {
            swipeOpacity = 1
        }

        // ── Phase 7: Idle float loop (starts after landing) ───────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                floatY = -16
                floatTilt = 9
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowScale = 1.14
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                ringPulse = 1.18
            }
        }

        // ── Phase 8: Chevron cascade wave ────────────────────────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.60).repeatForever(autoreverses: true).delay(0.00)) {
                c0Y = -9
            }
            withAnimation(.easeInOut(duration: 0.60).repeatForever(autoreverses: true).delay(0.14)) {
                c1Y = -9
            }
            withAnimation(.easeInOut(duration: 0.60).repeatForever(autoreverses: true).delay(0.28)) {
                c2Y = -9
            }
        }

        // ── Phase 9: Particle drift ───────────────────────────────────────
        withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
            particleDrift = 45
        }
    }
}

#Preview {
    AppLoadView(onComplete: {})
}

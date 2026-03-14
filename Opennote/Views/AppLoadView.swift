import SwiftUI

/// Minimal load screen: paper airplane + Opennote. Shown when re-opening the app. Swipe up to continue.
struct AppLoadView: View {
    let onComplete: () -> Void
    @State private var swayAngle: Double = -7

    var body: some View {
        ZStack {
            Color.opennoteCream
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 80) {
                    HStack(spacing: 12) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(swayAngle))
                        Text("Opennote")
                            .font(.system(size: 28, weight: .regular, design: .serif))
                            .foregroundStyle(.primary)
                    }
                    Text("The notebook that thinks\nwith you")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                Spacer(minLength: 100)
                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height < -50 {
                        Haptics.impact(.light)
                        onComplete()
                    }
                }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                swayAngle = 7
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onComplete()
            }
        }
    }
}

#Preview {
    AppLoadView(onComplete: {})
}

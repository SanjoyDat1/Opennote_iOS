import SwiftUI

/// Polished animated load screen - paper airplane flies in with dotted path, then auto-transitions.
struct SplashView: View {
    let onComplete: () -> Void
    
    @State private var planeOffset: CGFloat = -320
    @State private var planeOpacity: Double = 0
    @State private var pathRevealProgress: Double = 0
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.92
    
    private let pathDots: Int = 14
    
    var body: some View {
        ZStack {
            // Subtle warm gradient for depth
            LinearGradient(
                colors: [Color.opennoteCream, Color.opennoteCream.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Flight path + airplane - dots trail behind plane
                ZStack(alignment: .trailing) {
                    HStack(spacing: 6) {
                        ForEach(0..<pathDots, id: \.self) { i in
                            Circle()
                                .fill(Color.opennoteCreamDark.opacity(0.65))
                                .frame(width: 6, height: 6)
                                .opacity(pathRevealProgress > Double(i) / Double(pathDots) ? 1 : 0.25)
                        }
                        Spacer(minLength: 16)
                    }
                    .padding(.trailing, 10)
                    
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .foregroundStyle(Color.opennoteCreamDark)
                        .rotationEffect(.degrees(-42))
                        .offset(x: planeOffset)
                        .opacity(planeOpacity)
                        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                }
                .frame(height: 88)
                .frame(maxWidth: .infinity)
                
                // Logo with refined typography
                Text("Opennote")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
                    .padding(.top, 28)
                
                Spacer()
                Spacer(minLength: 60)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            // Phase 1: Plane flies in smoothly
            withAnimation(.easeOut(duration: 1.0)) {
                planeOffset = 0
                planeOpacity = 1
            }
            // Phase 2: Dots reveal along path (staggered)
            withAnimation(.easeInOut(duration: 0.6).delay(0.25)) {
                pathRevealProgress = 1
            }
            // Phase 3: Logo fades in with subtle scale
            withAnimation(.easeOut(duration: 0.55).delay(0.85)) {
                logoOpacity = 1
                logoScale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                onComplete()
            }
        }
    }
}

#Preview {
    SplashView(onComplete: {})
}

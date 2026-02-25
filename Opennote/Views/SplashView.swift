import SwiftUI

struct SplashView: View {
    let onSkip: () -> Void
    
    var body: some View {
        ZStack {
            Color.opennoteCream
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Spacer()
                
                // Paper airplane icon + Opennote text (centered)
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text("Opennote")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        onSkip()
                    }
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
    }
}

#Preview {
    SplashView(onSkip: {})
}

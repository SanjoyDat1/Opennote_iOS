import SwiftUI

/// Minimal load screen: paper airplane + Opennote. Shown when re-opening the app.
struct AppLoadView: View {
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.opennoteCream
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                HStack(spacing: 12) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.primary)
                    Text("Opennote")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                Spacer(minLength: 80)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                onComplete()
            }
        }
    }
}

#Preview {
    AppLoadView(onComplete: {})
}

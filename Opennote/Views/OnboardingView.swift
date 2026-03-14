import SwiftUI

struct OnboardingView: View {
    let onComplete: (String?) -> Void

    var body: some View {
        ZStack {
            Color.opennoteCream
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer(minLength: 0)

                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)

                Text("Welcome to Opennote")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Your notes, simplified.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    Haptics.impact(.medium)
                    onComplete(nil)
                } label: {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.opennoteGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: { _ in })
}

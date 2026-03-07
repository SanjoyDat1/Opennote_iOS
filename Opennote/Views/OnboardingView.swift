import SwiftUI

struct OnboardingView: View {
    let onComplete: (String?) -> Void
    @State private var selectedSource: String?
    
    private let referralOptions = [
        "Google search",
        "TikTok",
        "Instagram",
        "YouTube",
        "Friend/colleague recommendation",
        "Reddit",
        "Discord",
        "Twitter/X",
        "Professor/teacher",
        "University website",
        "Other"
    ]
    
    private let totalSteps = 8
    @State private var currentStep = 0
    
    var body: some View {
        ZStack {
            Color.opennoteCream
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        Text("How did you hear about Opennote?")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                            .padding(.top, 40)
                        
                        // 2-column grid with fixed-height cards
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(referralOptions, id: \.self) { option in
                                OnboardingOptionCard(
                                    title: option,
                                    isSelected: selectedSource == option,
                                    onTap: { selectedSource = option }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Help link
                        Button {
                            Haptics.impact(.light)
                            if let url = URL(string: "https://opennote.com") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Want more help? ")
                                .foregroundStyle(.secondary)
                            + Text("Check out the Opennote guide")
                                .foregroundStyle(Color.opennoteGreen)
                                .underline()
                        }
                        .font(.system(.body, design: .default))
                        .padding(.bottom, 24)
                    }
                }
                
                // Bottom: evenly spaced Back, dots, Get Started
                HStack(spacing: 0) {
                    Button {
                        Haptics.impact(.light)
                        if currentStep > 0 {
                            currentStep -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        ForEach(0..<totalSteps, id: \.self) { index in
                            Circle()
                                .fill(index <= currentStep ? Color.opennoteGreen : Color(.systemGray4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Get Started") {
                        Haptics.impact(.medium)
                        onComplete(selectedSource)
                    }
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.opennoteGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color.opennoteCream)
            }
        }
    }
}

struct OnboardingOptionCard: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    private let cardHeight: CGFloat = 56
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                Spacer(minLength: 8)
                
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.opennoteGreen)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView(onComplete: { _ in })
}

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
            
            VStack(spacing: 24) {
                Text("How did you hear about Opennote?")
                    .opennoteMajorHeader()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 40)
                
                // 2-column grid of selectable cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(referralOptions, id: \.self) { option in
                        OnboardingOptionCard(
                            title: option,
                            isSelected: selectedSource == option,
                            onTap: {
                                selectedSource = option
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                // Help link
                Button {
                    // TODO: Open Opennote guide
                } label: {
                    Text("Want more help? ")
                        .foregroundStyle(.secondary)
                    + Text("Check out the Opennote guide")
                        .foregroundStyle(.primary)
                        .underline()
                }
                .font(.system(.body, design: .default))
                
                Spacer()
                
                // Bottom: Back, progress dots, Get Started
                VStack(spacing: 16) {
                    HStack {
                        Button {
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
                        
                        // Progress dots (8 steps, green for active)
                        HStack(spacing: 6) {
                            ForEach(0..<totalSteps, id: \.self) { index in
                                Circle()
                                    .fill(index <= currentStep ? Color.opennoteGreen : Color(.systemGray4))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Get Started") {
                            onComplete(selectedSource)
                        }
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.opennoteGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

struct OnboardingOptionCard: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
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
            .padding(16)
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

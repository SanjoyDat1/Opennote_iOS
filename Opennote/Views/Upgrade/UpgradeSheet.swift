import SwiftUI

/// Subscription upgrade sheet - Explorer & Scholar tiers. Not functional; confetti on selection.
struct UpgradeSheet: View {
    @Binding var isPresented: Bool
    @State private var isMonthly = true
    @State private var selectedTier: Tier? = nil
    @State private var showConfetti = false

    enum Tier: String {
        case explorer = "Explorer"
        case scholar = "Scholar"
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)

                    // Header
                    VStack(spacing: 8) {
                        Text("Upgrade to unlock the proactive AI thinking partner")
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                        Text("Get real-time, intelligent assistance as you take notes")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)

                    // Monthly/Yearly toggle
                    HStack(spacing: 0) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isMonthly = true }
                        } label: {
                            Text("Monthly")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(isMonthly ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isMonthly ? Color(.systemGray5) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isMonthly = false }
                        } label: {
                            Text("Yearly")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(isMonthly ? .secondary : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isMonthly ? Color.clear : Color(.systemGray5))
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)

                    // Explorer tier
                    tierCard(
                        name: "Explorer",
                        tagline: "For dedicated learners",
                        tag: "Most Popular",
                        price: "$12.50",
                        features: [
                            "Unlimited AI chat",
                            "5 lecture transcriptions / day",
                            "5 flashcard & practice sets / day",
                            "3 video generations / day"
                        ],
                        tier: .explorer,
                        showEducationBanner: true,
                        isSelected: selectedTier == .explorer
                    )

                    // Scholar tier
                    tierCard(
                        name: "Scholar",
                        tagline: "For the most ambitious achievers",
                        tag: nil,
                        price: "$20.83",
                        features: [
                            "Everything in Explorer +",
                            "Real-time proactive AI thinking partner",
                            "Unlimited transcriptions",
                            "Unlimited flashcards & practice problems",
                            "Unlimited video generations"
                        ],
                        tier: .scholar,
                        showEducationBanner: true,
                        isSelected: selectedTier == .scholar
                    )

                    // Get Scholar button
                    Button {
                        Haptics.impact(.medium)
                        selectedTier = .scholar
                        showConfetti = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isPresented = false
                        }
                    } label: {
                        Text("Get Scholar")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }

    private func tierCard(
        name: String,
        tagline: String,
        tag: String?,
        price: String,
        features: [String],
        tier: Tier,
        showEducationBanner: Bool,
        isSelected: Bool = false
    ) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTier = tier
            }
            showConfetti = true
        } label: {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.system(size: 20, weight: .bold))
                            Text(tagline)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.opennoteLightGreen.opacity(0.6))
                    }

                    if showEducationBanner {
                        HStack(spacing: 6) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 14))
                            Text("Use an education email and get 20% off!")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text(price)
                            .font(.system(size: 28, weight: .bold))
                        Text("/month")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(features, id: \.self) { f in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                Text(f)
                                    .font(.system(size: 15))
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.black : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if let tag = tag {
                    Text(tag)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .offset(x: 16, y: -10)
                }

                Circle()
                    .stroke(Color(.systemGray2), lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(16)
            }
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Confetti View

private struct ConfettiView: View {
    @State private var fell = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<50, id: \.self) { i in
                    ConfettiPiece(
                        screenHeight: geo.size.height,
                        screenWidth: geo.size.width,
                        index: i,
                        fell: fell
                    )
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 2.0)) {
                    fell = true
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct ConfettiPiece: View {
    let screenHeight: CGFloat
    let screenWidth: CGFloat
    let index: Int
    let fell: Bool

    private static let colors: [Color] = [
        Color(red: 0.37, green: 0.62, blue: 0.39),  // opennote green
        .orange, .yellow, .red, .blue, .purple
    ]

    var body: some View {
        let seed = Double(index) * 1.3
        let x = CGFloat((sin(seed * 7) + 1) / 2) * screenWidth
        let startY: CGFloat = -20
        let endY = screenHeight + 50
        let rotation = fell ? 720.0 : 0
        let color = Self.colors[index % Self.colors.count]

        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 8, height: 12)
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: fell ? endY : startY)
            .animation(
                .easeIn(duration: 1.8)
                .delay(Double(index % 10) * 0.02),
                value: fell
            )
    }
}

#Preview {
    UpgradeSheet(isPresented: .constant(true))
}

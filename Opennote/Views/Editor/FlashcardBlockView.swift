import SwiftUI

struct FlashcardBlockView: View {
    let items: [FlashcardItem]
    let blockId: UUID
    @Binding var focusedBlockId: UUID?
    let onUpdate: ([FlashcardItem]) -> Void
    let onGenerate: () -> Void
    var isGenerating: Bool = false

    @State private var currentIndex = 0
    @State private var isFlipped = false

    private var isEmpty: Bool { items.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            flashcardHeader
            flashcardContent
        }
        .padding(12)
        .background(Color.opennoteLightGreen.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var flashcardHeader: some View {
        HStack {
            Image(systemName: "rectangle.stack.fill.badge.plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.opennoteGreen)
            Text("Flashcards")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
            if isEmpty {
                flashcardGenerateButton
            }
        }
    }

    @ViewBuilder
    private var flashcardGenerateButton: some View {
        Button {
            Haptics.impact(.light)
            onGenerate()
        } label: {
            if isGenerating {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Generate with AI")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color.opennoteGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.opennoteLightGreen)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }

    @ViewBuilder
    private var flashcardContent: some View {
        if isEmpty && !isGenerating {
            Text("Generate flashcards from your notes using Feynman AI")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else if !items.isEmpty {
            VStack(spacing: 12) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        FlashcardCardView(
                            front: item.front,
                            back: item.back
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(minHeight: 140)

                HStack {
                    Text("\(currentIndex + 1) / \(items.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct FlashcardCardView: View {
    let front: String
    let back: String
    @State private var isFlipped = false

    var body: some View {
        Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.3)) { isFlipped.toggle() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

                VStack(spacing: 8) {
                    if !isFlipped {
                        Text("Front")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(front)
                            .font(.system(size: 16, design: .default))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Back")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(back)
                            .font(.system(size: 16, design: .default))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }
}

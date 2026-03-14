import SwiftUI

struct PracticeProblemsBlockView: View {
    let items: [PracticeProblemItem]
    let blockId: UUID
    @Binding var focusedBlockId: UUID?
    let onUpdate: ([PracticeProblemItem]) -> Void
    let onGenerate: () -> Void
    var isGenerating: Bool = false

    @State private var expandedId: UUID?

    private var isEmpty: Bool { items.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            contentView
        }
        .padding(12)
        .background(Color.opennoteLightGreen.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.opennoteGreen)
            Text("Practice Problems")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
            if isEmpty {
                generateButton
            }
        }
    }

    @ViewBuilder
    private var generateButton: some View {
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
    private var contentView: some View {
        if isEmpty && !isGenerating {
            Text("Generate practice problems from your notes using Feynman AI")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else if !items.isEmpty {
            VStack(spacing: 8) {
                ForEach(items) { item in
                    PracticeProblemRowView(
                        item: item,
                        isExpanded: expandedId == item.id,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedId = expandedId == item.id ? nil : item.id
                            }
                        }
                    )
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct PracticeProblemRowView: View {
    let item: PracticeProblemItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(item.question)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if isExpanded {
                    Text(item.answer)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.leading, 20)
                        .padding(.top, 4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

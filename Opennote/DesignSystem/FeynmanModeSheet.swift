import SwiftUI

/// Full mode-picker sheet — Auto as hero card, three specific modes below.
struct FeynmanModeSheet: View {
    @Binding var selectedMode: FeynmanMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Feynman Mode")
                        .font(.title3.weight(.semibold))
                    Text("How should Feynman respond?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Haptics.impact(.light)
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.opennoteGreen)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 18)

            // ── Auto hero card ────────────────────────────────────────────────
            autoCard
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            // ── Section label ─────────────────────────────────────────────────
            Text("Or lock in a specific style")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            // ── Three mode rows ───────────────────────────────────────────────
            VStack(spacing: 0) {
                ForEach(Array(specificModes.enumerated()), id: \.element.id) { idx, mode in
                    modeRow(mode)
                    if idx < specificModes.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
    }

    private var specificModes: [FeynmanMode] {
        FeynmanMode.allCases.filter { $0 != .auto }
    }

    // MARK: Auto hero card

    private var autoCard: some View {
        let isSelected = selectedMode == .auto
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.22)) { selectedMode = .auto }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { dismiss() }
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.opennoteGreen : Color(.systemGray5))
                        .frame(width: 46, height: 46)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color(.systemGray))
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("Auto")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Recommended")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.opennoteGreen)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.opennoteGreen.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text("Feynman reads your question and silently picks\nSocratic, Direct, or Explain — whatever fits best.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.opennoteGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                isSelected
                    ? Color.opennoteGreen.opacity(0.07)
                    : Color(.systemGray6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.opennoteGreen.opacity(0.35) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.spring(response: 0.22), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: Mode row

    @ViewBuilder
    private func modeRow(_ mode: FeynmanMode) -> some View {
        let isSelected = selectedMode == mode
        Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.22)) { selectedMode = mode }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { dismiss() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.opennoteGreen.opacity(0.15) : Color.opennoteGreen.opacity(0.07))
                        .frame(width: 36, height: 36)
                    Image(systemName: mode.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.opennoteGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.opennoteGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                isSelected ? Color.opennoteGreen.opacity(0.05) : Color.clear
            )
            .animation(.spring(response: 0.22), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

/// Sheet for selecting Feynman response mode. Liquid glass design, half-sheet presentation.
struct FeynmanModeSheet: View {
    @Binding var selectedMode: FeynmanMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Feynman Mode")
                        .font(.title3.weight(.semibold))
                    Text("Changes how Feynman thinks with you")
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
            .padding(.bottom, 16)

            // Mode options card
            VStack(spacing: 0) {
                ForEach(Array(FeynmanMode.allCases.enumerated()), id: \.element.id) { index, mode in
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.2)) {
                            selectedMode = mode
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.opennoteGreen.opacity(selectedMode == mode ? 0.15 : 0.08))
                                    .frame(width: 36, height: 36)
                                Image(systemName: mode.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.opennoteGreen)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.body.weight(selectedMode == mode ? .semibold : .regular))
                                    .foregroundStyle(.primary)
                                Text(mode.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if selectedMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.opennoteGreen)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            selectedMode == mode
                                ? Color.opennoteGreen.opacity(0.06)
                                : Color.clear
                        )
                        .animation(.spring(response: 0.2), value: selectedMode)
                    }
                    .buttonStyle(.plain)

                    if index < FeynmanMode.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 66)
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
    }
}

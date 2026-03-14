import SwiftUI

/// A keyboard accessory toolbar that sits flush above the iOS keyboard.
/// Matches the system keyboard chrome — no card, shadow, or floating styling.
/// Use with `ToolbarItemGroup(placement: .keyboard)`.
struct KeyboardDismissAccessory: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                Haptics.selection()
                onDismiss()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.keyboardAccessoryIcon)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss keyboard")
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Color.keyboardAccessoryBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.keyboardAccessoryBorder)
                .frame(height: 1)
        }
    }
}

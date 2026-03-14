import SwiftUI
import UIKit

/// Thin keyboard accessory shown when editing journal body.
/// Green chevron-only dismiss button, matches keyboard gray background.
/// Used when keyboardState == .journalFocused — Feynman bar is fully hidden.
struct JournalKeyboardAccessory: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button {
                Haptics.selection()
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                onDismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.opennoteGreen)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss keyboard")
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color(UIColor.systemGray6))
    }
}

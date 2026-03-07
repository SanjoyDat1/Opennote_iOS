import SwiftUI

struct DividerBlockView: View {
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 1)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
    }
}

import SwiftUI

/// Multi-modal: Graph block - enter equation and open in Desmos.
struct GraphBlockView: View {
    let expression: String
    let blockId: UUID
    @FocusState.Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void
    
    private var desmosURL: URL? {
        URL(string: "https://www.desmos.com/calculator")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "function")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.opennoteGreen)
                TextField("e.g. y=x^2 or sin(x)", text: Binding(get: { expression }, set: { onUpdate($0) }))
                    .focused($focusedBlockId, equals: blockId)
                    .font(.system(.body, design: .default))
            }
            .padding(12)
            .background(Color.opennoteLightGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if let url = desmosURL {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 16))
                        Text("Open in Desmos")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color.opennoteGreen)
                }
            }
        }
    }
}

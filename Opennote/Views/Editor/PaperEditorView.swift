import SwiftUI

/// Paper editor for LaTeX content - raw text editing with syntax-friendly layout.
struct PaperEditorView: View {
    let paper: Paper
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        ZStack {
            Color.opennoteCream
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Text(paper.title)
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .lineLimit(1)
                    Spacer()
                    Button("Share") { }
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.opennoteGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.opennoteCream)

                TextEditor(text: $content)
                    .font(.system(size: 15, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .focused($isEditorFocused)
                    .padding(20)
                    .scrollDismissesKeyboard(.interactively)
                    .background(Color.white)
                    .overlay(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("Start writing LaTeX...")
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(24)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

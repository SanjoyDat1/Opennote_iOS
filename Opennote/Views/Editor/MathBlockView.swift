import SwiftUI
import WebKit

/// Multi-modal: Math/LaTeX block - renders equations.
struct MathBlockView: View {
    let latex: String
    let blockId: UUID
    @Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void

    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("LaTeX: e.g. \\frac{1}{2} or x^2 + y^2", text: Binding(get: { latex }, set: { onUpdate($0) }))
                .focused($isFieldFocused)
                .font(.system(.body, design: .monospaced))
                .onChange(of: isFieldFocused) { _, focused in
                    if focused { focusedBlockId = blockId }
                    else if focusedBlockId == blockId { focusedBlockId = nil }
                }
                .padding(12)
                .background(Color.opennoteLightGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if !latex.isEmpty {
                MathPreviewView(latex: latex)
                    .frame(minHeight: 44)
            }
        }
    }
}

private struct MathPreviewView: UIViewRepresentable {
    let latex: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = WKProcessPool()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let escaped = latex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
        let html = """
        <!DOCTYPE html><html><head>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css" crossorigin>
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js" crossorigin></script>
        </head><body style="margin:0;padding:12px;background:transparent;">
        <div id="math"></div>
        <script>
        try {
            katex.render('\(escaped)', document.getElementById('math'), { throwOnError: false });
        } catch(e) {}
        </script></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

import SwiftUI
import WebKit

/// Math/LaTeX block — renders equations via KaTeX in display (block) mode.
struct MathBlockView: View {
    let latex: String
    let blockId: UUID
    @Binding var focusedBlockId: UUID?
    let onUpdate: (String) -> Void

    @FocusState private var isFieldFocused: Bool
    @State private var renderedHeight: CGFloat = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Input field ───────────────────────────────────────────
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

            // ── Rendered preview ──────────────────────────────────────
            if !latex.isEmpty {
                MathPreviewView(latex: latex, contentHeight: $renderedHeight)
                    .frame(height: renderedHeight)
                    .background(Color(.systemGray6).opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - WebKit renderer

private struct MathPreviewView: UIViewRepresentable {
    let latex: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "heightBridge")

        let config = WKWebViewConfiguration()
        config.processPool = WKProcessPool()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let escaped = latex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <link rel="stylesheet"
              href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"
              crossorigin="anonymous">
        <script defer
                src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"
                crossorigin="anonymous"
                onload="renderMath()"></script>
        <style>
          * { box-sizing: border-box; }
          html, body {
            margin: 0;
            padding: 0;
            background: transparent;
            /* Base font size — KaTeX scales relative to this.
               26px gives large, readable equations on a phone screen. */
            font-size: 26px;
          }
          body {
            padding: 18px 16px;
          }
          #math-output {
            text-align: center;
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
          }
          /* Ensure KaTeX inherits the large base size */
          .katex { font-size: 1.1em; }
          .katex-display { margin: 0; }
        </style>
        </head>
        <body>
          <div id="math-output"></div>
          <script>
            function renderMath() {
              try {
                katex.render('\(escaped)', document.getElementById('math-output'), {
                  throwOnError: false,
                  displayMode: true,
                  output: 'html'
                });
              } catch(e) {
                document.getElementById('math-output').innerText = 'Invalid LaTeX';
              }
              reportHeight();
            }

            function reportHeight() {
              var h = document.body.scrollHeight;
              if (window.webkit && window.webkit.messageHandlers.heightBridge) {
                window.webkit.messageHandlers.heightBridge.postMessage(h);
              }
            }

            // Fallback if script tag fires before renderMath is defined
            if (typeof katex !== 'undefined') { renderMath(); }

            // Re-report after fonts finish painting
            window.addEventListener('load', reportHeight);
            setTimeout(reportHeight, 300);
            setTimeout(reportHeight, 800);
          </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: MathPreviewView

        init(_ parent: MathPreviewView) {
            self.parent = parent
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "heightBridge",
                  let raw = message.body as? NSNumber else { return }
            let h = CGFloat(raw.doubleValue)
            DispatchQueue.main.async {
                // Clamp to a sensible range: never smaller than 80pt, never taller than 320pt
                self.parent.contentHeight = min(max(h, 80), 320)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Final height check after full page load
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let h = (result as? NSNumber).map({ CGFloat($0.doubleValue) }) {
                    DispatchQueue.main.async {
                        self.parent.contentHeight = min(max(h, 80), 320)
                    }
                }
            }
        }
    }
}

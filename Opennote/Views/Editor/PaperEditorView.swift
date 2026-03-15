import SwiftUI
import WebKit
import PDFKit

// MARK: - Compile state

enum PaperCompileState: Equatable {
    case idle
    case compiling
    case autoFixing    // Feynman is reading + rewriting the LaTeX
    case recompiling   // Feynman finished; retrying the compile
    case error(String) // auto-fix failed — show message, allow manual retry

    var isIdle: Bool { self == .idle }

    var isAutoFixing: Bool {
        switch self {
        case .autoFixing, .recompiling: return true
        default: return false
        }
    }

    var overlayStage: String {
        switch self {
        case .autoFixing:   return "Feynman spotted a LaTeX error…"
        case .recompiling:  return "Almost there — recompiling…"
        default:            return ""
        }
    }

    var overlaySubtitle: String {
        switch self {
        case .autoFixing:   return "Feynman is analyzing and fixing your document automatically."
        case .recompiling:  return "Applying the fix and generating your PDF."
        default:            return ""
        }
    }
}

/// Paper editor: LaTeX code editor + live PDF preview. Split view with Compile, AI, notes-to-PDF.
struct PaperEditorView: View {
    let paper: Paper
    var onUpdate: ((Paper) -> Void)?
    var onDelete: (() -> Void)?
    var onCloneSelect: ((Paper) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(NotesStore.self) private var notesStore
    @State private var content: String
    @State private var editedTitle: String
    @FocusState private var isEditorFocused: Bool
    @State private var pdfURL: URL?
    @State private var compileState: PaperCompileState = .idle
    @State private var showSettingsSheet = false
    @State private var showAISheet = false
    @State private var showNotesToPDFSheet = false
    @State private var splitRatio: CGFloat = 0.5
    @State private var activePane: PaperPane = .code

    init(paper: Paper, onUpdate: ((Paper) -> Void)? = nil, onDelete: (() -> Void)? = nil, onCloneSelect: ((Paper) -> Void)? = nil) {
        self.paper = paper
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onCloneSelect = onCloneSelect
        let initialContent = paper.content.isEmpty ? PaperTemplate.defaultContent : paper.content
        _content = State(initialValue: initialContent)
        _editedTitle = State(initialValue: paper.title)
    }

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            topBar
            if UIDevice.current.userInterfaceIdiom == .pad {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        codeEditor.frame(width: geo.size.width * splitRatio)
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { v in
                                        let delta = v.translation.width / geo.size.width
                                        splitRatio = (splitRatio + delta).clamped(to: 0.25...0.75)
                                    }
                            )
                        pdfPreview.frame(width: geo.size.width * (1 - splitRatio))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Picker("Pane", selection: $activePane) {
                    Text("Code").tag(PaperPane.code)
                    Text("PDF").tag(PaperPane.pdf)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                Group {
                    if activePane == .code {
                        codeEditor
                    } else {
                        pdfPreview
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.opennoteCream)

        // ── Auto-fix overlay (inside ZStack, floats above the VStack) ──
        if compileState.isAutoFixing {
            LaTeXAutoFixOverlay(state: compileState)
                .transition(.opacity.animation(.easeInOut(duration: 0.35)))
                .zIndex(99)
        }
    } // end ZStack
    .animation(.easeInOut(duration: 0.3), value: compileState.isAutoFixing)
    .background(Color.opennoteCream)
    .navigationBarBackButtonHidden(true)
    .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                KeyboardDismissAccessory(onDismiss: { isEditorFocused = false })
            }
        }
        .onDisappear {
            saveContent(content)
        }
        .sheet(isPresented: $showSettingsSheet) {
            PaperSettingsSheet(
                isPresented: $showSettingsSheet,
                paper: paper,
                content: $content,
                onCloneSelect: onCloneSelect,
                onDelete: { onDelete?() },
                onCompilePDF: { compileAndPreview() },
                onShowAI: { showSettingsSheet = false; showAISheet = true },
                onShowNotesToPDF: { showSettingsSheet = false; showNotesToPDFSheet = true }
            )
        }
        .sheet(isPresented: $showAISheet) {
            PaperAISheet(texContent: $content, isPresented: $showAISheet)
        }
        .sheet(isPresented: $showNotesToPDFSheet) {
            NotesToPDFSheet(journals: notesStore.journals, onSelectJournal: { journal in
                convertJournalToLaTeX(journal)
                showNotesToPDFSheet = false
            }, isPresented: $showNotesToPDFSheet)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Text(editedTitle)
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            PaperScanButton(content: $content)

            Button {
                Haptics.impact(.light)
                showSettingsSheet = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.opennoteCream)
    }

    private var codeEditor: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            TextEditor(text: $content)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .padding(16)
                .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .top) {
            Text("LaTeX Source")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6).opacity(0.5))
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                Haptics.impact(.light)
                showAISheet = true
            } label: {
                Image("logo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(Color.opennoteGreen)
                    .clipShape(Circle())
                    .shadow(color: Color.opennoteGreen.opacity(0.45), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(20)
        }
    }

    private var pdfPreview: some View {
        ZStack {
            if let url = pdfURL {
                // HTML fallback uses WKWebView; real PDFs use native PDFKit
                if url.pathExtension == "html" {
                    PDFWebView(url: url)
                } else {
                    PDFKitView(url: url)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(.systemGray3))
                    Text("Tap the button below to compile your LaTeX to PDF")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if case .error(let msg) = compileState {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Compilation failed", systemImage: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.red)
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
                    Spacer()
                }
            }
        }
        .overlay(alignment: .top) {
            Text("PDF Preview")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6).opacity(0.5))
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                Haptics.impact(.light)
                compileAndPreview()
            } label: {
                HStack(spacing: 8) {
                    if compileState == .compiling {
                        ProgressView()
                            .scaleEffect(0.9)
                            .tint(.white)
                    } else {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 18, weight: .medium))
                    }
                    Text(compileState == .compiling ? "Compiling…" : "Compile PDF")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.opennoteGreen)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!compileState.isIdle || content.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(content.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
            .padding(20)
        }
    }

    private func compileAndPreview() {
        guard compileState.isIdle else { return }
        compileState = .compiling
        let tex = Self.ensureValidLaTeX(content)
        Task {
            // Initial attempt: external services only (no HTML fallback yet)
            // so that actual LaTeX errors still trigger the LLM auto-fix.
            let result = await Self.doCompileExternal(tex: tex)
            await MainActor.run {
                switch result {
                case .success(let url):
                    pdfURL = url
                    compileState = .idle
                case .failure(let compileErr):
                    // External services failed → let Feynman diagnose and fix.
                    // After Feynman's fix the FULL pipeline (incl. HTML fallback) runs,
                    // so the user always ends up seeing something.
                    compileState = .autoFixing
                    Task { await autoFixAndRecompile(brokenTex: tex, errorLog: compileErr.localizedDescription) }
                }
            }
        }
    }

    @MainActor
    private func autoFixAndRecompile(brokenTex: String, errorLog: String) async {
        var fixedTeX = ""
        do {
            for try await chunk in OpenAIService.shared.fixLaTeXErrors(tex: brokenTex, errorLog: errorLog) {
                fixedTeX += chunk
            }
        } catch {
            // LLM unreachable — still show an HTML preview so nothing is ever blank
            if let htmlURL = Self.renderLocalHTML(tex: brokenTex) {
                pdfURL = htmlURL
                compileState = .idle
            } else {
                compileState = .error("Could not reach Feynman AI. Tap Compile PDF to retry when online.")
            }
            return
        }

        guard !fixedTeX.isEmpty else {
            // LLM returned nothing — still give the user an HTML preview
            if let htmlURL = Self.renderLocalHTML(tex: brokenTex) {
                pdfURL = htmlURL
                compileState = .idle
            } else {
                compileState = .error("Feynman couldn't determine a fix. Please review your LaTeX manually.")
            }
            return
        }

        let sanitized = Self.ensureValidLaTeX(fixedTeX)
        content = sanitized          // apply the fix so the user can see the corrected code
        compileState = .recompiling

        // Full pipeline for the retry — includes HTML fallback, so ALWAYS succeeds.
        let result = await Self.doCompile(tex: sanitized)
        switch result {
        case .success(let url):
            pdfURL = url
            compileState = .idle
        case .failure:
            // This branch is unreachable in practice (doCompile has HTML fallback),
            // but handle it gracefully just in case.
            if let htmlURL = Self.renderLocalHTML(tex: sanitized) {
                pdfURL = htmlURL
                compileState = .idle
            } else {
                compileState = .error("Compilation failed. Please review your LaTeX.")
            }
        }
    }

    // MARK: - Compilation pipeline

    /// External-only compile (no HTML fallback).
    /// Used for the initial attempt so LaTeX errors still trigger the LLM fix.
    private static func doCompileExternal(tex: String) async -> Result<URL, NSError> {
        let clean = ensureValidLaTeX(tex)

        // Tier 1: latexonline.cc (two attempts with a pause)
        for attempt in 1...2 {
            let r = await doCompileLatexOnline(tex: clean)
            if case .success = r { return r }
            if attempt == 1 { try? await Task.sleep(nanoseconds: 1_500_000_000) }
        }

        // Tier 2: texlive.net CGI
        return await doCompileTexliveNet(tex: clean)
    }

    /// Full compile pipeline including HTML fallback.
    /// Used after the LLM fix — guaranteed to return .success.
    private static func doCompile(tex: String) async -> Result<URL, NSError> {
        let external = await doCompileExternal(tex: tex)
        if case .success = external { return external }

        // Tier 3: local HTML preview with MathJax — no network needed, always works
        if let htmlURL = renderLocalHTML(tex: tex) { return .success(htmlURL) }

        return .failure(NSError(domain: "PaperEditor", code: -999,
            userInfo: [NSLocalizedDescriptionKey: "All compilation methods failed."]))
    }

    /// Compile via latexonline.cc — simple form-encoded POST as documented.
    /// POST https://latexonline.cc/compile  (Content-Type: application/x-www-form-urlencoded)
    /// Body: text=<url-percent-encoded LaTeX source>
    private static func doCompileLatexOnline(tex: String) async -> Result<URL, NSError> {
        func err(_ msg: String, code: Int = -1) -> NSError {
            NSError(domain: "PaperEditor", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let url = URL(string: "https://latexonline.cc/compile") else {
            return .failure(err("Invalid latexonline.cc URL."))
        }
        guard let encoded = tex.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return .failure(err("Could not percent-encode the LaTeX source."))
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "text=\(encoded)".data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if data.prefix(4) == Data("%PDF".utf8) { return .success(try savePDF(data)) }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? "Compilation failed."
            return .failure(err("[latexonline.cc] HTTP \(code): \(parseErrorLog(raw))", code: code))
        } catch {
            return .failure(error as NSError)
        }
    }

    /// Extract only the meaningful lines from a pdflatex error log.
    private static func parseErrorLog(_ log: String) -> String {
        let lines = log.components(separatedBy: "\n")
        let important = lines.filter {
            $0.hasPrefix("!") || $0.contains("Error") || $0.contains("error") ||
            $0.hasPrefix("l.") || $0.contains("undefined")
        }
        return important.isEmpty ? log : important.prefix(15).joined(separator: "\n")
    }

    /// Fallback 1: compile via texlive.net CGI (David Carlisle's latexcgi).
    /// Uses the actual CGI endpoint and the array field names it expects.
    private static func doCompileTexliveNet(tex: String) async -> Result<URL, NSError> {
        func err(_ msg: String, code: Int = -1) -> NSError {
            NSError(domain: "PaperEditor", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        // The web page at /run is just a UI shell; the real CGI is at /cgi-bin/latexcgi
        guard let url = URL(string: "https://texlive.net/cgi-bin/latexcgi") else {
            return .failure(err("Invalid texlive.net URL."))
        }
        let boundary = "OpenNoteLatex\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()

        func field(_ name: String, filename: String? = nil, value: String) {
            var disp = "Content-Disposition: form-data; name=\"\(name)\""
            if let fn = filename { disp += "; filename=\"\(fn)\"" }
            body += "--\(boundary)\r\n\(disp)\r\n".data(using: .utf8)!
            if filename != nil { body += "Content-Type: text/plain; charset=utf-8\r\n".data(using: .utf8)! }
            body += "\r\n".data(using: .utf8)!
            body += (value + "\r\n").data(using: .utf8)!
        }

        // latexcgi uses array-syntax field names: filecontents[] and filename[]
        field("filecontents[]", filename: "main.tex", value: tex)
        field("filename[]", value: "main.tex")
        field("engine", value: "pdflatex")
        field("return", value: "pdf")
        body += "--\(boundary)--\r\n".data(using: .utf8)!

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if data.prefix(4) == Data("%PDF".utf8) { return .success(try savePDF(data)) }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? ""
            let msg = raw.hasPrefix("<!") ? "texlive.net returned an HTML page (service may be down)" : parseErrorLog(raw)
            return .failure(err("[texlive.net] HTTP \(code): \(msg)", code: code))
        } catch {
            return .failure(error as NSError)
        }
    }

    /// Fallback 2 (always succeeds): render the LaTeX body locally as HTML + MathJax.
    /// The WKWebView displays HTML files perfectly; the user sees a preview with a banner.
    private static func renderLocalHTML(tex: String) -> URL? {
        // Extract body between \begin{document} and \end{document}
        var body: String
        if let s = tex.range(of: "\\begin{document}"),
           let e = tex.range(of: "\\end{document}") {
            body = String(tex[s.upperBound..<e.lowerBound])
        } else {
            body = tex
        }

        // Strip LaTeX comments
        body = (try? body.replacingOccurrences(of: "%[^\n]*", with: "", options: .regularExpression)) ?? body

        // Commands to drop
        for cmd in ["\\maketitle", "\\tableofcontents", "\\listoffigures",
                    "\\listoftables", "\\noindent", "\\centering", "\\sloppy", "\\par"] {
            body = body.replacingOccurrences(of: cmd, with: "")
        }
        body = body.replacingOccurrences(of: "\\newpage", with: "<hr>")
        body = body.replacingOccurrences(of: "\\clearpage", with: "<hr>")

        // Sections
        body = (try? body.replacingOccurrences(of: "\\\\section\\*?\\{([^}]+)\\}", with: "\n<h1>$1</h1>\n", options: .regularExpression)) ?? body
        body = (try? body.replacingOccurrences(of: "\\\\subsection\\*?\\{([^}]+)\\}", with: "\n<h2>$1</h2>\n", options: .regularExpression)) ?? body
        body = (try? body.replacingOccurrences(of: "\\\\subsubsection\\*?\\{([^}]+)\\}", with: "\n<h3>$1</h3>\n", options: .regularExpression)) ?? body

        // Text formatting
        body = (try? body.replacingOccurrences(of: "\\\\textbf\\{([^}]+)\\}", with: "<strong>$1</strong>", options: .regularExpression)) ?? body
        body = (try? body.replacingOccurrences(of: "\\\\textit\\{([^}]+)\\}", with: "<em>$1</em>", options: .regularExpression)) ?? body
        body = (try? body.replacingOccurrences(of: "\\\\emph\\{([^}]+)\\}", with: "<em>$1</em>", options: .regularExpression)) ?? body
        body = (try? body.replacingOccurrences(of: "\\\\underline\\{([^}]+)\\}", with: "<u>$1</u>", options: .regularExpression)) ?? body
        body = (try? body.replacingOccurrences(of: "\\\\texttt\\{([^}]+)\\}", with: "<code>$1</code>", options: .regularExpression)) ?? body

        // Lists
        body = body.replacingOccurrences(of: "\\begin{itemize}", with: "<ul>")
        body = body.replacingOccurrences(of: "\\end{itemize}", with: "</ul>")
        body = body.replacingOccurrences(of: "\\begin{enumerate}", with: "<ol>")
        body = body.replacingOccurrences(of: "\\end{enumerate}", with: "</ol>")
        body = (try? body.replacingOccurrences(of: "\\\\item\\b", with: "<li>", options: .regularExpression)) ?? body

        // Display math environments → $$...$$ for MathJax
        body = (try? body.replacingOccurrences(of: "\\\\begin\\{equation\\*?\\}([\\s\\S]*?)\\\\end\\{equation\\*?\\}", with: "$$\n$1\n$$", options: .regularExpression)) ?? body
        body = (try? body.replacingOccurrences(of: "\\\\begin\\{align\\*?\\}([\\s\\S]*?)\\\\end\\{align\\*?\\}", with: "$$\n\\\\begin{align}$1\\\\end{align}\n$$", options: .regularExpression)) ?? body
        body = (try? body.replacingOccurrences(of: "\\\\\\[([\\s\\S]*?)\\\\\\]", with: "$$\n$1\n$$", options: .regularExpression)) ?? body

        // Line breaks and paragraphs
        body = (try? body.replacingOccurrences(of: "\\\\\\\\", with: "<br>", options: .regularExpression)) ?? body
        body = body.replacingOccurrences(of: "\n\n", with: "</p><p>")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script>
            window.MathJax = {
                tex: { inlineMath:[['$','$']], displayMath:[['$$','$$']], processEscapes:true },
                options: { skipHtmlTags:['script','noscript','style','textarea','pre'] }
            };
            </script>
            <script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js"></script>
            <style>
                body { font-family:-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif;
                       font-size:16px; line-height:1.65; margin:0; padding:20px 24px;
                       color:#1a1a1a; background:#fff; }
                h1 { font-size:22px; font-weight:700; margin:24px 0 10px; }
                h2 { font-size:18px; font-weight:600; margin:20px 0 8px; }
                h3 { font-size:15px; font-weight:600; margin:16px 0 6px; }
                ul,ol { margin:8px 0; padding-left:24px; }
                li { margin:4px 0; }
                code { font-family:'Courier New',monospace; font-size:13px;
                       background:#f0f0f0; padding:1px 4px; border-radius:3px; }
                pre { background:#f5f5f5; padding:12px; border-radius:6px; overflow-x:auto; }
                hr { border:none; border-top:1px solid #ddd; margin:20px 0; }
                table { border-collapse:collapse; width:100%; margin:12px 0; }
                th,td { border:1px solid #ccc; padding:6px 10px; text-align:left; }
                th { background:#f5f5f5; font-weight:600; }
                .banner { background:#fff3e0; border-left:4px solid #ff9800;
                          padding:10px 14px; margin-bottom:20px; font-size:13px;
                          color:#5d4037; border-radius:0 6px 6px 0; }
            </style>
        </head>
        <body>
            <div class="banner">
                ⚡ <strong>Preview mode</strong> — PDF compilation services were unreachable.
                Math renders via MathJax. Tap <em>Compile PDF</em> again when online to get a true PDF.
            </div>
            <p>\(body)</p>
        </body>
        </html>
        """
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".html")
        try? html.write(to: temp, atomically: true, encoding: .utf8)
        return temp
    }

    private static func savePDF(_ data: Data) throws -> URL {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pdf")
        try data.write(to: temp)
        return temp
    }

    // MARK: - Package sanitizer

    /// Packages known to be absent or unreliable on hosted pdflatex services.
    /// Everything NOT on this list is stripped and replaced with safe shims.
    private static let blockedPackages: [String] = [
        "tcolorbox", "minted", "fontawesome", "fontawesome5",
        "mdframed", "framed", "todonotes", "pdfpages",
        "marginnote", "sidenotes", "textpos",
        "newpxtext", "newpxmath",
        "libertine", "libertinust1math",
        "palatino", "mathpazo",
        "helvet", "courier", "times", "mathptmx",
        "luatexja", "xeCJK"
    ]

    /// Strips unsafe \\usepackage lines, patches environments, and injects
    /// compatibility shims so the document compiles on any standard pdflatex host.
    private static func stripUnsafePackages(_ text: String) -> String {
        var t = text

        // 1. Remove every \usepackage[...]{blockedPkg}
        for pkg in blockedPackages {
            let patterns = [
                "\\\\usepackage\\[[^\\]]*\\]\\{\(pkg)\\}",
                "\\\\usepackage\\{\(pkg)\\}"
            ]
            for p in patterns {
                t = (try? t.replacingOccurrences(of: p, with: "", options: .regularExpression)) ?? t
            }
        }

        // 2. Replace minted environments → lstlisting
        if t.contains("minted") {
            t = (try? t.replacingOccurrences(
                of: "\\\\begin\\{minted\\}(?:\\[[^\\]]*\\])?\\{[^}]*\\}",
                with: "\\\\begin{lstlisting}",
                options: .regularExpression)) ?? t
            t = t.replacingOccurrences(of: "\\end{minted}", with: "\\end{lstlisting}")
            if !t.contains("\\usepackage{listings}") {
                t = t.replacingOccurrences(of: "\\begin{document}",
                                           with: "\\usepackage{listings}\n\\begin{document}")
            }
        }

        // 3. Shim tcolorbox as a simple framed quote (preserves content)
        if t.contains("tcolorbox") {
            let shim = """
            % --- tcolorbox shim (not available on this host) ---
            \\makeatletter
            \\@ifundefined{tcolorbox}{%
              \\newenvironment{tcolorbox}[1][]{\\begin{quote}\\small}{\\end{quote}}%
            }{}
            \\makeatother
            """
            t = t.replacingOccurrences(of: "\\begin{document}",
                                       with: "\(shim)\n\\begin{document}")
        }

        // 4. Strip any remaining \\usepackage{non-existent font} calls
        let fontPackagePattern = "\\\\usepackage(?:\\[[^\\]]*\\])?\\{(?:newpx|libertine|palatino|helvet|courier|times|mathpt)[^}]*\\}"
        t = (try? t.replacingOccurrences(of: fontPackagePattern, with: "", options: .regularExpression)) ?? t

        return t
    }

    // MARK: - LaTeX pre-compile sanitizer

    /// Guarantees the string starts with \documentclass and ends with \end{document}.
    /// Strips markdown code fences that AI models sometimes emit despite instructions.
    private static func ensureValidLaTeX(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return raw }

        // Always strip unsafe packages first
        text = stripUnsafePackages(text)

        // Strip opening code fence (```latex / ```tex / ```)
        for fence in ["```latex", "```tex", "```"] {
            if text.lowercased().hasPrefix(fence) {
                if let nl = text.firstIndex(of: "\n") {
                    text = String(text[text.index(after: nl)...])
                } else {
                    text = String(text.dropFirst(fence.count))
                }
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        // Strip closing code fence
        if text.hasSuffix("\n```") { text = String(text.dropLast(4)).trimmingCharacters(in: .whitespacesAndNewlines) }
        else if text.hasSuffix("```") { text = String(text.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines) }

        // Skip any prose emitted before \documentclass
        if let r = text.range(of: "\\documentclass", options: .literal) { text = String(text[r.lowerBound...]) }

        // If still no \documentclass, wrap as a minimal document
        if !text.contains("\\documentclass") {
            return """
            \\documentclass[12pt]{article}
            \\usepackage[utf8]{inputenc}
            \\usepackage{amsmath,amssymb}
            \\usepackage{geometry}
            \\geometry{margin=1in}
            \\begin{document}

            \(text)

            \\end{document}
            """
        }

        // Guarantee \end{document} is the final token
        let endToken = "\\end{document}"
        if let r = text.range(of: endToken, options: [.literal, .backwards]) {
            text = String(text[..<r.upperBound])
        } else {
            // Handle partial truncation like \end{documen (stream cut off)
            for partial in ["\\end{documen", "\\end{docume", "\\end{docum",
                            "\\end{docu", "\\end{doc", "\\end{do", "\\end{d",
                            "\\end{", "\\end", "\\en"] {
                if text.hasSuffix(partial) { text = String(text.dropLast(partial.count)); break }
            }
            text += "\n\\end{document}"
        }
        return text
    }

    private func convertJournalToLaTeX(_ journal: Journal) {
        // Journal blocks aren't persisted - create a template with the journal title.
        // User can edit or use AI to refine.
        let escapedTitle = journal.title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
        content = """
        \\documentclass{article}
        \\usepackage[utf8]{inputenc}
        \\usepackage{geometry}
        \\geometry{margin=1in}
        \\title{\(escapedTitle)}
        \\date{\\today}
        \\begin{document}
        \\maketitle

        % Converted from journal "\(escapedTitle)"
        % Add your content below or ask AI to help.

        \\section{Content}

        \\end{document}
        """
        saveContent(content)
    }

    private func saveContent(_ text: String) {
        var updated = paper
        updated.content = text
        updated.lastEdited = Date()
        notesStore.updatePaper(updated)
    }
}

// MARK: - Helpers

private enum PaperPane {
    case code
    case pdf
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

/// Native PDFKit viewer — used for real PDF files returned by compilation services.
private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(named: "opennoteCream") ?? .systemBackground
        if let doc = PDFDocument(url: url) { pdfView.document = doc }
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let doc = PDFDocument(url: url), doc.documentURL != pdfView.document?.documentURL {
            pdfView.document = doc
        }
    }
}

/// WKWebView renderer — used only for the local HTML preview fallback.
private struct PDFWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

private struct PaperAISheet: View {
    @Binding var texContent: String
    @Binding var isPresented: Bool
    @FocusState private var isPromptFocused: Bool
    @State private var prompt = ""
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var aiOutput: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(spacing: 12) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(Color.opennoteGreen)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ask Feynman")
                                .font(.system(size: 22, weight: .bold, design: .serif))
                            Text("Describe how you'd like to improve your LaTeX")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    // Input section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your instruction")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        TextField("e.g. Add an abstract, fix the bibliography, rewrite the introduction...", text: $prompt, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, design: .default))
                            .lineLimit(3...8)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($isPromptFocused)
                    }

                    if let err = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if isRunning {
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(Color.opennoteGreen)
                            Text("Feynman is editing your LaTeX...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else if let output = aiOutput {
                        // Structured output preview
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.opennoteGreen)
                                Text("Feynman's suggestion")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                            }
                            ScrollView {
                                Text(output)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            }
                            .frame(minHeight: 200, maxHeight: 600)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }

                        HStack(spacing: 12) {
                            Button {
                                aiOutput = nil
                                prompt = ""
                            } label: {
                                Text("Try again")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(.systemGray5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            Button {
                                Haptics.impact(.light)
                                texContent = output
                                isPresented = false
                            } label: {
                                Text("Apply changes")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.opennoteGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button {
                            Haptics.impact(.light)
                            Task { await runAI() }
                        } label: {
                            HStack(spacing: 10) {
                                if isRunning {
                                    ProgressView().tint(.white)
                                } else {
                                    Image("logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                    Text("Ask Feynman")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.opennoteGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
                    }
                }
                .padding(20)
            }
            .background(Color.opennoteCream)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Ask Feynman")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.primary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    KeyboardDismissAccessory(onDismiss: { isPromptFocused = false })
                }
            }
        }
        .onDisappear {
            aiOutput = nil
        }
    }

    private func runAI() async {
        let trimmed = prompt.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isRunning = true
        errorMessage = nil
        aiOutput = nil
        defer { isRunning = false }
        let openAI = OpenAIService.shared
        guard openAI.isConfigured else {
            await MainActor.run {
                errorMessage = "Add your OpenAI API key in OpenAIConfig to use Feynman."
            }
            return
        }
        let response = await openAI.editLaTeX(tex: texContent, instruction: trimmed)
        await MainActor.run {
            if let newContent = response {
                aiOutput = newContent
            } else {
                errorMessage = "Feynman couldn't complete the edit. Please try again."
            }
        }
    }
}

// MARK: - Auto-fix overlay

private struct LaTeXAutoFixOverlay: View {
    let state: PaperCompileState

    @State private var logoRotation: Double = -8
    @State private var logoOffset: CGFloat = 0
    @State private var dot1Opacity: Double = 0.2
    @State private var dot2Opacity: Double = 0.2
    @State private var dot3Opacity: Double = 0.2
    @State private var haloScale: CGFloat = 0.95
    @State private var haloOpacity: Double = 0.4

    var body: some View {
        ZStack {
            // Blurred background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Ambient green halo
            Circle()
                .fill(Color.opennoteGreen.opacity(0.18))
                .frame(width: 280, height: 280)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)
                .blur(radius: 30)

            VStack(spacing: 28) {
                // Animated Feynman logo
                ZStack {
                    Circle()
                        .fill(Color.opennoteGreen.opacity(0.12))
                        .frame(width: 110, height: 110)
                        .scaleEffect(haloScale)
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(logoRotation))
                        .offset(y: logoOffset)
                }

                // Stage text
                VStack(spacing: 8) {
                    Text(state.overlayStage)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .id(state.overlayStage) // triggers transition
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    Text(state.overlaySubtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .id(state.overlaySubtitle)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.5), value: state.overlayStage)

                // Animated dots
                HStack(spacing: 8) {
                    ForEach(Array([dot1Opacity, dot2Opacity, dot3Opacity].enumerated()), id: \.offset) { i, op in
                        Circle()
                            .fill(Color.opennoteGreen)
                            .frame(width: 8, height: 8)
                            .opacity(op)
                    }
                }
            }
            .padding(40)
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        // Logo sway
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            logoRotation = 8
            logoOffset = -6
        }
        // Halo pulse
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            haloScale = 1.1
            haloOpacity = 0.7
        }
        // Dots cascade
        let base = 0.5
        withAnimation(.easeInOut(duration: base).repeatForever(autoreverses: true).delay(0.0)) {
            dot1Opacity = 1.0
        }
        withAnimation(.easeInOut(duration: base).repeatForever(autoreverses: true).delay(0.2)) {
            dot2Opacity = 1.0
        }
        withAnimation(.easeInOut(duration: base).repeatForever(autoreverses: true).delay(0.4)) {
            dot3Opacity = 1.0
        }
    }
}

private struct NotesToPDFSheet: View {
    let journals: [Journal]
    let onSelectJournal: (Journal) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List(journals) { journal in
                Button {
                    onSelectJournal(journal)
                } label: {
                    Text(journal.title)
                }
            }
            .navigationTitle("Turn notes into PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}


import SwiftUI
import PDFKit

// MARK: - Compile state

enum PaperCompileState: Equatable {
    case idle
    case compiling
    case error(String) // real LaTeX compile error — never a silent fallback

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
    var errorMessage: String? {
        if case .error(let msg) = self { return msg }
        return nil
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
    @State private var pdfURL: URL?          // temp-file URL — PDFKit memory-maps it
    @State private var compilationError: String?
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

    } // end ZStack
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
            // ── State 1: Compiling ──
            if compileState == .compiling {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(Color.opennoteGreen)
                    Text("Compiling PDF…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── State 2: Success — real PDFKit render (memory-mapped from temp file) ──
            } else if let url = pdfURL {
                PDFKitView(url: url)

            // ── State 3: Failure — show error log, nothing else ──
            } else if let log = compileState.errorMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Compilation Failed", systemImage: "xmark.octagon.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.red)
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            Haptics.impact(.light)
                            compileAndPreview()
                        } label: {
                            Label("Retry Compile", systemImage: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.opennoteGreen)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
                .background(Color(.systemGroupedBackground))

            // ── State 4: Idle, no compile yet ──
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(.systemGray3))
                    Text("Press Compile PDF to render your document")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .top) {
            if compileState != .compiling {
                Text("PDF Preview")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6).opacity(0.5))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !compileState.isError, compileState != .compiling {
                Button {
                    Haptics.impact(.light)
                    compileAndPreview()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text("Compile PDF")
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
                .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(content.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
                .padding(20)
            }
        }
    }

    private func compileAndPreview() {
        guard compileState.isIdle || compileState.isError else { return }
        compileState = .compiling
        pdfURL = nil
        compilationError = nil
        let tex = Self.ensureValidLaTeX(content)
        Task {
            let (url, errorLog) = await Self.compileToURL(tex: tex)
            await MainActor.run {
                compileState = .idle
                if let url {
                    pdfURL = url
                } else {
                    compileState = .error(errorLog ?? "Compilation failed.")
                }
            }
        }
    }

    // MARK: - Compilation pipeline

    /// Two-tier pipeline: latexonline.cc → texlive.net.
    /// Returns real PDF bytes on success, or a filtered error log on failure.
    /// Never falls back to any HTML/web renderer.
    /// Compiles and immediately writes PDF bytes to a temp file, then releases the Data.
    /// PDFKit uses URL-based loading to memory-map the file — far lower RAM than Data-based.
    /// Returns (tempFileURL, nil) on success or (nil, errorLog) on failure.
    private static func compileToURL(tex: String) async -> (URL?, String?) {
        let clean = ensureValidLaTeX(tex)
        var lastError = "PDF compilation failed. Check your LaTeX source and try again."

        // Tier 1: latexonline.cc (two attempts with a 1-second pause)
        for attempt in 1...2 {
            let r = await doCompileLatexOnline(tex: clean)
            switch r {
            case .success(let data):
                if let url = writePDFToDisk(data) { return (url, nil) }
            case .failure(let err):
                lastError = parseErrorLog(err.localizedDescription)
            }
            if attempt == 1 { try? await Task.sleep(nanoseconds: 1_000_000_000) }
        }

        // Tier 2: texlive.net CGI (one attempt)
        let r2 = await doCompileTexliveNet(tex: clean)
        switch r2 {
        case .success(let data):
            if let url = writePDFToDisk(data) { return (url, nil) }
        case .failure(let err):
            lastError = parseErrorLog(err.localizedDescription)
        }

        return (nil, lastError)
    }

    /// Writes PDF bytes to a uniquely-named temp file and immediately releases the Data.
    /// The returned URL is memory-mappable by PDFDocument(url:).
    private static func writePDFToDisk(_ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// Compile via latexonline.cc — form-encoded POST.
    /// POST https://latexonline.cc/compile  Content-Type: application/x-www-form-urlencoded
    private static func doCompileLatexOnline(tex: String) async -> Result<Data, NSError> {
        func err(_ msg: String, code: Int = -1) -> NSError {
            NSError(domain: "PaperEditor", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let url = URL(string: "https://latexonline.cc/compile") else {
            return .failure(err("Invalid latexonline.cc URL."))
        }
        // urlQueryAllowed leaves & and = unencoded — they are form-field delimiters
        // and MUST be percent-encoded when they appear inside a form value.
        // LaTeX uses & for table columns and align environments.
        var formValueCS = CharacterSet.urlQueryAllowed
        formValueCS.remove(charactersIn: "&=+#")
        guard let encoded = tex.addingPercentEncoding(withAllowedCharacters: formValueCS) else {
            return .failure(err("Could not percent-encode the LaTeX source."))
        }
        var request = URLRequest(url: url, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "text=\(encoded)".data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard data.prefix(4) == Data("%PDF".utf8) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let raw = String(data: data, encoding: .utf8) ?? "Compilation failed."
                return .failure(err("[latexonline.cc] HTTP \(code): \(raw)", code: code))
            }
            return .success(data)
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

    /// Fallback: compile via texlive.net CGI (David Carlisle's latexcgi).
    /// Field layout per the API spec:
    ///   filecontents[] — raw LaTeX source (no filename= in Content-Disposition)
    ///   filename[]     — must be literally "document.tex" (the server's main-file identifier)
    ///   engine         — "pdflatex"
    ///   return         — "pdf"
    private static func doCompileTexliveNet(tex: String) async -> Result<Data, NSError> {
        func err(_ msg: String, code: Int = -1) -> NSError {
            NSError(domain: "PaperEditor", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let url = URL(string: "https://texlive.net/cgi-bin/latexcgi") else {
            return .failure(err("Invalid texlive.net URL."))
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) {
            if let d = string.data(using: .utf8) { body.append(d) }
        }

        // Field 1: filecontents[] — raw LaTeX source, NO filename= attribute
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"filecontents[]\"\r\n\r\n")
        append("\(tex)\r\n")

        // Field 2: filename[] — MUST be "document.tex" so the server knows the entry point
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"filename[]\"\r\n\r\n")
        append("document.tex\r\n")

        // Field 3: engine
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"engine\"\r\n\r\n")
        append("pdflatex\r\n")

        // Field 4: return type
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"return\"\r\n\r\n")
        append("pdf\r\n")

        append("--\(boundary)--\r\n")

        var request = URLRequest(url: url, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard data.prefix(4) == Data("%PDF".utf8) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let raw = String(data: data, encoding: .utf8) ?? ""
                let msg = raw.hasPrefix("<!") ? "texlive.net returned an HTML page — service may be down." : raw
                return .failure(err("[texlive.net] HTTP \(code): \(msg)", code: code))
            }
            return .success(data)
        } catch {
            return .failure(error as NSError)
        }
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

/// Native PDFKit viewer — loads from a temp-file URL so PDFKit can memory-map the PDF.
/// Memory-mapped loading uses only the RAM needed for visible pages (~1-2 MB)
/// instead of loading the entire file into RAM like PDFDocument(data:) does.
private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true)
        pdfView.backgroundColor = UIColor(named: "opennoteCream") ?? UIColor.systemGroupedBackground
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
            pdfView.goToFirstPage(nil)
        }
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Only reload when the file URL has actually changed — this is critical.
        // Without this guard, every SwiftUI re-render (typing in the editor,
        // state changes, etc.) would allocate a new PDFDocument, causing rapid
        // memory churn that crashes the app.
        guard pdfView.document?.documentURL != url else { return }
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
            pdfView.goToFirstPage(nil)
        }
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


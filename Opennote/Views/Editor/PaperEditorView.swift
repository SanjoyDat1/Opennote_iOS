import SwiftUI
import WebKit

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
                PDFWebView(url: url)
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
            let result = await Self.doCompile(tex: tex)
            await MainActor.run {
                switch result {
                case .success(let url):
                    pdfURL = url
                    compileState = .idle
                case .failure(let compileErr):
                    // Automatically invoke Feynman to fix and retry
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
            compileState = .error("Feynman couldn't reach the AI service. Check your connection and try again.")
            return
        }

        guard !fixedTeX.isEmpty else {
            compileState = .error("Feynman couldn't determine a fix. Please review your LaTeX manually.")
            return
        }

        let sanitized = Self.ensureValidLaTeX(fixedTeX)
        content = sanitized          // apply the fix so the user can see it
        compileState = .recompiling

        let result = await Self.doCompile(tex: sanitized)
        switch result {
        case .success(let url):
            pdfURL = url
            compileState = .idle
        case .failure(let log2):
            compileState = .error("Feynman fixed some errors but the document still has issues.\n\nDetails:\n\(log2.localizedDescription)")
        }
    }

    // MARK: - Shared compile helper

    private static func doCompile(tex: String) async -> Result<URL, NSError> {
        func err(_ msg: String, code: Int = -1) -> NSError {
            NSError(domain: "PaperEditor", code: code,
                    userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let tarData = buildTarGz(texContent: tex) else {
            return .failure(err("Could not package the LaTeX document."))
        }
        guard let url = URL(string: "https://latexonline.cc/compile?command=pdflatex&force=true") else {
            return .failure(err("Invalid compilation URL."))
        }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = tarData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusOK = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            if statusOK, data.prefix(4) == Data("%PDF".utf8) {
                let temp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".pdf")
                try? data.write(to: temp)
                return .success(temp)
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errText = String(data: data, encoding: .utf8) ?? "Compilation failed."
                return .failure(err("HTTP \(code): \(errText)", code: code))
            }
        } catch {
            return .failure(error as NSError)
        }
    }

    // MARK: - LaTeX pre-compile sanitizer

    /// Guarantees the string starts with \documentclass and ends with \end{document}.
    /// Strips markdown code fences that AI models sometimes emit despite instructions.
    private static func ensureValidLaTeX(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return raw }

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

    // MARK: - Tar.gz builder

    /// Creates a gzip-compressed tar archive containing a single `main.tex`.
    /// Uses the format accepted by `latexonline.cc/compile` POST endpoint.
    private static func buildTarGz(texContent: String) -> Data? {
        guard let texData = texContent.data(using: .utf8) else { return nil }

        // ── Build minimal POSIX ustar tar ────────────────────────────────────
        var tar = Data()
        var h = [UInt8](repeating: 0, count: 512)

        func write(_ s: String, at off: Int, max n: Int) {
            for (i, b) in s.utf8.prefix(n).enumerated() { h[off + i] = b }
        }

        write("main.tex",                                    at: 0,   max: 100) // name
        write("0000644\0",                                   at: 100, max: 8)   // mode
        write("0000000\0",                                   at: 108, max: 8)   // uid
        write("0000000\0",                                   at: 116, max: 8)   // gid
        write(String(format: "%011o\0", texData.count),      at: 124, max: 12)  // size
        write(String(format: "%011o\0",
                     Int(Date().timeIntervalSince1970)),      at: 136, max: 12)  // mtime
        h[156] = UInt8(ascii: "0")                                               // type: regular
        write("ustar\0",                                     at: 257, max: 6)   // magic
        write("00",                                          at: 263, max: 2)   // version

        // Checksum field must be ASCII spaces when summing, then replaced with octal sum
        for i in 148..<156 { h[i] = UInt8(ascii: " ") }
        let cksum = h.reduce(0) { $0 + Int($1) }
        write(String(format: "%06o\0 ", cksum),              at: 148, max: 8)

        tar.append(contentsOf: h)
        tar.append(texData)

        // Pad file content to 512-byte block boundary
        let rem = texData.count % 512
        if rem > 0 { tar.append(contentsOf: [UInt8](repeating: 0, count: 512 - rem)) }
        // Two zero-filled 512-byte end-of-archive blocks
        tar.append(contentsOf: [UInt8](repeating: 0, count: 1024))

        // ── Wrap in gzip ─────────────────────────────────────────────────────
        // NSData.compressed(using: .zlib) gives RFC-1950 zlib: 2-byte header | DEFLATE | 4-byte Adler32.
        // gzip (RFC-1952) needs raw DEFLATE stream, framed with its own header/trailer.
        guard let zlibData = try? (tar as NSData).compressed(using: .zlib) as Data,
              zlibData.count > 6 else { return nil }

        let deflate = zlibData.dropFirst(2).dropLast(4)   // strip zlib envelope

        var gz = Data()
        gz.append(contentsOf: [0x1f, 0x8b, 0x08, 0x00,    // magic, DEFLATE, no flags
                                0x00, 0x00, 0x00, 0x00,    // mtime = 0
                                0x00, 0xff])               // xfl=0, OS=unknown
        gz.append(deflate)

        var crc = tarCRC32(tar)                            // CRC32 of uncompressed tar
        withUnsafeBytes(of: &crc)   { gz.append(contentsOf: $0) }
        var sz = UInt32(tar.count & 0xFFFF_FFFF)           // ISIZE mod 2^32
        withUnsafeBytes(of: &sz)    { gz.append(contentsOf: $0) }

        return gz
    }

    /// CRC-32 with polynomial 0xEDB88320 as required by gzip (RFC-1952).
    private static func tarCRC32(_ data: Data) -> UInt32 {
        let tbl: [UInt32] = (0..<256).map { n -> UInt32 in
            var c = UInt32(n)
            for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
            return c
        }
        var crc: UInt32 = 0xFFFF_FFFF
        for b in data { crc = tbl[Int((crc ^ UInt32(b)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFF_FFFF
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

private struct PDFWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        let readAccessURL = url.deletingLastPathComponent()
        view.loadFileURL(url, allowingReadAccessTo: readAccessURL)
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let readAccessURL = url.deletingLastPathComponent()
        webView.loadFileURL(url, allowingReadAccessTo: readAccessURL)
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


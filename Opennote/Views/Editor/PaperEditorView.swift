import SwiftUI
import WebKit

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
    @State private var isCompiling = false
    @State private var compileError: String?
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        Haptics.selection()
                        isEditorFocused = false
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.opennoteGreen)
                }
                .padding(.vertical, 4)
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

            Button {
                Haptics.impact(.light)
                showSettingsSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            ShareLink(
                item: content,
                subject: Text(editedTitle),
                message: Text("Shared from Opennote")
            ) {
                Text("Share")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.opennoteGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
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
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.opennoteGreen)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
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
            if let err = compileError {
                VStack {
                    Spacer()
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    if isCompiling {
                        ProgressView()
                            .scaleEffect(0.9)
                            .tint(.white)
                    } else {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 18, weight: .medium))
                    }
                    Text(isCompiling ? "Compiling…" : "Compile PDF")
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
            .disabled(isCompiling || content.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(content.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
            .padding(20)
        }
    }

    private func compileAndPreview() {
        isCompiling = true
        compileError = nil
        let tex = content
        Task {
            do {
                let encoded = tex.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let urlString = "https://latexonline.cc/compile?text=\(encoded)&force=true"
                guard let url = URL(string: urlString) else {
                    throw NSError(domain: "Paper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                let (data, response) = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    isCompiling = false
                    if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                        let temp = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString + ".pdf")
                        try? data.write(to: temp)
                        pdfURL = temp
                        compileError = nil
                    } else {
                        compileError = String(data: data, encoding: .utf8) ?? "Compilation failed"
                    }
                }
            } catch {
                await MainActor.run {
                    isCompiling = false
                    compileError = error.localizedDescription
                }
            }
        }
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
                    HStack {
                        Spacer()
                        Button("Done") {
                            Haptics.selection()
                            isPromptFocused = false
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.opennoteGreen)
                    }
                    .padding(.vertical, 8)
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


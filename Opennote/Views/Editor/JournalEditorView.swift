import SwiftUI

/// Journal Editor - clean design matching spec. No "Generate video" section.
struct JournalEditorView: View {
    let journal: Journal
    var onDelete: (() -> Void)?
    var onCloneSelect: ((Journal) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(NotesStore.self) private var notesStore
    @FocusState private var focusedBlockId: UUID?
    @State private var viewModel: JournalEditorViewModel
    @State private var showSettingsSheet = false
    @State private var showSlashPalette = false
    @State private var slashFilter = ""
    @State private var slashBlockId: UUID?
    @State private var showPhotoToText = false

    init(journal: Journal, initialBlocks: [NoteBlock]? = nil, onDelete: (() -> Void)? = nil, onCloneSelect: ((Journal) -> Void)? = nil) {
        self.journal = journal
        self.onDelete = onDelete
        self.onCloneSelect = onCloneSelect
        let blocks = initialBlocks ?? [NoteBlock(orderIndex: 0, blockType: .paragraph(""))]
        _viewModel = State(initialValue: JournalEditorViewModel(journalTitle: journal.title, blocks: blocks))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            editorContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.opennoteCream)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        Haptics.selection()
                        focusedBlockId = nil
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.opennoteGreen)
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            notesStore.pendingBlocksForJournalId.removeValue(forKey: journal.id)
            if viewModel.blocks.count == 1, isBlockEmpty(viewModel.blocks[0]) {
                focusedBlockId = viewModel.blocks[0].id
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            JournalSettingsSheet(
                isPresented: $showSettingsSheet,
                journal: journal,
                viewModel: viewModel,
                onCloneSelect: onCloneSelect,
                onDelete: { onDelete?() }
            )
        }
        .sheet(isPresented: $showPhotoToText) {
            PhotoToTextView(isPresented: $showPhotoToText) { text in
                insertPhotoToTextResult(text)
            }
        }
        .onChange(of: viewModel.blocks) { _, _ in
            if showSlashPalette, let bid = slashBlockId,
               !viewModel.blocks.contains(where: { $0.id == bid }) {
                showSlashPalette = false
            }
        }
    }

    private func handleSlashTriggered(blockId: UUID, filter: String) {
        slashBlockId = blockId
        slashFilter = filter
        showSlashPalette = true
    }

    private func handleSlashCommandSelected(_ cmd: SlashCommand) {
        guard let blockId = slashBlockId ?? viewModel.blocks.first?.id else { return }
        clearSlashFromBlock(blockId)
        showSlashPalette = false
        slashBlockId = nil
        slashFilter = ""

        switch cmd.id {
        case "text":
            break
        case "h1": insertBlockType(.heading(level: 1, text: ""), at: blockId)
        case "h2": insertBlockType(.heading(level: 2, text: ""), at: blockId)
        case "h3": insertBlockType(.heading(level: 3, text: ""), at: blockId)
        case "bullet": insertBlockType(.bulletList([""]), at: blockId)
        case "numbered": insertBlockType(.numberedList([""]), at: blockId)
        case "checklist": insertBlockType(.todo(items: [TodoItem(text: "", done: false)]), at: blockId)
        case "quote": insertBlockType(.callout(text: ""), at: blockId)
        case "divider": insertBlockType(.divider, at: blockId)
        case "code": insertBlockType(.codeCard(language: "Python", code: "", stdin: "", stdout: ""), at: blockId)
        case "latex", "math": insertBlockType(.mathBlock(latex: ""), at: blockId)
        case "graph": insertBlockType(.graphBlock(expression: ""), at: blockId)
        case "image":
            showPhotoToText = true
        case "photo_to_text":
            showPhotoToText = true
        case "ask_feynman":
            viewModel.insertAIPrompt(after: blockId)
            if let aiBlock = viewModel.blocks.last(where: { $0.blockType.isAIPrompt }) {
                focusedBlockId = aiBlock.id
            }
        case "flashcards":
            let newId = viewModel.insertFlashcardSet(after: blockId)
            focusedBlockId = viewModel.blocks.first(where: { $0.id == newId })?.id
            Task { await viewModel.generateFlashcards(blockId: newId) }
        case "practice":
            let newId = viewModel.insertPracticeProblems(after: blockId)
            focusedBlockId = viewModel.blocks.first(where: { $0.id == newId })?.id
            Task { await viewModel.generatePracticeProblems(blockId: newId) }
        case "subjournal", "link_journal":
            break
        default:
            break
        }
    }

    private func clearSlashFromBlock(_ blockId: UUID) {
        guard let idx = viewModel.blocks.firstIndex(where: { $0.id == blockId }) else { return }
        let block = viewModel.blocks[idx]
        if case .paragraph(let text) = block.blockType, text.hasPrefix("/") {
            viewModel.updateBlock(id: blockId, blockType: .paragraph(""))
        }
    }

    private func insertPhotoToTextResult(_ text: String) {
        guard let blockId = slashBlockId ?? viewModel.blocks.first?.id else { return }
        let newBlock = NoteBlock(orderIndex: 0, blockType: .paragraph(text))
        viewModel.insertBlock(after: blockId, newBlock: newBlock)
        focusedBlockId = newBlock.id
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "doc.text")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            
            Text(".../")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
            
            Text(viewModel.journalTitle)
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 8)
            
            Button {
                Haptics.impact(.light)
                showSettingsSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            
            ShareLink(
                item: viewModel.blocksToMarkdown(),
                subject: Text(viewModel.journalTitle),
                message: Text("Shared from Opennote")
            ) {
                Text("Share")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.opennoteGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.opennoteCream)
    }

    private var editorContent: some View {
        ZStack(alignment: .topLeading) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    // "Start with" - Ask Feynman only (no Generate video)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Start with")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Type / on a new line for commands")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }

                        HStack(spacing: 10) {
                            Button {
                                insertFeynmanBlockAtFirst()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Color.opennoteGreen)
                                    Text("Ask Feynman")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundStyle(Color.opennoteGreen)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(Color.opennoteLightGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Button {
                                showPhotoToText = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Color.opennoteGreen)
                                    Text("Photo to Text")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundStyle(Color.opennoteGreen)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(Color.opennoteLightGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button("Heading 1") { insertBlockType(.heading(level: 1, text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Heading 2") { insertBlockType(.heading(level: 2, text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Heading 3") { insertBlockType(.heading(level: 3, text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Bullet List") { insertBlockType(.bulletList([""]), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Numbered List") { insertBlockType(.numberedList([""]), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Code Block") { insertBlockType(.codeCard(language: "Python", code: "", stdin: "", stdout: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("To-do List") { insertBlockType(.todo(items: [TodoItem(text: "", done: false)]), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Callout / Quote") { insertBlockType(.callout(text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Divider") { insertBlockType(.divider, at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Divider()
                                Button {
                                    insertBlockType(.graphBlock(expression: ""), at: focusedBlockId ?? viewModel.blocks.first?.id)
                                } label: {
                                    Label("Graph (Desmos)", systemImage: "chart.line.uptrend.xyaxis")
                                }
                                Button {
                                    insertBlockType(.mathBlock(latex: ""), at: focusedBlockId ?? viewModel.blocks.first?.id)
                                } label: {
                                    Label("Math Equation", systemImage: "function")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 48, height: 48)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                            }
                        }
                    }

                    // Placeholder when no content
                    if viewModel.blocks.count == 1, isBlockEmpty(viewModel.blocks[0]) {
                        Text("Start writing or type \"/\" to see commands...")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }

                    // Block list
                    ForEach(viewModel.blocks) { block in
                        BlockRowView(
                            block: block,
                            focusedBlockId: $focusedBlockId,
                            viewModel: viewModel,
                            onReturnKey: { insertParagraphAfter(block.id) },
                            onSlashTriggered: handleSlashTriggered
                        )
                        .id(block.id)
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: focusedBlockId) { _, newId in
                guard let id = newId else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showSlashPalette {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showSlashPalette = false
                        if let bid = slashBlockId, let idx = viewModel.blocks.firstIndex(where: { $0.id == bid }),
                           case .paragraph(let text) = viewModel.blocks[idx].blockType, text == "/" {
                            viewModel.updateBlock(id: bid, blockType: .paragraph(""))
                        }
                        slashBlockId = nil
                    }
                SlashCommandPaletteView(
                    filter: slashFilter,
                    onSelect: handleSlashCommandSelected
                )
                .padding(.horizontal, 20)
                .padding(.top, 120)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private func insertParagraphAfter(_ blockId: UUID) {
        let newId = viewModel.insertParagraph(after: blockId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedBlockId = newId
        }
    }

    private func insertFeynmanBlockAtFirst() {
        let targetId = viewModel.blocks.first?.id
        if let id = targetId {
            viewModel.insertAIPrompt(after: id)
        } else {
            viewModel.insertBlock(at: 0, block: NoteBlock(orderIndex: 0, blockType: .aiPrompt(command: "", response: nil)))
        }
        if let aiBlock = viewModel.blocks.last(where: { $0.blockType.isAIPrompt }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedBlockId = aiBlock.id
            }
        }
    }

    private func insertBlockType(_ blockType: NoteBlock.BlockType, at blockId: UUID?) {
        guard let id = blockId ?? viewModel.blocks.first?.id else { return }
        let newId: UUID?
        switch blockType {
        case .graphBlock:
            newId = viewModel.insertGraphBlock(after: id)
        case .mathBlock:
            newId = viewModel.insertMathBlock(after: id)
        default:
            let newBlock = NoteBlock(orderIndex: 0, blockType: blockType)
            viewModel.insertBlock(after: id, newBlock: newBlock)
            newId = newBlock.id
        }
        if let newId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedBlockId = newId
            }
        }
    }

    private func isBlockEmpty(_ block: NoteBlock) -> Bool {
        switch block.blockType {
        case .paragraph(let t): return t.isEmpty
        case .heading(_, let t): return t.isEmpty
        case .bulletList(let i): return i.allSatisfy { $0.isEmpty }
        case .numberedList(let i): return i.allSatisfy { $0.isEmpty }
        case .codeCard(_, let c, _, _): return c.isEmpty
        case .aiPrompt(let cmd, _): return cmd.isEmpty
        case .graphBlock(let e): return e.isEmpty
        case .mathBlock(let l): return l.isEmpty
        case .callout(let t): return t.isEmpty
        case .todo(let items): return items.allSatisfy { $0.text.isEmpty }
        case .divider: return false
        case .flashcardSet(let i): return i.isEmpty
        case .practiceProblems(let i): return i.isEmpty
        }
    }
}

extension NoteBlock.BlockType {
    var isAIPrompt: Bool {
        if case .aiPrompt = self { return true }
        return false
    }
}

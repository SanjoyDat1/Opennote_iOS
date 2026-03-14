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
    @State private var chatBarViewModel = FeynmanChatBarViewModel()
    @FocusState private var isChatInputFocused: Bool
    @State private var showFeynmanPlusSheet = false
    @State private var showFeynmanModeSheet = false
    @State private var showPhotoToTextFlowSheet = false
    @State private var showVoiceInputSheet = false
    @State private var showInsertFromJournalSheet = false
    @State private var speechService = SpeechToTextService()
    // Feynman chat — persistent per journal session, shown inline above the input bar
    @State private var feynmanConversation = FeynmanConversationViewModel()
    // Voice note — insert transcription into journal (separate from chat bar mic)
    @State private var showVoiceForJournal = false
    @State private var voiceInsertAnchorId: UUID?

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
                onDelete: { onDelete?() },
                onInsertText: { text in insertTextFromChat(text) }
            )
        }
        .sheet(isPresented: $showPhotoToText) {
            PhotoToTextView(isPresented: $showPhotoToText) { text in
                insertPhotoToTextResult(text)
            }
        }
        .sheet(isPresented: $showFeynmanPlusSheet) {
            FeynmanPlusSheet(
                onPhotoLibrary: { showPhotoToTextFlowSheet = true },
                onDocument: { showPhotoToTextFlowSheet = true },
                onInsertFromJournal: { showInsertFromJournalSheet = true },
                onInsertFormatting: { showSlashPalette = true },
                onDismiss: { showFeynmanPlusSheet = false }
            )
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFeynmanModeSheet) {
            FeynmanModeSheet(selectedMode: Binding(
                get: { chatBarViewModel.selectedMode },
                set: { chatBarViewModel.selectedMode = $0 }
            ))
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPhotoToTextFlowSheet) {
            PhotoToTextFlowSheet(
                onInsertBlock: { text, _ in
                    insertPhotoToTextResult(text)
                    showPhotoToTextFlowSheet = false
                },
                onDismiss: { showPhotoToTextFlowSheet = false }
            )
        }
        .sheet(isPresented: $showVoiceInputSheet) {
            VoiceInputSheet(
                service: speechService,
                insertIntoPrompt: true,
                onInsert: { text in
                    chatBarViewModel.appendTranscribedText(text)
                    showVoiceInputSheet = false
                    isChatInputFocused = true
                },
                onDismiss: { showVoiceInputSheet = false }
            )
        }
        .sheet(isPresented: $showVoiceForJournal) {
            VoiceInputSheet(
                service: SpeechToTextService(),
                insertIntoPrompt: false,
                onInsert: { text in
                    showVoiceForJournal = false
                    let anchorId = voiceInsertAnchorId ?? viewModel.blocks.last?.id
                    guard let id = anchorId else { return }
                    let newBlock = NoteBlock(orderIndex: 0, blockType: .paragraph(text))
                    viewModel.insertBlock(after: id, newBlock: newBlock)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedBlockId = newBlock.id
                    }
                },
                onDismiss: { showVoiceForJournal = false }
            )
        }
        .sheet(isPresented: $showInsertFromJournalSheet) {
            FeynmanInsertFromJournalSheet(
                contentChunks: viewModel.blocksToMarkdown()
                    .components(separatedBy: "\n\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty },
                onSelect: { selected in
                    if chatBarViewModel.inputText.isEmpty {
                        chatBarViewModel.inputText = selected
                    } else {
                        chatBarViewModel.inputText += "\n\n" + selected
                    }
                    isChatInputFocused = true
                },
                onDismiss: { showInsertFromJournalSheet = false }
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FeynmanChatBar(
                viewModel: chatBarViewModel,
                conversation: feynmanConversation,
                isFocused: $isChatInputFocused,
                isNoteFocused: focusedBlockId != nil,
                journalContext: viewModel.blocksToMarkdown(),
                onPlus: { showFeynmanPlusSheet = true },
                onInsertIntoJournal: { text in insertTextFromChat(text) },
                onExpandFromCollapsed: {
                    focusedBlockId = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isChatInputFocused = true
                    }
                }
            )
        }
        .onChange(of: viewModel.blocks) { _, _ in
            if showSlashPalette, let bid = slashBlockId,
               !viewModel.blocks.contains(where: { $0.id == bid }) {
                withAnimation(.easeOut(duration: 0.18)) { showSlashPalette = false }
            }
        }
    }

    private func handleSlashTriggered(blockId: UUID, filter: String) {
        if filter.isEmpty {
            // User just typed "/" — show palette
            slashBlockId = blockId
            slashFilter = ""
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSlashPalette = true
            }
        } else {
            // User typed something after "/" — dismiss palette immediately
            withAnimation(.easeOut(duration: 0.18)) {
                showSlashPalette = false
            }
            slashBlockId = nil
            slashFilter = ""
        }
    }

    private func dismissSlashPalette() {
        withAnimation(.easeOut(duration: 0.18)) { showSlashPalette = false }
        if let bid = slashBlockId,
           let idx = viewModel.blocks.firstIndex(where: { $0.id == bid }),
           case .paragraph(let t) = viewModel.blocks[idx].blockType, t == "/" {
            viewModel.updateBlock(id: bid, blockType: .paragraph(""))
        }
        slashBlockId = nil
        slashFilter = ""
    }

    private func handleSlashCommandSelected(_ cmd: SlashCommand) {
        guard let blockId = slashBlockId ?? viewModel.blocks.first?.id else { return }
        clearSlashFromBlock(blockId)
        withAnimation(.easeOut(duration: 0.18)) { showSlashPalette = false }
        slashBlockId = nil
        slashFilter = ""

        switch cmd.id {
        case "text":
            // Focus stays on the current paragraph — nothing to insert
            focusedBlockId = blockId
        case "h1":   insertBlockType(.heading(level: 1, text: ""), at: blockId)
        case "h2":   insertBlockType(.heading(level: 2, text: ""), at: blockId)
        case "h3":   insertBlockType(.heading(level: 3, text: ""), at: blockId)
        case "bullet":    insertBlockType(.bulletList([""]), at: blockId)
        case "numbered":  insertBlockType(.numberedList([""]), at: blockId)
        case "checklist": insertBlockType(.todo(items: [TodoItem(text: "", done: false)]), at: blockId)
        case "quote":     insertBlockType(.callout(text: ""), at: blockId)
        case "divider":   insertBlockType(.divider, at: blockId)
        case "code":  insertBlockType(.codeCard(language: "Python", code: "", stdin: "", stdout: ""), at: blockId)
        case "math":  insertBlockType(.mathBlock(latex: ""), at: blockId)
        case "graph": insertBlockType(.graphBlock(expression: ""), at: blockId)

        case "scan_notes":
            showPhotoToTextFlowSheet = true

        case "voice_note":
            voiceInsertAnchorId = blockId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showVoiceForJournal = true
            }

        case "ask_feynman":
            // Focus the inline chat input bar
            focusedBlockId = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isChatInputFocused = true
            }

        case "flashcards":
            let newId = viewModel.insertFlashcardSet(after: blockId)
            focusedBlockId = viewModel.blocks.first(where: { $0.id == newId })?.id
            Task { await viewModel.generateFlashcards(blockId: newId) }

        case "practice":
            let newId = viewModel.insertPracticeProblems(after: blockId)
            focusedBlockId = viewModel.blocks.first(where: { $0.id == newId })?.id
            Task { await viewModel.generatePracticeProblems(blockId: newId) }

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
                    VStack(alignment: .leading, spacing: 14) {
                    if viewModel.blocks.count == 1, isBlockEmpty(viewModel.blocks[0]) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Start with")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Type / for commands")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }

                        HStack(spacing: 10) {
                            // ── Scan notes — hero action ──────────────────
                            Button {
                                Haptics.impact(.light)
                                showPhotoToTextFlowSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(Color.opennoteGreen)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Scan Notes")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.opennoteGreen)
                                        Text("Photo → text")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(Color.opennoteGreen.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.opennoteLightGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.opennoteGreen.opacity(0.22), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            // ── Block-type quick insert menu ──────────────
                            Menu {
                                Button("Heading 1") { insertBlockType(.heading(level: 1, text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Heading 2") { insertBlockType(.heading(level: 2, text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Heading 3") { insertBlockType(.heading(level: 3, text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Bullet List") { insertBlockType(.bulletList([""]), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Numbered List") { insertBlockType(.numberedList([""]), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("To-do List") { insertBlockType(.todo(items: [TodoItem(text: "", done: false)]), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Callout / Quote") { insertBlockType(.callout(text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                                Button("Code Block") { insertBlockType(.codeCard(language: "Python", code: "", stdin: "", stdout: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
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
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("Blocks")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
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
                // Transparent tap-away dismissal
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { dismissSlashPalette() }

                // Palette anchored to the bottom of the content area (sits above keyboard)
                VStack {
                    Spacer()
                    SlashCommandPaletteView(onSelect: handleSlashCommandSelected)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
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

    /// Inserts text from the inline Feynman chat into the journal as a new paragraph block.
    private func insertTextFromChat(_ text: String) {
        isChatInputFocused = false
        let anchorId = focusedBlockId ?? viewModel.blocks.last?.id
        guard let id = anchorId else { return }
        let newBlock = NoteBlock(orderIndex: 0, blockType: .paragraph(text))
        viewModel.insertBlock(after: id, newBlock: newBlock)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedBlockId = newBlock.id
        }
    }
}

extension NoteBlock.BlockType {
    var isAIPrompt: Bool {
        if case .aiPrompt = self { return true }
        return false
    }
}

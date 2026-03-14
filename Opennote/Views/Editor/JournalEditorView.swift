import SwiftUI

/// Journal Editor - clean design matching spec. No "Generate video" section.
struct JournalEditorView: View {
    let journal: Journal
    var onDelete: (() -> Void)?
    var onCloneSelect: ((Journal) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(NotesStore.self) private var notesStore
    @State private var focusedBlockId: UUID?
    @State private var isKeyboardVisible = false
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
    // Voice note — live dictation directly into a journal block
    @State private var showVoiceForJournal = false
    @State private var voiceInsertAnchorId: UUID?
    @State private var journalSpeechService = SpeechToTextService()
    @State private var voiceLiveBlockId: UUID?

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
                service: journalSpeechService,
                insertIntoPrompt: false,
                onLiveUpdate: { newText in
                    // Stream partial results directly into the live paragraph block
                    if let id = voiceLiveBlockId {
                        viewModel.updateBlock(id: id, blockType: .paragraph(newText))
                    }
                },
                onInsert: { _ in
                    // Text is already live in the journal block — just tidy up
                    showVoiceForJournal = false
                    if let id = voiceLiveBlockId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedBlockId = id
                        }
                    }
                    voiceLiveBlockId = nil
                    journalSpeechService.reset()
                },
                onDismiss: {
                    // Cancel — remove the live block if it exists
                    showVoiceForJournal = false
                    if let id = voiceLiveBlockId {
                        viewModel.deleteBlock(id: id)
                    }
                    voiceLiveBlockId = nil
                    journalSpeechService.reset()
                }
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
                isNoteFocused: isKeyboardVisible && !isChatInputFocused,
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
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
            startJournalVoiceDictation(anchorId: blockId)

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

    // MARK: "Start with" quick-action bar

    private var startWithBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Start with")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Type / for commands")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                // ── + All commands (slash palette) ────────────────
                Button {
                    Haptics.impact(.light)
                    slashBlockId = viewModel.blocks.first?.id
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSlashPalette = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.opennoteGreen)
                        .frame(width: 48, height: 48)
                        .background(Color.opennoteLightGreen.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(Color.opennoteGreen.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                // ── Camera — scan notes ───────────────────────────
                Button {
                    Haptics.impact(.light)
                    showPhotoToTextFlowSheet = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 48, height: 48)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)

                // ── Mic — voice note ──────────────────────────────
                Button {
                    Haptics.impact(.light)
                    startJournalVoiceDictation(anchorId: viewModel.blocks.last?.id)
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 48, height: 48)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var editorContent: some View {
        ZStack(alignment: .topLeading) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                    if viewModel.blocks.count == 1, isBlockEmpty(viewModel.blocks[0]) {
                        startWithBar
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
                            onSlashTriggered: handleSlashTriggered,
                            onBackspaceOnEmpty: { deleteEmptyBlockAndFocusPrevious(block.id) }
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
                    SlashCommandPaletteView(
                        onSelect: handleSlashCommandSelected,
                        onDismiss: dismissSlashPalette
                    )
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

    /// Creates a live paragraph block then opens the voice dictation sheet.
    /// As the user speaks, the block is updated in real time via `onLiveUpdate`.
    private func startJournalVoiceDictation(anchorId: UUID?) {
        journalSpeechService.reset()
        let anchor = anchorId ?? viewModel.blocks.last?.id
        guard let anchor else { return }
        focusedBlockId = nil // dismiss any open keyboard

        // Create an empty block that will be filled live
        let liveBlock = NoteBlock(orderIndex: 0, blockType: .paragraph(""))
        viewModel.insertBlock(after: anchor, newBlock: liveBlock)
        voiceLiveBlockId = liveBlock.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            showVoiceForJournal = true
        }
    }

    /// Deletes an empty paragraph block and moves focus (cursor) to the end of the block above it.
    /// If the block is the only one, clears its text but keeps it (mirrors Apple Notes behaviour).
    private func deleteEmptyBlockAndFocusPrevious(_ blockId: UUID) {
        guard let idx = viewModel.blocks.firstIndex(where: { $0.id == blockId }) else { return }
        guard viewModel.blocks.count > 1 else { return } // keep at least one block

        let previousId = idx > 0 ? viewModel.blocks[idx - 1].id : nil
        viewModel.deleteBlock(id: blockId)

        if let prevId = previousId {
            // Small delay lets SwiftUI finish the deletion render before we steal focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusedBlockId = prevId
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

    /// Inserts the full Feynman response into the journal.
    /// Splits on double-newlines so each paragraph becomes its own block,
    /// avoiding any UITextView newline-interception edge cases.
    private func insertTextFromChat(_ text: String) {
        isChatInputFocused = false
        // Always anchor to the very last block so content appends at the bottom
        guard var anchorId = viewModel.blocks.last?.id else { return }

        // Split into paragraphs; fall back to the whole text as one block
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let chunks = paragraphs.isEmpty ? [text] : paragraphs

        for chunk in chunks {
            let block = NoteBlock(orderIndex: 0, blockType: .paragraph(chunk))
            viewModel.insertBlock(after: anchorId, newBlock: block)
            anchorId = block.id
        }
        // Scroll to the last inserted block without stealing the keyboard
        let lastId = anchorId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedBlockId = lastId
        }
    }
}

extension NoteBlock.BlockType {
    var isAIPrompt: Bool {
        if case .aiPrompt = self { return true }
        return false
    }
}

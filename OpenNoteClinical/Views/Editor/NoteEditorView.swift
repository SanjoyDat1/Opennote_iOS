import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var viewModel: NoteViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedBlockId: UUID?
    @FocusState private var isTitleFocused: Bool
    @State private var aiAssistantVM = AIAssistantViewModel()
    @State private var showAISidebar = false
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                titleField
                Divider()
                
                ForEach(viewModel.blocks) { block in
                    BlockRowView(
                        block: block,
                        focusedBlockId: $focusedBlockId,
                        viewModel: viewModel,
                        onReturnKey: { insertParagraphAfter(block.id) }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                contextToolbar
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAISidebar = true
                } label: {
                    Image(systemName: "sparkles")
                }
            }
        }
        .inspector(isPresented: $showAISidebar) {
            AIAssistantSidebarView(viewModel: aiAssistantVM)
        }
        .onAppear {
            aiAssistantVM.contextProvider = { [viewModel] in viewModel.blocksToMarkdown() }
        }
        .onAppear {
            if viewModel.blocks.isEmpty || (viewModel.blocks.count == 1 && isBlockEmpty(viewModel.blocks[0])) {
                focusedBlockId = viewModel.blocks.first?.id
            }
        }
        .onDisappear {
            Task {
                await NoteSyncService.shared.syncNoteImmediately(viewModel.note, markdown: viewModel.blocksToMarkdown())
            }
        }
    }
    
    private var titleField: some View {
        TextField("Untitled Note", text: Binding(
            get: { viewModel.title },
            set: { viewModel.title = $0 }
        ))
        .focused($isTitleFocused)
        .font(.title2)
        .fontWeight(.semibold)
    }
    
    @ViewBuilder
    private var contextToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                blockTypeButton("H1", systemImage: "textformat.size.larger") {
                    insertHeading(1)
                }
                blockTypeButton("H2", systemImage: "textformat.size") {
                    insertHeading(2)
                }
                blockTypeButton("H3", systemImage: "textformat") {
                    insertHeading(3)
                }
                blockTypeButton("Bullet", systemImage: "list.bullet") {
                    insertBulletList()
                }
                blockTypeButton("Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                    insertCodeCard()
                }
                blockTypeButton("1.", systemImage: "list.number") {
                    insertNumberedList()
                }
                blockTypeButton("AI", systemImage: "sparkles") {
                    insertAIPrompt()
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    private func blockTypeButton(_ label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Label(label, systemImage: systemImage)
                .font(.caption)
        }
    }
    
    private func insertParagraphAfter(_ blockId: UUID) {
        let newId = viewModel.insertParagraph(after: blockId)
        focusedBlockId = newId
    }
    
    private func insertHeading(_ level: Int) {
        guard let targetId = focusedBlockId ?? viewModel.blocks.last?.id else {
            viewModel.insertBlock(at: 0, block: NoteBlock(orderIndex: 0, blockType: .heading(level: level, text: "")))
            if let first = viewModel.blocks.first { focusedBlockId = first.id }
            return
        }
        viewModel.insertHeading(level: level, after: targetId)
        if let idx = viewModel.blocks.firstIndex(where: { $0.id == targetId }),
           idx + 1 < viewModel.blocks.count {
            focusedBlockId = viewModel.blocks[idx + 1].id
        }
    }
    
    private func insertBulletList() {
        guard let targetId = focusedBlockId ?? viewModel.blocks.last?.id else {
            viewModel.insertBlock(at: 0, block: NoteBlock(orderIndex: 0, blockType: .bulletList([""])))
            if let first = viewModel.blocks.first { focusedBlockId = first.id }
            return
        }
        viewModel.insertBulletList(after: targetId)
        if let idx = viewModel.blocks.firstIndex(where: { $0.id == targetId }),
           idx + 1 < viewModel.blocks.count {
            focusedBlockId = viewModel.blocks[idx + 1].id
        }
    }
    
    private func insertCodeCard() {
        guard let targetId = focusedBlockId ?? viewModel.blocks.last?.id else {
            viewModel.insertBlock(at: 0, block: NoteBlock(orderIndex: 0, blockType: .codeCard(language: "swift", code: "")))
            if let first = viewModel.blocks.first { focusedBlockId = first.id }
            return
        }
        viewModel.insertCodeCard(after: targetId)
        if let idx = viewModel.blocks.firstIndex(where: { $0.id == targetId }),
           idx + 1 < viewModel.blocks.count {
            focusedBlockId = viewModel.blocks[idx + 1].id
        }
    }
    
    private func insertNumberedList() {
        guard let targetId = focusedBlockId ?? viewModel.blocks.last?.id else {
            viewModel.insertBlock(at: 0, block: NoteBlock(orderIndex: 0, blockType: .numberedList([""])))
            if let first = viewModel.blocks.first { focusedBlockId = first.id }
            return
        }
        viewModel.insertNumberedList(after: targetId)
        if let idx = viewModel.blocks.firstIndex(where: { $0.id == targetId }),
           idx + 1 < viewModel.blocks.count {
            focusedBlockId = viewModel.blocks[idx + 1].id
        }
    }
    
    private func insertAIPrompt() {
        guard let targetId = focusedBlockId ?? viewModel.blocks.last?.id else {
            viewModel.insertBlock(at: 0, block: NoteBlock(orderIndex: 0, blockType: .aiPrompt(command: "", response: nil)))
            if let first = viewModel.blocks.first { focusedBlockId = first.id }
            return
        }
        viewModel.insertAIPrompt(after: targetId)
        if let idx = viewModel.blocks.firstIndex(where: { $0.id == targetId }),
           idx + 1 < viewModel.blocks.count {
            focusedBlockId = viewModel.blocks[idx + 1].id
        }
    }
    
    private func isBlockEmpty(_ block: NoteBlock) -> Bool {
        switch block.blockType {
        case .paragraph(let t): return t.isEmpty
        case .heading(_, let t): return t.isEmpty
        case .bulletList(let items): return items.allSatisfy { $0.isEmpty }
        case .numberedList(let items): return items.allSatisfy { $0.isEmpty }
        case .codeCard(_, let c): return c.isEmpty
        case .aiPrompt(let c, _): return c.isEmpty
        }
    }
}

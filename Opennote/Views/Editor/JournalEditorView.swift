import SwiftUI

/// Phase 3: Journal Editor - modular block-based editor with Feynman AI commands
struct JournalEditorView: View {
    let journal: Journal
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedBlockId: UUID?
    @State private var viewModel: JournalEditorViewModel
    @State private var researchQuery = ""

    init(journal: Journal) {
        self.journal = journal
        _viewModel = State(initialValue: JournalEditorViewModel(journalTitle: journal.title))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.opennoteCream
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                editorContent
            }

            researchBar
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.primary)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                feynmanToolbar
            }
        }
        .onAppear {
            if viewModel.blocks.count == 1, isBlockEmpty(viewModel.blocks[0]) {
                focusedBlockId = viewModel.blocks[0].id
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.secondary)
                Text("... /")
                    .font(.system(size: 13, design: .default))
                    .foregroundStyle(.secondary)
                Text(viewModel.journalTitle)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)
            }
            Spacer()
            Button { } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.secondary)
            }
            Button("Share") { }
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.opennoteGreen)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.opennoteCream)
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // "Start with" + Feynman command buttons (when empty or at top)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start with")
                        .font(.system(size: 13, design: .default))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                insertFeynmanBlockAtFirst()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Color.opennoteGreen)
                                    Text("Ask Feynman")
                                        .font(.system(size: 17, design: .default))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.opennoteLightGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Button {
                                // TODO: Generate video
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Color.pink)
                                    Text("Generate a video explanation")
                                        .font(.system(size: 17, design: .default))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.pink.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        Menu {
                            Button("Heading 1") { insertBlockType(.heading(level: 1, text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                            Button("Heading 2") { insertBlockType(.heading(level: 2, text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                            Button("Heading 3") { insertBlockType(.heading(level: 3, text: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                            Button("Bullet List") { insertBlockType(.bulletList([""]), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                            Button("Numbered List") { insertBlockType(.numberedList([""]), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                            Button("Code Block") { insertBlockType(.codeCard(language: "swift", code: ""), at: focusedBlockId ?? viewModel.blocks.first?.id) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                    }
                }

                // Placeholder when no content
                if viewModel.blocks.count == 1, isBlockEmpty(viewModel.blocks[0]) {
                    Text("Start writing or type \"/\" to see commands...")
                        .font(.system(size: 17, design: .default))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                // Block list
                ForEach(viewModel.blocks) { block in
                    BlockRowView(
                        block: block,
                        focusedBlockId: $focusedBlockId,
                        viewModel: viewModel,
                        onReturnKey: { insertParagraphAfter(block.id) }
                    )
                }

                Spacer(minLength: 80)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 60)
    }

    private var feynmanToolbar: some View {
        HStack(spacing: 12) {
            Button {
                if let id = focusedBlockId {
                    let newId = viewModel.insertAIPrompt(after: id)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedBlockId = newId
                    }
                } else {
                    insertFeynmanBlockAtFirst()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.opennoteGreen)
                    Text("Ask Feynman")
                        .font(.system(size: 15, weight: .medium, design: .default))
                }
            }
            Button {
                // Generate video
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                        .foregroundStyle(Color.pink)
                    Text("Generate video")
                        .font(.system(size: 15, weight: .medium, design: .default))
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var researchBar: some View {
        HStack(spacing: 12) {
            Button { } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.opennoteGreen)
            }
            .buttonStyle(.plain)
            TextField("Ask to start research", text: $researchQuery)
                .font(.system(size: 17, design: .default))
                .foregroundStyle(Color.opennoteGreen)
            Button { } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.opennoteGreen)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.opennoteLightGreen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
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
        let newBlock = NoteBlock(orderIndex: 0, blockType: blockType)
        viewModel.insertBlock(after: id, newBlock: newBlock)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedBlockId = newBlock.id
        }
    }

    private func isBlockEmpty(_ block: NoteBlock) -> Bool {
        switch block.blockType {
        case .paragraph(let t): return t.isEmpty
        case .heading(_, let t): return t.isEmpty
        case .bulletList(let i): return i.allSatisfy { $0.isEmpty }
        case .numberedList(let i): return i.allSatisfy { $0.isEmpty }
        case .codeCard(_, let c): return c.isEmpty
        case .aiPrompt(let cmd, _): return cmd.isEmpty
        }
    }
}

extension NoteBlock.BlockType {
    var isAIPrompt: Bool {
        if case .aiPrompt = self { return true }
        return false
    }
}

import SwiftUI

struct BlockRowView: View {
    let block: NoteBlock
    @FocusState.Binding var focusedBlockId: UUID?
    @Bindable var viewModel: JournalEditorViewModel
    let onReturnKey: () -> Void
    var onSlashTriggered: ((UUID, String) -> Void)? = nil

    var body: some View {
        Group {
            switch block.blockType {
            case .paragraph(let text):
                ParagraphBlockView(
                    text: text,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .paragraph($0)) },
                    onSubmit: onReturnKey,
                    onSlashTriggered: onSlashTriggered
                )

            case .heading(let level, let text):
                HeadingBlockView(
                    text: text,
                    level: level,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .heading(level: level, text: $0)) },
                    onSubmit: onReturnKey,
                    onSlashTriggered: onSlashTriggered
                )

            case .bulletList(let items):
                BulletListBlockView(
                    items: items,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .bulletList($0)) },
                    onReturnAtLastItem: onReturnKey
                )

            case .numberedList(let items):
                NumberedListBlockView(
                    items: items,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .numberedList($0)) },
                    onReturnAtLastItem: onReturnKey
                )

            case .codeCard(let language, let code, let stdin, let stdout):
                CodeCardBlockView(
                    code: code,
                    language: language,
                    stdin: stdin,
                    stdout: stdout,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .codeCard(language: $0, code: $1, stdin: $2, stdout: $3)) }
                )

            case .aiPrompt(let command, let response):
                AIPromptBlockView(
                    command: command,
                    response: response,
                    blockId: block.id,
                    isRunning: viewModel.runningAIBlockId == block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .aiPrompt(command: $0, response: response)) },
                    onRun: { Task { await runFeynman(blockId: block.id) } },
                    onAddToNotes: { text in
                        let newBlock = NoteBlock(orderIndex: 0, blockType: .paragraph(text))
                        viewModel.insertBlock(after: block.id, newBlock: newBlock)
                        focusedBlockId = newBlock.id
                    },
                    onClose: {
                        if viewModel.blocks.count > 1 {
                            viewModel.deleteBlock(id: block.id)
                        } else {
                            viewModel.updateBlock(id: block.id, blockType: .paragraph(""))
                        }
                    }
                )
            case .graphBlock(let expression):
                GraphBlockView(
                    expression: expression,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .graphBlock(expression: $0)) }
                )
            case .mathBlock(let latex):
                MathBlockView(
                    latex: latex,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .mathBlock(latex: $0)) }
                )
            case .callout(let text):
                CalloutBlockView(
                    text: text,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .callout(text: $0)) }
                )
            case .todo(let items):
                TodoBlockView(
                    items: items,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .todo(items: $0)) },
                    onReturnAtLastItem: onReturnKey
                )
            case .divider:
                DividerBlockView()
            case .flashcardSet(let items):
                FlashcardBlockView(
                    items: items,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .flashcardSet(items: $0)) },
                    onGenerate: { Task { await generateFlashcards(blockId: block.id) } },
                    isGenerating: viewModel.runningAIBlockId == block.id
                )
            case .practiceProblems(let items):
                PracticeProblemsBlockView(
                    items: items,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .practiceProblems(items: $0)) },
                    onGenerate: { Task { await generatePracticeProblems(blockId: block.id) } },
                    isGenerating: viewModel.runningAIBlockId == block.id
                )
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                if viewModel.blocks.count > 1 {
                    viewModel.deleteBlock(id: block.id)
                }
            } label: {
                Label("Delete Block", systemImage: "trash")
            }
        }
    }

    private func runFeynman(blockId: UUID) async {
        await viewModel.runAIBlock(blockId: blockId)
    }

    private func generateFlashcards(blockId: UUID) async {
        await viewModel.generateFlashcards(blockId: blockId)
    }

    private func generatePracticeProblems(blockId: UUID) async {
        await viewModel.generatePracticeProblems(blockId: blockId)
    }
}

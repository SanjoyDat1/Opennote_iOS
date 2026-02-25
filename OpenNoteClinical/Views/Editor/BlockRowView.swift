import SwiftUI
import SwiftData

/// Dispatches to the appropriate block view based on BlockType.
struct BlockRowView: View {
    let block: NoteBlock
    @FocusState.Binding var focusedBlockId: UUID?
    @Bindable var viewModel: NoteViewModel
    let onReturnKey: () -> Void
    
    var body: some View {
        Group {
            switch block.blockType {
            case .paragraph(let text):
                ParagraphBlockView(
                    text: text,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .paragraph($0)) },
                    onSubmit: onReturnKey
                )
                
            case .heading(let level, let text):
                HeadingBlockView(
                    text: text,
                    level: level,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .heading(level: level, text: $0)) },
                    onSubmit: onReturnKey
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
                
            case .codeCard(let language, let code):
                CodeCardBlockView(
                    code: code,
                    language: language,
                    blockId: block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .codeCard(language: language, code: $0)) }
                )
                
            case .aiPrompt(let command, let response):
                AIPromptBlockView(
                    command: command,
                    response: response,
                    blockId: block.id,
                    isRunning: viewModel.runningAIBlockId == block.id,
                    focusedBlockId: $focusedBlockId,
                    onUpdate: { viewModel.updateBlock(id: block.id, blockType: .aiPrompt(command: $0, response: response)) },
                    onRun: { Task { await viewModel.runAIBlock(blockId: block.id) } }
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
}

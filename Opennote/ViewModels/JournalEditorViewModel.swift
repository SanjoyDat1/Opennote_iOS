import Foundation

@Observable
final class JournalEditorViewModel {
    var blocks: [NoteBlock]
    var journalTitle: String
    var runningAIBlockId: UUID?

    init(journalTitle: String, blocks: [NoteBlock]? = nil) {
        self.journalTitle = journalTitle
        self.blocks = blocks ?? [NoteBlock(orderIndex: 0, blockType: .paragraph(""))]
    }

    func insertBlock(at index: Int, block: NoteBlock) {
        var updated = blocks
        let b = NoteBlock(id: block.id, orderIndex: index, blockType: block.blockType)
        updated.insert(b, at: index)
        blocks = reindex(updated)
    }

    func insertBlock(after blockId: UUID, newBlock: NoteBlock) {
        guard let idx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        insertBlock(at: idx + 1, block: newBlock)
    }

    func updateBlock(id: UUID, blockType: NoteBlock.BlockType) {
        guard let idx = blocks.firstIndex(where: { $0.id == id }) else { return }
        var updated = blocks
        updated[idx] = NoteBlock(id: id, orderIndex: idx, blockType: blockType)
        blocks = reindex(updated)
    }

    func deleteBlock(id: UUID) {
        var updated = blocks.filter { $0.id != id }
        if updated.isEmpty {
            updated = [NoteBlock(orderIndex: 0, blockType: .paragraph(""))]
        }
        blocks = reindex(updated)
    }

    func insertParagraph(after blockId: UUID) -> UUID {
        let newBlock = NoteBlock(orderIndex: 0, blockType: .paragraph(""))
        insertBlock(after: blockId, newBlock: newBlock)
        return newBlock.id
    }

    func insertHeading(level: Int, after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .heading(level: level, text: "")))
    }

    func insertBulletList(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .bulletList([""])))
    }

    func insertNumberedList(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .numberedList([""])))
    }

    func insertCodeCard(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .codeCard(language: "swift", code: "")))
    }

    @discardableResult
    func insertAIPrompt(after blockId: UUID) -> UUID {
        let newBlock = NoteBlock(orderIndex: 0, blockType: .aiPrompt(command: "", response: nil))
        insertBlock(after: blockId, newBlock: newBlock)
        return newBlock.id
    }

    func blocksToMarkdown() -> String {
        NoteBlock.toMarkdown(blocks)
    }

    /// Run Feynman AI on an AI prompt block. Streams response into a new paragraph block below.
    @MainActor
    func runAIBlock(blockId: UUID) async {
        guard let idx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        let block = blocks[idx]
        guard case .aiPrompt(let command, _) = block.blockType,
              !command.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        runningAIBlockId = blockId
        defer { runningAIBlockId = nil }

        let newParagraphId = insertParagraph(after: blockId)
        var streamedContent = ""

        let openAI = OpenAIService.shared
        guard openAI.isConfigured else {
            updateBlock(id: newParagraphId, blockType: .paragraph("Add your OpenAI API key in OpenAIConfig.swift to use Feynman."))
            return
        }

        let messages: [[String: String]] = [["role": "user", "content": command]]

        do {
            for try await delta in openAI.streamChat(messages: messages, systemContext: blocksToMarkdown()) {
                streamedContent += delta
                updateBlock(id: newParagraphId, blockType: .paragraph(streamedContent))
            }
            updateBlock(id: blockId, blockType: .aiPrompt(command: command, response: streamedContent))
        } catch {
            updateBlock(id: newParagraphId, blockType: .paragraph("Error: \(error.localizedDescription)"))
        }
    }

    private func reindex(_ blocks: [NoteBlock]) -> [NoteBlock] {
        blocks.enumerated().map { i, b in
            NoteBlock(id: b.id, orderIndex: i, blockType: b.blockType)
        }
    }
}

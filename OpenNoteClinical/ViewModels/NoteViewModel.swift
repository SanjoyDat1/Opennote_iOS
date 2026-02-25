import Foundation
import SwiftData

@Observable
final class NoteViewModel {
    var note: Note
    private let modelContext: ModelContext
    
    /// Block ID currently streaming an AI response.
    var runningAIBlockId: UUID?
    
    var blocks: [NoteBlock] {
        get { note.blocks }
        set {
            note.blocks = newValue
            note.updatedAt = Date()
            save()
        }
    }
    
    var title: String {
        get { note.title }
        set {
            note.title = newValue
            note.updatedAt = Date()
            save()
        }
    }
    
    init(note: Note, modelContext: ModelContext) {
        self.note = note
        self.modelContext = modelContext
    }
    
    func insertBlock(at index: Int, block: NoteBlock) {
        var updated = blocks
        let blockWithOrder = NoteBlock(id: block.id, orderIndex: index, blockType: block.blockType)
        updated.insert(blockWithOrder, at: index)
        updated = reindex(updated)
        blocks = updated
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
    
    func insertHeading(level: Int, after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .heading(level: level, text: "")))
    }
    
    func insertParagraph(after blockId: UUID) -> UUID {
        let newBlock = NoteBlock(orderIndex: 0, blockType: .paragraph(""))
        insertBlock(after: blockId, newBlock: newBlock)
        return newBlock.id
    }
    
    func insertBulletList(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .bulletList([""])))
    }
    
    func insertAIPrompt(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .aiPrompt(command: "", response: nil)))
    }
    
    func insertCodeCard(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .codeCard(language: "swift", code: "")))
    }
    
    func insertNumberedList(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .numberedList([""])))
    }
    
    /// Runs the AI block: streams response into a new paragraph block below.
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
        guard openAI.isConfigured else { return }
        
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
    
    private func save() {
        try? modelContext.save()
        Task {
            await NoteSyncService.shared.syncNote(note, markdown: blocksToMarkdown())
        }
    }
    
    /// Serializes the current blocks into clean Markdown. Used as live clinical context for the AI.
    func blocksToMarkdown() -> String {
        blocksToMarkdown(blocks)
    }
    
    /// Serializes the given blocks into clean Markdown.
    func blocksToMarkdown(_ blocks: [NoteBlock]) -> String {
        NoteBlock.toMarkdown(blocks)
    }
}

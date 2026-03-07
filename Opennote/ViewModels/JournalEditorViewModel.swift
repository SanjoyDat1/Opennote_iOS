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
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .codeCard(language: "Python", code: "", stdin: "", stdout: "")))
    }

    @discardableResult
    func insertAIPrompt(after blockId: UUID) -> UUID {
        let newBlock = NoteBlock(orderIndex: 0, blockType: .aiPrompt(command: "", response: nil))
        insertBlock(after: blockId, newBlock: newBlock)
        return newBlock.id
    }

    @discardableResult
    func insertGraphBlock(after blockId: UUID) -> UUID {
        let newBlock = NoteBlock(orderIndex: 0, blockType: .graphBlock(expression: ""))
        insertBlock(after: blockId, newBlock: newBlock)
        return newBlock.id
    }

    @discardableResult
    func insertMathBlock(after blockId: UUID) -> UUID {
        let newBlock = NoteBlock(orderIndex: 0, blockType: .mathBlock(latex: ""))
        insertBlock(after: blockId, newBlock: newBlock)
        return newBlock.id
    }

    func insertCallout(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .callout(text: "")))
    }

    func insertTodo(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .todo(items: [TodoItem(text: "", done: false)])))
    }

    func insertDivider(after blockId: UUID) {
        insertBlock(after: blockId, newBlock: NoteBlock(orderIndex: 0, blockType: .divider))
    }

    func blocksToMarkdown() -> String {
        NoteBlock.toMarkdown(blocks)
    }

    /// Total word count across all text content in blocks.
    func wordCount() -> Int {
        blocks.reduce(0) { count, block in
            let text = blockTextContent(block)
            let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            return count + words.count
        }
    }

    private func blockTextContent(_ block: NoteBlock) -> String {
        switch block.blockType {
        case .heading(_, let t): return t
        case .paragraph(let t): return t
        case .bulletList(let items): return items.joined(separator: " ")
        case .numberedList(let items): return items.joined(separator: " ")
        case .codeCard(_, let c, _, _): return c
        case .aiPrompt(let cmd, let r): return cmd + " " + (r ?? "")
        case .callout(let t): return t
        case .todo(let items): return items.map(\.text).joined(separator: " ")
        case .divider: return ""
        case .graphBlock(let e): return e
        case .mathBlock(let l): return l
        case .flashcardSet(let items): return items.map { $0.front + " " + $0.back }.joined(separator: " ")
        case .practiceProblems(let items): return items.map { $0.question + " " + $0.answer }.joined(separator: " ")
        }
    }

    func insertFlashcardSet(after blockId: UUID) -> UUID {
        let newBlock = NoteBlock(orderIndex: 0, blockType: .flashcardSet(items: []))
        insertBlock(after: blockId, newBlock: newBlock)
        return newBlock.id
    }

    func insertPracticeProblems(after blockId: UUID) -> UUID {
        let newBlock = NoteBlock(orderIndex: 0, blockType: .practiceProblems(items: []))
        insertBlock(after: blockId, newBlock: newBlock)
        return newBlock.id
    }

    @MainActor
    func generateFlashcards(blockId: UUID) async {
        guard let idx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        guard case .flashcardSet = blocks[idx].blockType else { return }

        runningAIBlockId = blockId
        defer { runningAIBlockId = nil }

        let context = blocksToMarkdown()
        let openAI = OpenAIService.shared
        guard openAI.isConfigured else {
            updateBlock(id: blockId, blockType: .flashcardSet(items: [FlashcardItem(front: "Add your OpenAI API key in OpenAIConfig to use Feynman.", back: "")]))
            return
        }

        if let pairs = await openAI.generateFlashcards(from: context) {
            let items = pairs.map { FlashcardItem(front: $0.front, back: $0.back) }
            updateBlock(id: blockId, blockType: .flashcardSet(items: items))
        } else {
            updateBlock(id: blockId, blockType: .flashcardSet(items: [FlashcardItem(front: "Could not generate flashcards. Try again.", back: "")]))
        }
    }

    @MainActor
    func generatePracticeProblems(blockId: UUID) async {
        guard let idx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        guard case .practiceProblems = blocks[idx].blockType else { return }

        runningAIBlockId = blockId
        defer { runningAIBlockId = nil }

        let context = blocksToMarkdown()
        let openAI = OpenAIService.shared
        guard openAI.isConfigured else {
            updateBlock(id: blockId, blockType: .practiceProblems(items: [PracticeProblemItem(question: "Add your OpenAI API key in OpenAIConfig to use Feynman.", answer: "")]))
            return
        }

        if let pairs = await openAI.generatePracticeProblems(from: context) {
            let items = pairs.map { PracticeProblemItem(question: $0.question, answer: $0.answer) }
            updateBlock(id: blockId, blockType: .practiceProblems(items: items))
        } else {
            updateBlock(id: blockId, blockType: .practiceProblems(items: [PracticeProblemItem(question: "Could not generate practice problems. Try again.", answer: "")]))
        }
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

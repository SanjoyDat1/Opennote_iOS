import Foundation

/// In-memory + UserDefaults persistence for journals and papers (MVP).
@Observable
final class NotesStore {
    var journals: [Journal]
    var papers: [Paper]
    /// Temporary storage for blocks when cloning a journal. Cleared after the new editor reads them.
    var pendingBlocksForJournalId: [String: [NoteBlock]] = [:]

    private let journalsKey = "opennote.journals"
    private let papersKey = "opennote.papers"
    
    init() {
        self.journals = Self.loadJournals()
        self.papers = Self.loadPapers()
    }
    
    func addJournal(_ journal: Journal) {
        journals.append(journal)
        save()
    }
    
    func addPaper(_ paper: Paper) {
        papers.append(paper)
        save()
    }
    
    func updateJournal(_ journal: Journal) {
        guard let idx = journals.firstIndex(where: { $0.id == journal.id }) else { return }
        journals[idx] = journal
        save()
    }
    
    func updatePaper(_ paper: Paper) {
        guard let idx = papers.firstIndex(where: { $0.id == paper.id }) else { return }
        papers[idx] = paper
        save()
    }
    
    func deleteJournal(id: String) {
        journals.removeAll { $0.id == id }
        deleteBlocks(forJournalId: id)
        save()
    }
    
    func deletePaper(id: String) {
        papers.removeAll { $0.id == id }
        save()
    }
    
    // MARK: - Block persistence (one JSON file per journal in Application Support)

    private var blocksDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("opennote/blocks", isDirectory: true)
    }

    private func blocksURL(for journalId: String) -> URL {
        blocksDirectory.appendingPathComponent("\(journalId).json")
    }

    /// Writes the full block array for a journal to disk atomically.
    func saveBlocks(_ blocks: [NoteBlock], forJournalId id: String) {
        let dir = blocksDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(blocks) else { return }
        try? data.write(to: blocksURL(for: id), options: .atomic)
    }

    /// Reads the saved block array for a journal. Returns nil if not yet persisted.
    func loadBlocks(forJournalId id: String) -> [NoteBlock]? {
        guard let data = try? Data(contentsOf: blocksURL(for: id)) else { return nil }
        return try? JSONDecoder().decode([NoteBlock].self, from: data)
    }

    /// Removes the block file when a journal is deleted.
    func deleteBlocks(forJournalId id: String) {
        try? FileManager.default.removeItem(at: blocksURL(for: id))
    }

    /// Returns a short plain-text preview extracted from the first meaningful blocks.
    /// Returns nil if no content has been saved yet.
    func loadPreview(forJournalId id: String) -> String? {
        guard let blocks = loadBlocks(forJournalId: id) else { return nil }
        var snippets: [String] = []
        var charCount = 0
        for block in blocks {
            let text = blockPreviewText(block)
            guard !text.isEmpty else { continue }
            snippets.append(text)
            charCount += text.count
            if charCount >= 200 { break }
        }
        let joined = snippets.joined(separator: "  ·  ")
        return joined.isEmpty ? nil : String(joined.prefix(220))
    }

    private func blockPreviewText(_ block: NoteBlock) -> String {
        switch block.blockType {
        case .paragraph(let t):        return t.trimmingCharacters(in: .whitespacesAndNewlines)
        case .heading(_, let t):       return t.trimmingCharacters(in: .whitespacesAndNewlines)
        case .callout(let t):          return t.trimmingCharacters(in: .whitespacesAndNewlines)
        case .bulletList(let items):   return items.filter { !$0.isEmpty }.joined(separator: " · ")
        case .numberedList(let items): return items.filter { !$0.isEmpty }.joined(separator: " · ")
        case .todo(let items):         return items.map(\.text).filter { !$0.isEmpty }.joined(separator: " · ")
        default: return ""
        }
    }

    // MARK: - Metadata persistence

    private func save() {
        if let data = try? JSONEncoder().encode(journals.map { JournalDTO.from($0) }) {
            UserDefaults.standard.set(data, forKey: journalsKey)
        }
        if let data = try? JSONEncoder().encode(papers.map { PaperDTO.from($0) }) {
            UserDefaults.standard.set(data, forKey: papersKey)
        }
    }
    
    private static func loadJournals() -> [Journal] {
        guard let data = UserDefaults.standard.data(forKey: "opennote.journals"),
              let dtos = try? JSONDecoder().decode([JournalDTO].self, from: data),
              !dtos.isEmpty else {
            return [Journal(title: "My First Journal", lastEdited: Date())]
        }
        return dtos.map { $0.toJournal() }
    }
    
    private static func loadPapers() -> [Paper] {
        guard let data = UserDefaults.standard.data(forKey: "opennote.papers"),
              let dtos = try? JSONDecoder().decode([PaperDTO].self, from: data),
              !dtos.isEmpty else {
            return [Paper(title: "Untitled Paper", lastEdited: Date())]
        }
        return dtos.map { $0.toPaper() }
    }
}

private struct JournalDTO: Codable {
    let id: String
    let title: String
    let lastEdited: Date
    let isFavorite: Bool?
    
    static func from(_ j: Journal) -> JournalDTO {
        JournalDTO(id: j.id, title: j.title, lastEdited: j.lastEdited, isFavorite: j.isFavorite)
    }
    
    func toJournal() -> Journal {
        Journal(id: id, title: title, lastEdited: lastEdited, isFavorite: isFavorite ?? false)
    }
}

private struct PaperDTO: Codable {
    let id: String
    let title: String
    let lastEdited: Date
    let content: String?
    let isFavorite: Bool?
    
    static func from(_ p: Paper) -> PaperDTO {
        PaperDTO(id: p.id, title: p.title, lastEdited: p.lastEdited, content: p.content, isFavorite: p.isFavorite)
    }
    
    func toPaper() -> Paper {
        Paper(id: id, title: title, lastEdited: lastEdited, content: content ?? "", isFavorite: isFavorite ?? false)
    }
}

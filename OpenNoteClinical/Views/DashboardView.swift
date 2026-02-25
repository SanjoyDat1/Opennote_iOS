import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var notes: [Note] = []
    @State private var selectedNote: Note?
    @State private var searchText = ""
    @State private var searchResults: [UUID] = []
    @State private var isSearching = false
    @State private var searchError: String?
    
    private var currentUserId: UUID? {
        authViewModel.currentUser?.id
    }
    
    /// Notes to display: semantically filtered when searching, otherwise all.
    private var displayedNotes: [Note] {
        if isSearching && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let ids = Set(searchResults)
            return notes.filter { ids.contains($0.id) }
                .sorted { a, b in
                    guard let ia = searchResults.firstIndex(of: a.id),
                          let ib = searchResults.firstIndex(of: b.id) else { return false }
                    return ia < ib
                }
        }
        return notes
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty && !isSearching {
                    ContentUnavailableView {
                        Label("No Notes", systemImage: "doc.text")
                    } description: {
                        Text("Tap + to create your first clinical note.")
                    }
                } else if displayedNotes.isEmpty && isSearching {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(displayedNotes, id: \.id) { note in
                            Button {
                                selectedNote = note
                            } label: {
                                NoteRowView(note: note)
                            }
                        }
                        .onDelete(perform: deleteNotes)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by concept…")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    isSearching = false
                    searchResults = []
                    searchError = nil
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out") {
                        Task { await authViewModel.signOut() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createNewNote()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(item: $selectedNote) { note in
                NoteEditorView(viewModel: NoteViewModel(note: note, modelContext: modelContext))
            }
            .onAppear {
                fetchNotes()
            }
            .onChange(of: currentUserId) { _, _ in
                fetchNotes()
            }
            .overlay {
                if let err = searchError {
                    VStack {
                        Spacer()
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            isSearching = false
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        Task {
            do {
                let results = try await SemanticSearchService.shared.search(query: query, limit: 10)
                searchResults = results.map { $0.id }
            } catch {
                searchError = error.localizedDescription
                searchResults = []
            }
        }
    }
    
    private func fetchNotes() {
        guard let userId = currentUserId else {
            notes = []
            return
        }
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { $0.userId == userId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        notes = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func createNewNote() {
        guard let userId = currentUserId else { return }
        
        let note = Note(
            userId: userId,
            title: "Untitled Note",
            blocksPayload: try? JSONEncoder().encode([NoteBlock(orderIndex: 0, blockType: .paragraph(""))]),
            updatedAt: Date()
        )
        modelContext.insert(note)
        try? modelContext.save()
        
        notes.insert(note, at: 0)
        selectedNote = note
        
        Task {
            await NoteSyncService.shared.syncNoteImmediately(note, markdown: NoteBlock.toMarkdown(note.blocks))
        }
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            if index < displayedNotes.count {
                let note = displayedNotes[index]
                modelContext.delete(note)
            }
        }
        try? modelContext.save()
        fetchNotes()
    }
}

// MARK: - Note conformance for navigationDestination(item:)
extension Note: Identifiable {}

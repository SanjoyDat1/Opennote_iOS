import SwiftUI

struct MainContainerView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(NotesStore.self) private var notesStore
    @State private var showSidebar = false
    @State private var showInbox = false
    @State private var selectedJournal: Journal?
    @State private var selectedPaper: Paper?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                HomeView(
                    journals: notesStore.journals,
                    papers: notesStore.papers,
                    onCreateJournal: { createJournal() },
                    onCreatePaper: { createPaper() },
                    onSelectJournal: { selectedJournal = $0 },
                    onSelectPaper: { selectedPaper = $0 },
                    onDeleteJournal: { notesStore.deleteJournal(id: $0) },
                    onDeletePaper: { notesStore.deletePaper(id: $0) },
                    onRenameJournal: { notesStore.updateJournal($0) },
                    onRenamePaper: { notesStore.updatePaper($0) },
                    onFavoriteJournal: { notesStore.updateJournal($0) },
                    onFavoritePaper: { notesStore.updatePaper($0) }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Haptics.impact(.light)
                            withAnimation(.easeOut(duration: 0.25)) { showSidebar = true }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(.primary)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showInbox = true
                        } label: {
                            Image(systemName: "tray")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .navigationDestination(item: $selectedJournal) { journal in
                    JournalEditorView(
                        journal: journal,
                        initialBlocks: notesStore.pendingBlocksForJournalId[journal.id],
                        onDelete: {
                            notesStore.deleteJournal(id: journal.id)
                            selectedJournal = nil
                        },
                        onCloneSelect: { newJournal in
                            selectedJournal = newJournal
                        }
                    )
                }
                .navigationDestination(item: $selectedPaper) { paper in
                    PaperEditorView(
                        paper: paper,
                        onDelete: {
                            notesStore.deletePaper(id: paper.id)
                            selectedPaper = nil
                        },
                        onCloneSelect: { newPaper in
                            selectedPaper = newPaper
                        }
                    )
                }
                .sheet(isPresented: $showInbox) {
                    InboxView(isPresented: $showInbox)
                }
                
                // Sidebar overlay
                if showSidebar {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            Haptics.impact(.light)
                            withAnimation(.easeOut(duration: 0.2)) { showSidebar = false }
                        }
                    
                    HStack(spacing: 0) {
                        SidebarView(
                            isPresented: $showSidebar,
                            journals: notesStore.journals,
                            papers: notesStore.papers,
                            onSelectJournal: { journal in
                                selectedJournal = journal
                                showSidebar = false
                            },
                            onSelectPaper: { paper in
                                selectedPaper = paper
                                showSidebar = false
                            },
                            onCreateJournal: {
                                createJournal()
                                showSidebar = false
                            },
                            onCreatePaper: {
                                createPaper()
                                showSidebar = false
                            },
                            onSelectInbox: {
                                showSidebar = false
                                showInbox = true
                            },
                            onDeleteJournal: { notesStore.deleteJournal(id: $0) },
                            onDeletePaper: { notesStore.deletePaper(id: $0) },
                            onRenameJournal: { notesStore.updateJournal($0) },
                            onRenamePaper: { notesStore.updatePaper($0) },
                            onFavoriteJournal: { notesStore.updateJournal($0) },
                            onFavoritePaper: { notesStore.updatePaper($0) }
                        )
                        .frame(maxWidth: 320)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func createJournal() {
        Haptics.impact(.light)
        let journal = Journal(title: "Untitled Journal")
        notesStore.addJournal(journal)
        selectedJournal = journal
    }
    
    private func createPaper() {
        Haptics.impact(.light)
        let paper = Paper(title: "Untitled Paper", content: PaperTemplate.defaultContent)
        notesStore.addPaper(paper)
        selectedPaper = paper
    }
}

// Make Journal/Paper conform to Hashable for navigationDestination
extension Journal: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Journal, rhs: Journal) -> Bool { lhs.id == rhs.id }
}

extension Paper: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Paper, rhs: Paper) -> Bool { lhs.id == rhs.id }
}

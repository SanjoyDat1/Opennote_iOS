import SwiftUI

struct MainContainerView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showSidebar = false
    @State private var showInbox = false
    @State private var selectedJournal: Journal?
    @State private var selectedPaper: Paper?
    
    // MVP mock data
    @State private var journals: [Journal] = [
        Journal(title: "My First Journal", lastEdited: Date())
    ]
    @State private var papers: [Paper] = [
        Paper(title: "Untitled Paper", lastEdited: Date())
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                HomeView(
                    journals: journals,
                    papers: papers,
                    onCreateJournal: { createJournal() },
                    onCreatePaper: { createPaper() },
                    onSelectJournal: { journal in
                        selectedJournal = journal
                    },
                    onSelectPaper: { paper in
                        selectedPaper = paper
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showSidebar = true
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
                    JournalEditorView(journal: journal)
                }
                .navigationDestination(item: $selectedPaper) { paper in
                    PaperEditorView(paper: paper)
                }
                .sheet(isPresented: $showInbox) {
                    InboxView(isPresented: $showInbox)
                }
                
                // Sidebar overlay
                if showSidebar {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showSidebar = false }
                    
                    HStack(spacing: 0) {
                        SidebarView(
                            isPresented: $showSidebar,
                            journals: journals,
                            papers: papers,
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
                            }
                        )
                        .frame(maxWidth: 320)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func createJournal() {
        let journal = Journal(title: "Untitled Journal")
        journals.append(journal)
        selectedJournal = journal
    }
    
    private func createPaper() {
        let paper = Paper(title: "Untitled Paper")
        papers.append(paper)
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

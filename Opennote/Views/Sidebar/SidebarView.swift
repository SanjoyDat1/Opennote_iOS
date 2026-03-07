import SwiftUI

struct SidebarView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Binding var isPresented: Bool
    var journals: [Journal]
    var papers: [Paper]
    var onSelectJournal: (Journal) -> Void
    var onSelectPaper: (Paper) -> Void
    var onCreateJournal: () -> Void
    var onCreatePaper: () -> Void
    var onSelectInbox: () -> Void = {}
    var onDeleteJournal: ((String) -> Void)?
    var onDeletePaper: ((String) -> Void)?
    var onRenameJournal: ((Journal) -> Void)?
    var onRenamePaper: ((Paper) -> Void)?
    var onFavoriteJournal: ((Journal) -> Void)?
    var onFavoritePaper: ((Paper) -> Void)?
    
    @State private var journalsExpanded = true
    @State private var papersExpanded = true
    @State private var journalToRename: Journal?
    @State private var paperToRename: Paper?
    @State private var renameText = ""
    @State private var showJournalRename = false
    @State private var showPaperRename = false
    @State private var showUpgradeSheet = false
    
    private var recentJournals: [Journal] {
        Array(journals.sorted { $0.lastEdited > $1.lastEdited }.prefix(2))
    }
    private var recentPapers: [Paper] {
        Array(papers.sorted { $0.lastEdited > $1.lastEdited }.prefix(2))
    }
    private var hasMoreJournals: Bool { journals.count > 2 }
    private var hasMorePapers: Bool { papers.count > 2 }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Color.opennoteCream
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Top: User profile + New+ button
                HStack {
                    // User profile row with Sign Out
                    Menu {
                        Button("Sign Out") {
                            Task { @MainActor in
                                appViewModel.signOut()
                                isPresented = false
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                )
                            Text(appViewModel.currentUser?.name ?? "Sanjoy")
                                .font(.system(size: 17, weight: .medium, design: .default))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.5))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Menu {
                        Button("New Journal") {
                            onCreateJournal()
                        }
                        Button("New Paper") {
                            onCreatePaper()
                        }
                    } label: {
                        Text("New +")
                            .font(.system(size: 17, weight: .semibold, design: .default))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.opennoteGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Search, Home, Inbox
                VStack(alignment: .leading, spacing: 4) {
                    SidebarRow(icon: "magnifyingglass", title: "Search") {
                        Haptics.selection()
                        isPresented = false
                        // Search: could present search overlay - for MVP, closing sidebar
                    }
                    SidebarRow(icon: "house", title: "Home") {
                        isPresented = false
                    }
                    SidebarRow(icon: "tray", title: "Inbox") {
                        isPresented = false
                        onSelectInbox()
                    }
                }
                .padding(.horizontal, 12)
                
                // Your Journals (expandable)
                DisclosureGroup(isExpanded: $journalsExpanded) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Text("Create Journal")
                            .font(.system(size: 17, design: .default))
                            .foregroundStyle(.primary)
                        if hasMoreJournals {
                            Spacer(minLength: 4)
                            Button {
                                Haptics.selection()
                                isPresented = false
                            } label: {
                                Text("...more")
                                    .font(.system(size: 17, design: .default))
                                    .foregroundStyle(Color.opennoteGreen)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onCreateJournal()
                        isPresented = false
                    }
                    ForEach(recentJournals) { journal in
                        HStack {
                            Text(journal.title)
                                .font(.system(.body, design: .default))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectJournal(journal)
                            isPresented = false
                        }
                        .contextMenu {
                            if onRenameJournal != nil {
                                Button("Rename") {
                                    journalToRename = journal
                                    renameText = journal.title
                                    showJournalRename = true
                                }
                            }
                            if let onFavoriteJournal {
                                Button {
                                    var updated = journal
                                    updated.isFavorite.toggle()
                                    onFavoriteJournal(updated)
                                } label: {
                                    Label(journal.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: journal.isFavorite ? "star.slash" : "star")
                                }
                            }
                            if let onDeleteJournal {
                                Button(role: .destructive) { onDeleteJournal(journal.id) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } label: {
                    Text("Your Journals")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                // Your Papers (expandable)
                DisclosureGroup(isExpanded: $papersExpanded) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Text("Create Paper")
                            .font(.system(.body, design: .default))
                            .foregroundStyle(.primary)
                        if hasMorePapers {
                            Spacer(minLength: 4)
                            Button {
                                Haptics.selection()
                                isPresented = false
                            } label: {
                                Text("...more")
                                    .font(.system(size: 17, design: .default))
                                    .foregroundStyle(Color.opennoteGreen)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onCreatePaper()
                        isPresented = false
                    }
                    
                    ForEach(recentPapers) { paper in
                        HStack {
                            Text(paper.title)
                                .font(.system(.body, design: .default))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectPaper(paper)
                            isPresented = false
                        }
                        .contextMenu {
                            if onRenamePaper != nil {
                                Button("Rename") {
                                    paperToRename = paper
                                    renameText = paper.title
                                    showPaperRename = true
                                }
                            }
                            if let onFavoritePaper {
                                Button {
                                    var updated = paper
                                    updated.isFavorite.toggle()
                                    onFavoritePaper(updated)
                                } label: {
                                    Label(paper.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: paper.isFavorite ? "star.slash" : "star")
                                }
                            }
                            if let onDeletePaper {
                                Button(role: .destructive) { onDeletePaper(paper.id) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } label: {
                    Text("Your Papers")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                Spacer(minLength: 16)

                // Upgrade button at bottom
                Button {
                    Haptics.impact(.light)
                    showUpgradeSheet = true
                } label: {
                    Text("Upgrade")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.opennoteGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeSheet(isPresented: $showUpgradeSheet)
        }
        .alert("Rename Journal", isPresented: $showJournalRename) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { journalToRename = nil }
            Button("Save") {
                if var j = journalToRename {
                    j.title = renameText.isEmpty ? "Untitled Journal" : renameText
                    onRenameJournal?(j)
                }
                journalToRename = nil
            }
        } message: {
            Text("Enter a new title.")
        }
        .alert("Rename Paper", isPresented: $showPaperRename) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { paperToRename = nil }
            Button("Save") {
                if var p = paperToRename {
                    p.title = renameText.isEmpty ? "Untitled Paper" : renameText
                    onRenamePaper?(p)
                }
                paperToRename = nil
            }
        } message: {
            Text("Enter a new title.")
        }
    }
}

struct SidebarRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.primary)
                    .frame(width: 24, alignment: .leading)
                Text(title)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.clear)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SidebarView(
        isPresented: .constant(true),
        journals: [Journal(title: "My First Journal")],
        papers: [Paper(title: "Untitled Paper")],
        onSelectJournal: { _ in },
        onSelectPaper: { _ in },
        onCreateJournal: {},
        onCreatePaper: {},
        onSelectInbox: {},
        onDeleteJournal: nil,
        onDeletePaper: nil,
        onRenameJournal: nil,
        onRenamePaper: nil,
        onFavoriteJournal: nil,
        onFavoritePaper: nil
    )
    .environment(AppViewModel())
}

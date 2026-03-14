import SwiftUI

enum HomeFilter: String, CaseIterable {
    case all = "All"
    case shared = "Shared"
    case owned = "Owned"
}

enum HomeViewMode {
    case grid
    case list
}

struct HomeView: View {
    var journals: [Journal]
    var papers: [Paper]
    var onCreateJournal: () -> Void
    var onCreatePaper: () -> Void
    var onSelectJournal: (Journal) -> Void
    var onSelectPaper: (Paper) -> Void
    var onDeleteJournal: ((String) -> Void)?
    var onDeletePaper: ((String) -> Void)?
    var onRenameJournal: ((Journal) -> Void)?
    var onRenamePaper: ((Paper) -> Void)?
    var onFavoriteJournal: ((Journal) -> Void)?
    var onFavoritePaper: ((Paper) -> Void)?
    
    @State private var filter: HomeFilter = .all
    @State private var viewMode: HomeViewMode = .grid
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header: logo + Home
                HStack(spacing: 8) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("Home")
                        .opennoteMajorHeader()
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Segmented: All | Shared | Owned
                HStack {
                    HStack(spacing: 0) {
                        ForEach(HomeFilter.allCases, id: \.self) { f in
                            Button {
                                filter = f
                            } label: {
                                Text(f.rawValue)
                                    .font(.system(size: 15, weight: .medium, design: .default))
                                    .foregroundStyle(filter == f ? .primary : .secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    Spacer()
                    
                    // Grid/List toggle
                    HStack(spacing: 0) {
                        Button {
                            viewMode = .grid
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(viewMode == .grid ? .primary : .secondary)
                                .frame(width: 40, height: 36)
                                .background(viewMode == .grid ? Color(.systemGray5) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        Button {
                            viewMode = .list
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(viewMode == .list ? .primary : .secondary)
                                .frame(width: 40, height: 36)
                                .background(viewMode == .list ? Color(.systemGray5) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 20)
                
                // Content based on filter
                switch filter {
                case .all:
                    allContent
                case .shared:
                    sharedContent
                case .owned:
                    ownedContent
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color.opennoteCream)
    }
    
    private var allContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Papers section
            papersSection
            
            // Journals section
            journalsSection
        }
    }
    
    private var sharedContent: some View {
        EmptySharedView()
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }
    
    private var ownedContent: some View {
        allContent
    }
    
    // MARK: Papers — compact horizontal scroll row
    private var papersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Papers")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                countBadge(papers.count)
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Create paper compact card
                    Button { onCreatePaper() } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(Color(.systemGray3))
                        }
                        .frame(width: 120, height: 108)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .foregroundStyle(Color(.systemGray3))
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(papers) { paper in
                        PaperCompactCard(
                            paper: paper,
                            onTap: { onSelectPaper(paper) },
                            onDelete: { onDeletePaper?(paper.id) },
                            onRename: onRenamePaper
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Journals — full-width large cards (primary emphasis)
    private var journalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Journals")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                countBadge(journals.count)
                Spacer()
                HStack(spacing: 3) {
                    Text("Last edited")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            // Create journal — large hero card
            Button { onCreateJournal() } label: {
                ZStack {
                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(Color(.systemGray3))
                }
                .frame(maxWidth: .infinity)
                .frame(height: journals.isEmpty ? 280 : 220)
                .background(Color(.systemBackground).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                        .foregroundStyle(Color(.systemGray3))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            // Existing journal cards
            VStack(spacing: 12) {
                ForEach(journals) { journal in
                    JournalLargeCard(
                        journal: journal,
                        onTap: { onSelectJournal(journal) },
                        onDelete: { onDeleteJournal?(journal.id) },
                        onRename: onRenameJournal,
                        onFavorite: onFavoriteJournal
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
    }
}

// MARK: - Empty States
struct EmptySharedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 80, height: 80)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Text("No shared items")
                .font(.system(size: 20, weight: .semibold, design: .default))
            
            Text("You don't have any items that have been shared with you yet.")
                .font(.system(.body, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Create Cards (dashed border)
struct CreateCard: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 100)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(Color(.systemGray4))
            )
        }
        .buttonStyle(.plain)
    }
}

struct CreateCardList: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(Color(.systemGray4))
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paper & Journal Cards
struct PaperCard: View {
    let paper: Paper
    let onTap: () -> Void
    var onDelete: (() -> Void)?
    var onRename: ((Paper) -> Void)?
    var onFavorite: ((Paper) -> Void)?
    
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        if onRename != nil {
                            Button("Rename") {
                                renameText = paper.title
                                showRenameAlert = true
                            }
                        }
                        if let onFavorite {
                            Button {
                                var updated = paper
                                updated.isFavorite.toggle()
                                onFavorite(updated)
                            } label: {
                                Label(paper.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: paper.isFavorite ? "star.slash" : "star")
                            }
                        }
                        if let onDelete {
                            Button(role: .destructive) { onDelete() } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(paper.title)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(paper.lastEdited, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opennoteCard()
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onRename != nil {
                Button("Rename") {
                    renameText = paper.title
                    showRenameAlert = true
                }
            }
            if let onFavorite {
                Button {
                    var updated = paper
                    updated.isFavorite.toggle()
                    onFavorite(updated)
                } label: {
                    Label(paper.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: paper.isFavorite ? "star.slash" : "star")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Rename Paper", isPresented: $showRenameAlert) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                var updated = paper
                updated.title = renameText.isEmpty ? "Untitled Paper" : renameText
                onRename?(updated)
            }
        } message: {
            Text("Enter a new title for this paper.")
        }
    }
}

struct PaperListRow: View {
    let paper: Paper
    let onTap: () -> Void
    var onDelete: (() -> Void)?
    var onRename: ((Paper) -> Void)?
    var onFavorite: ((Paper) -> Void)?
    
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.secondary)
                Text(paper.title)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    if onRename != nil {
                        Button("Rename") {
                            renameText = paper.title
                            showRenameAlert = true
                        }
                    }
                    if let onFavorite {
                        Button {
                            var updated = paper
                            updated.isFavorite.toggle()
                            onFavorite(updated)
                        } label: {
                            Label(paper.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: paper.isFavorite ? "star.slash" : "star")
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive) { onDelete() } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .opennoteCard()
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onRename != nil {
                Button("Rename") {
                    renameText = paper.title
                    showRenameAlert = true
                }
            }
            if let onFavorite {
                Button {
                    var updated = paper
                    updated.isFavorite.toggle()
                    onFavorite(updated)
                } label: {
                    Label(paper.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: paper.isFavorite ? "star.slash" : "star")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Rename Paper", isPresented: $showRenameAlert) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                var updated = paper
                updated.title = renameText.isEmpty ? "Untitled Paper" : renameText
                onRename?(updated)
            }
        } message: {
            Text("Enter a new title.")
        }
    }
}

struct JournalCard: View {
    let journal: Journal
    let onTap: () -> Void
    var onDelete: (() -> Void)?
    var onRename: ((Journal) -> Void)?
    var onFavorite: ((Journal) -> Void)?
    
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        )
                    Menu {
                        if onRename != nil {
                            Button("Rename") {
                                renameText = journal.title
                                showRenameAlert = true
                            }
                        }
                        if let onFavorite {
                            Button {
                                var updated = journal
                                updated.isFavorite.toggle()
                                onFavorite(updated)
                            } label: {
                                Label(journal.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: journal.isFavorite ? "star.slash" : "star")
                            }
                        }
                        if let onDelete {
                            Button(role: .destructive) { onDelete() } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(journal.title)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(journal.lastEdited, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opennoteCard()
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onRename != nil {
                Button("Rename") {
                    renameText = journal.title
                    showRenameAlert = true
                }
            }
            if let onFavorite {
                Button {
                    var updated = journal
                    updated.isFavorite.toggle()
                    onFavorite(updated)
                } label: {
                    Label(journal.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: journal.isFavorite ? "star.slash" : "star")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Rename Journal", isPresented: $showRenameAlert) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                var updated = journal
                updated.title = renameText.isEmpty ? "Untitled Journal" : renameText
                onRename?(updated)
            }
        } message: {
            Text("Enter a new title for this journal.")
        }
    }
}

struct JournalListRow: View {
    let journal: Journal
    let onTap: () -> Void
    var onDelete: (() -> Void)?
    var onRename: ((Journal) -> Void)?
    var onFavorite: ((Journal) -> Void)?
    
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "book.closed")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.secondary)
                Text(journal.title)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    if onRename != nil {
                        Button("Rename") {
                            renameText = journal.title
                            showRenameAlert = true
                        }
                    }
                    if let onFavorite {
                        Button {
                            var updated = journal
                            updated.isFavorite.toggle()
                            onFavorite(updated)
                        } label: {
                            Label(journal.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: journal.isFavorite ? "star.slash" : "star")
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive) { onDelete() } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .opennoteCard()
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onRename != nil {
                Button("Rename") {
                    renameText = journal.title
                    showRenameAlert = true
                }
            }
            if let onFavorite {
                Button {
                    var updated = journal
                    updated.isFavorite.toggle()
                    onFavorite(updated)
                } label: {
                    Label(journal.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: journal.isFavorite ? "star.slash" : "star")
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Rename Journal", isPresented: $showRenameAlert) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                var updated = journal
                updated.title = renameText.isEmpty ? "Untitled Journal" : renameText
                onRename?(updated)
            }
        } message: {
            Text("Enter a new title.")
        }
    }
}

// MARK: - Paper compact card (horizontal row)

struct PaperCompactCard: View {
    let paper: Paper
    let onTap: () -> Void
    var onDelete: (() -> Void)?
    var onRename: ((Paper) -> Void)?

    @State private var showRenameAlert = false
    @State private var renameText = ""

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Color(.systemGray3))
                    Spacer()
                    if let onDelete {
                        Button {
                            Haptics.impact(.light)
                            onDelete()
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.red.opacity(0.82))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 8)

                Text(paper.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(paper.lastEdited, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(12)
            .frame(width: 132, height: 108)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onRename != nil {
                Button("Rename") { renameText = paper.title; showRenameAlert = true }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Rename Paper", isPresented: $showRenameAlert) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                var updated = paper
                updated.title = renameText.isEmpty ? "Untitled Paper" : renameText
                onRename?(updated)
            }
        }
    }
}

// MARK: - Journal large card (full-width, primary emphasis)

struct JournalLargeCard: View {
    let journal: Journal
    let onTap: () -> Void
    var onDelete: (() -> Void)?
    var onRename: ((Journal) -> Void)?
    var onFavorite: ((Journal) -> Void)?

    @State private var showRenameAlert = false
    @State private var renameText = ""

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(journal.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(journal.lastEdited, style: .date)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        if onRename != nil {
                            Button("Rename") {
                                renameText = journal.title
                                showRenameAlert = true
                            }
                        }
                        if let onFavorite {
                            Button {
                                var updated = journal
                                updated.isFavorite.toggle()
                                onFavorite(updated)
                            } label: {
                                Label(
                                    journal.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: journal.isFavorite ? "star.slash" : "star"
                                )
                            }
                        }
                        if let onDelete {
                            Button(role: .destructive) { onDelete() } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }

                // Spacer gives the card vertical weight — like a real notebook page
                Spacer(minLength: 48)

                HStack {
                    if journal.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.opennoteGreen)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(.systemGray3))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onRename != nil {
                Button("Rename") { renameText = journal.title; showRenameAlert = true }
            }
            if let onFavorite {
                Button {
                    var updated = journal
                    updated.isFavorite.toggle()
                    onFavorite(updated)
                } label: {
                    Label(
                        journal.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: journal.isFavorite ? "star.slash" : "star"
                    )
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Rename Journal", isPresented: $showRenameAlert) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                var updated = journal
                updated.title = renameText.isEmpty ? "Untitled Journal" : renameText
                onRename?(updated)
            }
        }
    }
}

#Preview {
    HomeView(
        journals: [
            Journal(title: "Biology 101"),
            Journal(title: "Physics Notes")
        ],
        papers: [Paper(title: "Untitled Paper")],
        onCreateJournal: {},
        onCreatePaper: {},
        onSelectJournal: { _ in },
        onSelectPaper: { _ in },
        onDeleteJournal: nil,
        onDeletePaper: nil,
        onRenameJournal: nil,
        onRenamePaper: nil,
        onFavoriteJournal: nil,
        onFavoritePaper: nil
    )
}

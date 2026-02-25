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
    
    @State private var journalsExpanded = true
    @State private var papersExpanded = true
    
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
                    SidebarRow(icon: "magnifyingglass", title: "Search") { }
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
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onCreateJournal()
                        isPresented = false
                    }
                    ForEach(journals) { journal in
                        HStack {
                            Text(journal.title)
                                .font(.system(.body, design: .default))
                                .lineLimit(1)
                            Spacer()
                            Button { } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Button { } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectJournal(journal)
                            isPresented = false
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
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onCreatePaper()
                        isPresented = false
                    }
                    
                    ForEach(papers) { paper in
                        HStack {
                            Text(paper.title)
                                .font(.system(.body, design: .default))
                                .lineLimit(1)
                            Spacer()
                            Button { } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectPaper(paper)
                            isPresented = false
                        }
                    }
                } label: {
                    Text("Your Papers")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                
                Spacer()
            }
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
        onSelectInbox: {}
    )
    .environment(AppViewModel())
}

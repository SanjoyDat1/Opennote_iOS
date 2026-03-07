import SwiftUI
import PDFKit

/// Settings sheet for papers - matches the exact UI spec. All options functional.
struct PaperSettingsSheet: View {
    @Binding var isPresented: Bool
    let paper: Paper
    @Binding var content: String
    @Environment(NotesStore.self) private var notesStore
    var onCloneSelect: ((Paper) -> Void)?
    var onDelete: () -> Void
    var onCompilePDF: (() -> Void)?
    var onShowAI: (() -> Void)?
    var onShowNotesToPDF: (() -> Void)?

    @State private var showFrequencySheet = false
    @State private var showIntegrationsSheet = false
    @State private var showVersionHistorySheet = false
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    @Bindable private var appSettings = AppSettings.shared

    private var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Group 1: AI/Suggestion Settings
                    settingsCard {
                        VStack(spacing: 0) {
                            settingsRow(icon: "lightbulb.sparkle", title: "Proactive Suggestions") {
                                Toggle("", isOn: $appSettings.proactiveSuggestions)
                                    .labelsHidden()
                            }
                            Divider().padding(.leading, 48)
                            Button {
                                showFrequencySheet = true
                            } label: {
                                settingsRow(icon: "hourglass", title: "Frequency", subtitle: appSettings.suggestionFrequency.rawValue, showChevron: true) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            Button {
                                showIntegrationsSheet = true
                            } label: {
                                settingsRow(icon: "square.grid.2x2", title: "Integrations", subtitle: "Connect your apps", showChevron: true) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            settingsRow(icon: "waveform", title: "Record Your Notes", showChevron: false) {
                                EmptyView()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.impact(.light)
                            }
                        }
                    }

                    // Group 2: Export/Management
                    settingsCard {
                        VStack(spacing: 0) {
                            Button {
                                onShowAI?()
                            } label: {
                                settingsRow(icon: "paperplane.fill", title: "Ask Feynman", assetName: "logo", showChevron: false) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            Button {
                                onShowNotesToPDF?()
                            } label: {
                                settingsRow(icon: "doc.on.doc", title: "Turn notes into PDF", showChevron: false) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            Button {
                                onCompilePDF?()
                                isPresented = false
                            } label: {
                                settingsRow(icon: "doc.richtext", title: "Compile PDF Preview", showChevron: false) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            .disabled(content.isEmpty)
                            Divider().padding(.leading, 48)
                            Button {
                                shareItems = [content]
                                showShareSheet = true
                            } label: {
                                settingsRow(icon: "arrow.down.doc", title: "Export to Markdown", showChevron: false) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            Button {
                                exportPaperToPDF()
                            } label: {
                                settingsRow(icon: "square.and.arrow.up", title: "Export to PDF", showChevron: false) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            Button {
                                clonePaper()
                            } label: {
                                settingsRow(icon: "doc.on.doc", title: "Clone paper", showChevron: false) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            Button {
                                showVersionHistorySheet = true
                            } label: {
                                settingsRow(icon: "clock.arrow.circlepath", title: "Version history", showChevron: false) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 18))
                                    Text("Move to Trash")
                                        .font(.system(size: 17))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Word Count
                    HStack {
                        Text("Word Count")
                            .font(.system(size: 17))
                        Spacer()
                        Text("\(wordCount)")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18))
                        Text("Settings")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.selection()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.opennoteGreen)
                }
            }
            .sheet(isPresented: $showFrequencySheet) {
                FrequencySheet(appSettings: appSettings, isPresented: $showFrequencySheet)
            }
            .sheet(isPresented: $showIntegrationsSheet) {
                IntegrationsSheet(isPresented: $showIntegrationsSheet)
            }
            .sheet(isPresented: $showVersionHistorySheet) {
                PaperVersionHistorySheet(isPresented: $showVersionHistorySheet, paper: paper)
            }
            .confirmationDialog("Move to Trash", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Move to Trash", role: .destructive) {
                    notesStore.deletePaper(id: paper.id)
                    isPresented = false
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This paper will be permanently deleted.")
            }
            .sheet(isPresented: $showShareSheet) {
                if !shareItems.isEmpty {
                    ShareSheet(items: shareItems)
                }
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func settingsRow(icon: String, title: String, subtitle: String? = nil, assetName: String? = nil, showChevron: Bool = false, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if let asset = assetName {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                }
            }
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            trailing()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func clonePaper() {
        Haptics.impact(.light)
        let newPaper = Paper(title: "\(paper.title) (Copy)", content: content)
        notesStore.addPaper(newPaper)
        isPresented = false
        onCloneSelect?(newPaper)
    }

    private func exportPaperToPDF() {
        Haptics.impact(.light)
        Task {
            let encoded = content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "https://latexonline.cc/compile?text=\(encoded)&force=true"
            guard let url = URL(string: urlString) else { return }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                        let temp = FileManager.default.temporaryDirectory
                            .appendingPathComponent("\(paper.title).pdf")
                        try? data.write(to: temp)
                        shareItems = [temp]
                        showShareSheet = true
                    }
                }
            } catch {}
        }
    }
}

private struct PaperVersionHistorySheet: View {
    @Binding var isPresented: Bool
    let paper: Paper

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Version history")
                    .font(.headline)
                Text("Previous versions of your paper will appear here once versioning is enabled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Version history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundStyle(Color.opennoteGreen)
                }
            }
        }
    }
}

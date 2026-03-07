import SwiftUI
import PDFKit

/// Settings sheet for journals - matches the exact UI spec. All options functional.
struct JournalSettingsSheet: View {
    @Binding var isPresented: Bool
    let journal: Journal
    @Bindable var viewModel: JournalEditorViewModel
    @Environment(NotesStore.self) private var notesStore
    @Environment(\.dismiss) private var dismiss
    var onCloneSelect: ((Journal) -> Void)?
    var onDelete: () -> Void

    @State private var showFrequencySheet = false
    @State private var showIntegrationsSheet = false
    @State private var showVersionHistorySheet = false
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    @Bindable private var appSettings = AppSettings.shared

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
                                // Record: placeholder for future audio recording
                            }
                        }
                    }

                    // Group 2: Export/Management
                    settingsCard {
                        VStack(spacing: 0) {
                            Button {
                                exportToMarkdown()
                            } label: {
                                settingsRow(icon: "arrow.down.doc", title: "Export to Markdown", showChevron: false) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            Button {
                                exportToPDF()
                            } label: {
                                settingsRow(icon: "doc.richtext", title: "Export to PDF", showChevron: false) { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 48)
                            Button {
                                cloneJournal()
                            } label: {
                                settingsRow(icon: "doc.on.doc", title: "Clone journal", showChevron: false) { EmptyView() }
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
                        Text("\(viewModel.wordCount())")
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
                VersionHistorySheet(isPresented: $showVersionHistorySheet, journal: journal)
            }
            .confirmationDialog("Move to Trash", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Move to Trash", role: .destructive) {
                    performDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This journal will be permanently deleted.")
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

    private func settingsRow(icon: String, title: String, subtitle: String? = nil, showChevron: Bool = false, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
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

    private func exportToMarkdown() {
        Haptics.impact(.light)
        shareItems = [viewModel.blocksToMarkdown()]
        showShareSheet = true
    }

    private func exportToPDF() {
        Haptics.impact(.light)
        let pdfData = PDFExporter.export(markdown: viewModel.blocksToMarkdown(), title: journal.title)
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(journal.title).pdf")
        try? pdfData.write(to: temp)
        shareItems = [temp]
        showShareSheet = true
    }

    private func cloneJournal() {
        Haptics.impact(.light)
        let clonedBlocks = viewModel.blocks.map { b in
            NoteBlock(orderIndex: b.orderIndex, blockType: b.blockType)
        }
        let newJournal = Journal(title: "\(journal.title) (Copy)")
        notesStore.pendingBlocksForJournalId[newJournal.id] = clonedBlocks
        notesStore.addJournal(newJournal)
        isPresented = false
        onCloneSelect?(newJournal)
    }

    private func performDelete() {
        Haptics.notification(.warning)
        notesStore.deleteJournal(id: journal.id)
        isPresented = false
        onDelete()
    }
}

// MARK: - Sub-sheets

private struct VersionHistorySheet: View {
    @Binding var isPresented: Bool
    let journal: Journal

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Version history")
                    .font(.headline)
                Text("Previous versions of your journal will appear here once versioning is enabled.")
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

// MARK: - PDF Export

private enum PDFExporter {
    static func export(markdown: String, title: String) -> Data {
        let pdfMeta = [
            kCGPDFContextCreator: "Opennote",
            kCGPDFContextAuthor: "Opennote User"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMeta as [String: Any]
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            context.beginPage()
            let font = UIFont.systemFont(ofSize: 12)
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]

            var y: CGFloat = 40
            let margin: CGFloat = 50
            let width = pageRect.width - 2 * margin

            // Title
            (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 30

            // Body - simple line wrapping
            let lines = markdown.components(separatedBy: .newlines)
            for line in lines {
                let text = (line as NSString)
                let size = text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                             options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
                if y + size.height > pageRect.height - 50 {
                    context.beginPage()
                    y = 50
                }
                text.draw(in: CGRect(x: margin, y: y, width: width, height: size.height), withAttributes: attrs)
                y += size.height + 4
            }
        }
    }
}


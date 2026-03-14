import SwiftUI
import PDFKit

// MARK: - Journal Settings Sheet
//
// Matches the screenshot exactly:
//  ⊞ Settings header | Done button
//  Font picker (Default / Serif with selection border)
//  Record Your Notes row → pushes NotesRecorderSheet
//  Export to Markdown, Export to PDF, Clone journal, Version history
//  Move to Trash (red)
//  Footer: Word Count + Last saved

struct JournalSettingsSheet: View {
    @Binding var isPresented: Bool
    let journal: Journal
    @Bindable var viewModel: JournalEditorViewModel
    @Environment(NotesStore.self) private var notesStore
    var onCloneSelect: ((Journal) -> Void)?
    var onDelete: () -> Void
    var onInsertText: ((String) -> Void)?

    @State private var showVersionHistorySheet = false
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var navigateToRecorder = false

    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Font picker
                    fontSection

                    // MARK: Record Your Notes
                    settingsCard {
                        NavigationLink(destination: recorderDestination) {
                            settingsRow(icon: "waveform", title: "Record Your Notes")
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: Export / Management
                    settingsCard {
                        VStack(spacing: 0) {
                            Button { exportToMarkdown() } label: {
                                settingsRow(icon: "arrow.down.doc", title: "Export to Markdown")
                            }
                            .buttonStyle(.plain)

                            rowDivider

                            Button { exportToPDF() } label: {
                                settingsRow(icon: "doc.richtext", title: "Export to PDF")
                            }
                            .buttonStyle(.plain)

                            rowDivider

                            Button { cloneJournal() } label: {
                                settingsRow(icon: "doc.on.doc", title: "Clone journal")
                            }
                            .buttonStyle(.plain)

                            rowDivider

                            Button { showVersionHistorySheet = true } label: {
                                settingsRow(icon: "clock.arrow.circlepath", title: "Version history")
                            }
                            .buttonStyle(.plain)

                            rowDivider

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.red)
                                        .frame(width: 28, alignment: .center)
                                    Text("Move to Trash")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color.red)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // MARK: Footer: word count + last saved
                    footerSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                        Text("Settings")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
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
            .sheet(isPresented: $showVersionHistorySheet) {
                VersionHistorySheet(isPresented: $showVersionHistorySheet, journal: journal)
            }
            .confirmationDialog("Move to Trash", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Move to Trash", role: .destructive) { performDelete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This journal will be permanently deleted.")
            }
            .sheet(isPresented: $showShareSheet) {
                if !shareItems.isEmpty { ShareSheet(items: shareItems) }
            }
        }
    }

    // MARK: Font section

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Font")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(AppSettings.EditorFont.allCases, id: \.rawValue) { font in
                    Button {
                        Haptics.selection()
                        appSettings.editorFont = font
                    } label: {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(font.rawValue)
                                    .font(font == .serif
                                          ? .system(size: 17, design: .serif)
                                          : .system(size: 17))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(font.description)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            appSettings.editorFont == font
                                                ? Color.opennoteGreen
                                                : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeOut(duration: 0.15), value: appSettings.editorFont)
                }
            }
        }
    }

    // MARK: Footer

    private var footerSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Word Count")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.wordCount())")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Last saved \(journal.lastEdited.relativeFormatted())")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Notes Recorder destination

    private var recorderDestination: some View {
        NotesRecorderSheet { text in
            onInsertText?(text)
            isPresented = false
        }
        .navigationTitle("Notes Recorder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 15, weight: .medium))
                    Text("Notes Recorder")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
    }

    // MARK: Helpers

    private var rowDivider: some View {
        Divider().padding(.leading, 56)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func settingsRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Actions

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
        let clonedBlocks = viewModel.blocks.map { NoteBlock(orderIndex: $0.orderIndex, blockType: $0.blockType) }
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

// MARK: - Date helper

private extension Date {
    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Version history sub-sheet

private struct VersionHistorySheet: View {
    @Binding var isPresented: Bool
    let journal: Journal

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Version History")
                    .font(.system(size: 20, weight: .semibold))
                Text("Previous versions will appear here.\nVersion snapshots are saved automatically as you write.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Version history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(Color.opennoteGreen)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - PDF Exporter

private enum PDFExporter {
    static func export(markdown: String, title: String) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont]
            let margin: CGFloat = 50
            let width = pageRect.width - 2 * margin
            var y: CGFloat = 40

            (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 34

            for line in markdown.components(separatedBy: .newlines) {
                let text = line as NSString
                let size = text.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: bodyAttrs,
                    context: nil
                )
                if y + size.height > pageRect.height - 50 {
                    context.beginPage()
                    y = 50
                }
                text.draw(in: CGRect(x: margin, y: y, width: width, height: size.height), withAttributes: bodyAttrs)
                y += size.height + 4
            }
        }
    }
}

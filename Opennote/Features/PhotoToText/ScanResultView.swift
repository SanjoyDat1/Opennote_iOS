import SwiftUI

// MARK: - Scan Result View

struct ScanResultView: View {
    @Bindable var session: ScanSessionModel
    var onInsert: (String, InsertionMode) -> Void
    var onDismiss: () -> Void

    @State private var showOriginalImage = false
    @State private var showDeleteImageAlert = false

    // MARK: Derived state

    private var isProcessing: Bool {
        switch session.phase {
        case .enhancing, .recognizing, .formatting: return true
        default: return false
        }
    }

    private var progressValue: Double {
        switch session.phase {
        case .enhancing:             return 0.08
        case .recognizing:           return 0.22
        case .formatting(let p):     return 0.25 + p * 0.75
        default:                     return 1.0
        }
    }

    private var statusText: String {
        switch session.phase {
        case .enhancing:         return "Enhancing image…"
        case .recognizing:       return "Reading handwriting…"
        case .formatting:        return "Structuring your notes with AI…"
        case .reviewing:         return "Ready — review and insert below"
        case .failed(let msg):   return msg
        default:                 return ""
        }
    }

    private var isFailed: Bool {
        if case .failed = session.phase { return true }
        return false
    }

    private var canInsert: Bool {
        if case .reviewing = session.phase { return !session.formattedText.isEmpty }
        return false
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // ── Main scroll area ──────────────────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Progress / status banner
                        if isProcessing || statusText != "" {
                            statusBanner
                                .padding(.horizontal, 20)
                                .padding(.top, 14)
                                .padding(.bottom, 4)
                        }

                        // Rendered note preview (streams in live)
                        if !session.formattedText.isEmpty {
                            MarkdownNotePreview(markdown: session.formattedText)
                                .padding(.horizontal, 24)
                                .padding(.top, 20)
                                .padding(.bottom, 120)
                        } else if !isProcessing {
                            emptyState
                        }
                    }
                }
                .background(Color(.systemBackground))

                // ── Floating insert button ────────────────────────────
                if canInsert {
                    insertButton
                }

                // ── Retry button on failure ───────────────────────────
                if case .failed = session.phase, session.capturedImage != nil {
                    retryButton
                }
            }
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                // Original image menu
                if session.capturedImage != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showOriginalImage = true
                            } label: {
                                Label("View Original", systemImage: "photo")
                            }
                            Button(role: .destructive) {
                                showDeleteImageAlert = true
                            } label: {
                                Label("Delete Original", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "photo.circle")
                                .foregroundStyle(Color.opennoteGreen)
                                .font(.system(size: 20))
                        }
                    }
                }
            }
        }
        // Original image sheet
        .sheet(isPresented: $showOriginalImage) {
            NavigationStack {
                Group {
                    if let img = session.capturedImage {
                        GeometryReader { geo in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                        .ignoresSafeArea(edges: .bottom)
                    } else {
                        ContentUnavailableView("Image Removed", systemImage: "photo.slash")
                    }
                }
                .navigationTitle("Original Scan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showOriginalImage = false }
                    }
                }
            }
        }
        .alert("Delete original image?", isPresented: $showDeleteImageAlert) {
            Button("Delete", role: .destructive) { session.capturedImage = nil }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The extracted text will be kept; only the source photo is removed.")
        }
    }

    // MARK: Sub-views

    private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isProcessing {
                ProgressView(value: progressValue)
                    .tint(Color.opennoteGreen)
                    .animation(.easeInOut(duration: 0.4), value: progressValue)
            }
            HStack(spacing: 6) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.75)
                        .tint(Color.opennoteGreen)
                }
                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isFailed ? Color.red : Color.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var insertButton: some View {
        VStack(spacing: 0) {
            // Fade gradient so content doesn't hard-clip behind the button
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)

            Button {
                Haptics.impact(.medium)
                onInsert(session.formattedText, .appendToEnd)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Insert into Notes")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Color.opennoteGreen)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(Color(.systemBackground))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var retryButton: some View {
        Button {
            guard let img = session.capturedImage else { return }
            Haptics.impact(.medium)
            session.startScan([img])
        } label: {
            Label("Try Again", systemImage: "arrow.clockwise")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Color.red.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.opennoteGreen.opacity(0.6))
            Text("No text extracted")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Try re-scanning with better lighting or a steadier angle.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Markdown Note Preview

/// Renders the AI-formatted markdown as a polished note preview,
/// matching how it will look once inserted into the journal.
private struct MarkdownNotePreview: View {
    let markdown: String

    private var segments: [NoteSegment] { parseSegments(markdown) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                segmentView(seg)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.15), value: markdown)
    }

    @ViewBuilder
    private func segmentView(_ seg: NoteSegment) -> some View {
        switch seg.kind {
        case .h1:
            inlineText(seg.content)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 10)
                .padding(.top, 4)

        case .h2:
            inlineText(seg.content)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 6)
                .padding(.top, 18)

        case .h3:
            inlineText(seg.content)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 4)
                .padding(.top, 14)

        case .body:
            inlineText(seg.content)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primary)
                .lineSpacing(5)
                .padding(.bottom, 10)

        case .divider:
            Divider()
                .padding(.vertical, 14)

        case .blank:
            Color.clear.frame(height: 6)
        }
    }

    @ViewBuilder
    private func inlineText(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
        } else {
            Text(text)
        }
    }

    // MARK: Parser

    private enum SegmentKind { case h1, h2, h3, body, divider, blank }
    private struct NoteSegment { let kind: SegmentKind; let content: String }

    private func parseSegments(_ raw: String) -> [NoteSegment] {
        var result: [NoteSegment] = []
        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty {
                result.append(NoteSegment(kind: .blank, content: ""))
            } else if t == "---" || t == "***" || t == "___" {
                result.append(NoteSegment(kind: .divider, content: ""))
            } else if t.hasPrefix("### ") {
                result.append(NoteSegment(kind: .h3, content: String(t.dropFirst(4))))
            } else if t.hasPrefix("## ") {
                result.append(NoteSegment(kind: .h2, content: String(t.dropFirst(3))))
            } else if t.hasPrefix("# ") {
                result.append(NoteSegment(kind: .h1, content: String(t.dropFirst(2))))
            } else {
                // Strip any stray list markers the LLM may still output
                var body = t
                if body.hasPrefix("- ") || body.hasPrefix("* ") || body.hasPrefix("• ") {
                    body = String(body.dropFirst(2))
                } else {
                    let numPattern = #"^(\d+)\.\s+"#
                    body = body.replacingOccurrences(of: numPattern, with: "", options: .regularExpression)
                }
                if !body.isEmpty {
                    result.append(NoteSegment(kind: .body, content: body))
                }
            }
        }
        // Collapse consecutive blanks to a single one
        return result.reduce(into: [NoteSegment]()) { acc, seg in
            if seg.kind == .blank, acc.last?.kind == .blank { return }
            acc.append(seg)
        }
    }
}

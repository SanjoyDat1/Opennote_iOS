import SwiftUI
import UIKit

// MARK: - LaTeXScanSession

/// Orchestrates scan → OCR → GPT-4o LaTeX generation for the Papers editor.
@Observable
@MainActor
final class LaTeXScanSession {
    enum Phase: Equatable {
        case idle
        case enhancing
        case recognizing
        case generating(progress: Double)
        case reviewing
        case failed(message: String)
    }

    var phase: Phase = .idle
    var capturedImage: UIImage?
    var generatedLaTeX: String = ""

    private var scanTask: Task<Void, Never>?

    func startScan(_ images: [UIImage], existingLaTeX: String) {
        scanTask?.cancel()
        scanTask = nil
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runScan(images, existingLaTeX: existingLaTeX)
        }
        scanTask = task
    }

    private func runScan(_ images: [UIImage], existingLaTeX: String) async {
        guard let image = images.first else { return }
        guard !Task.isCancelled else { return }

        capturedImage = image
        generatedLaTeX = ""

        phase = .enhancing
        let enhanced = await ImagePreprocessor.enhance(image)
        guard !Task.isCancelled else { return }

        phase = .recognizing
        let ocrResult = try? await VisionOCRService.recognize(enhanced)
        guard !Task.isCancelled else { return }
        let rawOCR = ocrResult?.rawText ?? ""

        phase = .generating(progress: 0.0)
        let service = OpenAIVisionService()
        var chunkCount = 0

        do {
            for try await chunk in service.formatNoteAsLaTeX(
                image: enhanced,
                rawOCRText: rawOCR,
                existingLaTeX: existingLaTeX
            ) {
                guard !Task.isCancelled else { return }
                generatedLaTeX += chunk
                chunkCount += 1
                phase = .generating(progress: min(Double(chunkCount) / 280.0, 0.95))
            }
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(message: error.localizedDescription)
            return
        }

        guard !Task.isCancelled else { return }
        phase = .reviewing
        scanTask = nil
    }

    func reset() {
        scanTask?.cancel()
        scanTask = nil
        capturedImage = nil
        phase = .idle
        generatedLaTeX = ""
    }

    var isProcessing: Bool {
        switch phase {
        case .enhancing, .recognizing, .generating: return true
        default: return false
        }
    }
}

// MARK: - PaperScanButton

/// Drop-in replacement for PhotoToTextButton in the Papers editor.
/// Runs the full scan → LaTeX generation → preview → insert-before-\end{document} flow.
struct PaperScanButton: View {
    @Binding var content: String

    @State private var session = LaTeXScanSession()
    @State private var showScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var showResult = false
    @State private var showImagePicker = false
    @State private var showSourcePicker = false

    var body: some View {
        Button {
            Haptics.impact(.light)
            showSourcePicker = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Color(.systemGray5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan notes to LaTeX")
        .sheet(isPresented: $showSourcePicker) {
            PhotoToTextSourceSheet(
                onScanDocument: { showSourcePicker = false; showScanner = true },
                onChooseFromLibrary: { showSourcePicker = false; showImagePicker = true },
                onDismiss: { showSourcePicker = false }
            )
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView(scannedImages: $scannedImages, isPresented: $showScanner)
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPickerView(selectedImage: Binding(
                get: { nil },
                set: { img in
                    if let img { scannedImages = [img]; showImagePicker = false }
                }
            ))
        }
        .onChange(of: scannedImages) { _, newImages in
            guard !newImages.isEmpty else { return }
            showResult = true
            session.startScan(newImages, existingLaTeX: content)
            scannedImages = []
        }
        .sheet(isPresented: $showResult) {
            LaTeXScanResultView(
                session: session,
                onInsert: { latex in
                    // GPT-4o returns the complete compilable document — replace entirely.
                    content = latex
                    Haptics.impact(.medium)
                    showResult = false
                },
                onDismiss: {
                    session.reset()
                    showResult = false
                }
            )
        }
    }
}

// MARK: - LaTeXScanResultView

struct LaTeXScanResultView: View {
    @Bindable var session: LaTeXScanSession
    var onInsert: (String) -> Void
    var onDismiss: () -> Void

    @State private var showOriginalImage = false

    private var isFailed: Bool {
        if case .failed = session.phase { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if session.isProcessing {
                    LaTeXAnalyzingView(phase: session.phase)
                        .transition(.opacity)
                } else {
                    // Result area
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if isFailed {
                                failureBanner
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                            }

                            if !session.generatedLaTeX.isEmpty {
                                laTeXPreview
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 120)
                            } else if !session.isProcessing {
                                emptyState
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .transition(.opacity)
                }

                // Insert button
                if case .reviewing = session.phase, !session.generatedLaTeX.isEmpty {
                    insertButton
                }

                // Retry button
                if case .failed = session.phase, session.capturedImage != nil {
                    retryButton
                }
            }
            .animation(.easeInOut(duration: 0.4), value: session.isProcessing)
            .navigationTitle(session.isProcessing ? "" : "LaTeX Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                if !session.isProcessing, session.capturedImage != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showOriginalImage = true
                        } label: {
                            Image(systemName: "photo.circle")
                                .foregroundStyle(Color.opennoteGreen)
                                .font(.system(size: 20))
                        }
                    }
                }
            }
        }
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
    }

    // MARK: Sub-views

    private var laTeXPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header badge
            HStack(spacing: 7) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.opennoteGreen)
                Text("Complete, compilable document — tap Apply to replace your paper")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.opennoteGreen)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.opennoteGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // LaTeX code block
            LaTeXCodeView(code: session.generatedLaTeX)
        }
    }

    private var insertButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            Button {
                Haptics.impact(.medium)
                onInsert(session.generatedLaTeX)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath.doc.on.clipboard")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Apply to Paper")
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
            session.startScan([img], existingLaTeX: "")
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

    private var failureBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            if case .failed(let msg) = session.phase {
                Text(msg)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.opennoteGreen.opacity(0.6))
            Text("No content extracted")
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

// MARK: - LaTeXCodeView

/// Renders LaTeX source code with lightweight syntax colouring.
private struct LaTeXCodeView: View {
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar strip
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("LaTeX Source")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    Haptics.impact(.light)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.opennoteGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))

            Divider()

            // Code
            Text(attributedCode(code))
                .font(.system(size: 13, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .textSelection(.enabled)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: code)
    }

    /// Basic syntax colouring: commands in green, comments in grey.
    private func attributedCode(_ source: String) -> AttributedString {
        var result = AttributedString()
        let lines = source.components(separatedBy: "\n")

        for (lineIdx, line) in lines.enumerated() {
            var remaining = line[line.startIndex...]

            while !remaining.isEmpty {
                // Comment — everything from % to end of line (handle escaped \%)
                if remaining.first == "%" {
                    var comment = AttributedString(String(remaining))
                    comment.foregroundColor = .secondaryLabel
                    result.append(comment)
                    remaining = remaining[remaining.endIndex...]
                    break
                }

                // LaTeX command: \word
                if remaining.first == "\\" {
                    let afterSlash = remaining.dropFirst()
                    let cmdEnd = afterSlash.firstIndex(where: { !$0.isLetter }) ?? afterSlash.endIndex
                    let cmdRange = remaining.startIndex..<cmdEnd
                    var cmd = AttributedString(String(remaining[cmdRange]))
                    cmd.foregroundColor = UIColor(Color.opennoteGreen)
                    result.append(cmd)
                    remaining = remaining[cmdEnd...]
                    continue
                }

                // Regular character — collect until next \ or %
                let end = remaining.firstIndex(where: { $0 == "\\" || $0 == "%" }) ?? remaining.endIndex
                var plain = AttributedString(String(remaining[remaining.startIndex..<end]))
                plain.foregroundColor = .label
                result.append(plain)
                remaining = remaining[end...]
            }

            if lineIdx < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }
}

// MARK: - LaTeXAnalyzingView

/// Full-screen animated loading state for the LaTeX generation phase.
private struct LaTeXAnalyzingView: View {
    let phase: LaTeXScanSession.Phase

    @State private var floatY: CGFloat = 0
    @State private var tilt: Double = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.25
    @State private var dotIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.opennoteGreen.opacity(glowOpacity), .clear],
                        center: .center, startRadius: 0, endRadius: 80
                    ))
                    .frame(width: 180, height: 180)
                    .scaleEffect(glowScale)
                    .blur(radius: 8)

                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .offset(y: floatY)
                    .rotationEffect(.degrees(tilt))
            }
            .frame(height: 180)

            Spacer().frame(height: 32)

            VStack(spacing: 10) {
                Text("Integrating into your paper")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(phaseLabel)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.opennoteGreen)
                    .animation(.easeInOut(duration: 0.3), value: phaseLabel)
                    .id(phaseLabel)

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { idx in
                        Circle()
                            .fill(Color.opennoteGreen)
                            .frame(width: 7, height: 7)
                            .scaleEffect(dotIndex == idx ? 1.35 : 0.85)
                            .opacity(dotIndex == idx ? 1.0 : 0.35)
                            .animation(.easeInOut(duration: 0.3), value: dotIndex)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { floatY = -14 }
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) { tilt = 7 }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowScale = 1.18; glowOpacity = 0.5
            }
        }
        .onReceive(Timer.publish(every: 0.42, on: .main, in: .common).autoconnect()) { _ in
            dotIndex = (dotIndex + 1) % 3
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .enhancing:               return "Enhancing your scan..."
        case .recognizing:             return "Reading your handwriting..."
        case .generating(let p):
            let pct = Int((0.25 + p * 0.75) * 100)
            return "Building your document… \(pct)%"
        default:                       return "Processing..."
        }
    }
}

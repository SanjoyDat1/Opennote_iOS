import SwiftUI
import UIKit

// MARK: - Notes Recorder Sheet
//
// Three-tab sheet: Record (mic), YouTube (captions), History.
// Presented as a NavigationLink destination within JournalSettingsSheet.
// All three tabs share a persistent Transcript section at the bottom.

struct NotesRecorderSheet: View {
    let onInsert: (String) -> Void

    enum RecorderTab: CaseIterable {
        case record, youtube, history

        var title: String {
            switch self {
            case .record: return "Record"
            case .youtube: return "YouTube"
            case .history: return "History"
            }
        }

        var icon: String {
            switch self {
            case .record: return "mic"
            case .youtube: return "play.rectangle"
            case .history: return "clock"
            }
        }
    }

    @StateObject private var speechService = SpeechToTextService()
    @State private var selectedTab: RecorderTab = .record
    @State private var transcript: String = ""
    @State private var youtubeURL: String = ""
    @State private var isTranscribing = false
    @State private var transcribeError: String?
    @State private var audioSource: AudioSource = .mic
    @State private var showMicUnavailableAlert = false

    enum AudioSource { case mic, screen, micAndScreen }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            tabBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider().opacity(0.5)

            // Tab content
            Group {
                switch selectedTab {
                case .record:   recordContent
                case .youtube:  youtubeContent
                case .history:  historyContent
                }
            }

            Divider().opacity(0.5)

            // Transcript — always pinned at the bottom
            transcriptSection
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: speechService.transcribedText) { _, text in
            if !text.isEmpty { transcript = text }
        }
        .alert("Not Available", isPresented: $showMicUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Screen audio capture is not available on this device. Use the Mic source to record your voice.")
        }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(RecorderTab.allCases, id: \.title) { tab in
                Button {
                    Haptics.selection()
                    selectedTab = tab
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                        Text(tabLabel(tab))
                            .font(.system(size: 15, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(selectedTab == tab ? Color.opennoteGreen : Color.clear)
                    .foregroundStyle(selectedTab == tab ? .white : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.18), value: selectedTab)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    private func tabLabel(_ tab: RecorderTab) -> String {
        if tab == .history {
            let count = TranscriptionHistory.shared.records.count
            return "History (\(count))"
        }
        return tab.title
    }

    // MARK: Record tab

    private var recordContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Audio source
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio Source")
                        .font(.system(size: 17, weight: .semibold))
                    HStack(spacing: 10) {
                        audioSourceButton("Mic", icon: "mic", source: .mic)
                        audioSourceButton("Screen", icon: "display", source: .screen)
                        audioSourceButton("Mic + Screen", icon: "mic.and.signal.meter", source: .micAndScreen)
                    }
                }

                // Microphone dropdown
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Microphone")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Button {
                            Haptics.selection()
                            // Refresh: reset any stale state
                            if !speechService.isListening {
                                speechService.reset()
                                transcript = ""
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Text("Default microphone")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }

                // Record / Stop + Add to Journal
                HStack(spacing: 12) {
                    Button {
                        Haptics.impact(.medium)
                        Task {
                            if speechService.isListening {
                                speechService.stopListening()
                                if !speechService.transcribedText.isEmpty {
                                    TranscriptionHistory.shared.add(
                                        text: speechService.transcribedText,
                                        source: "Mic"
                                    )
                                }
                            } else {
                                transcript = ""
                                speechService.reset()
                                await speechService.startListening()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: speechService.isListening ? "stop.circle.fill" : "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(speechService.isListening ? "Stop Recording" : "Start Recording")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(speechService.isListening ? Color.red.opacity(0.88) : Color.opennoteGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: speechService.isListening)

                    addToJournalButton
                }

                // Live recording indicator
                if speechService.isListening {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.opennoteGreen)
                            .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                        Text("Recording…")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.opennoteGreen)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let err = speechService.errorMessage {
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
            }
            .padding(16)
        }
        .animation(.easeOut(duration: 0.2), value: speechService.isListening)
    }

    @ViewBuilder
    private func audioSourceButton(_ label: String, icon: String, source: AudioSource) -> some View {
        let isSelected = audioSource == source
        let isAvailable = source == .mic

        Button {
            if isAvailable {
                Haptics.selection()
                audioSource = source
            } else {
                showMicUnavailableAlert = true
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isSelected ? .primary : Color(.systemGray2))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(.systemBackground) : Color.clear)
                    .shadow(color: isSelected ? .black.opacity(0.06) : .clear, radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(.systemGray3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(isAvailable ? 1 : 0.4)
    }

    // MARK: YouTube tab

    private var youtubeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // URL + Transcribe
                HStack(spacing: 10) {
                    TextField("Enter YouTube URL…", text: $youtubeURL)
                        .font(.system(size: 16))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )

                    Button {
                        Haptics.impact(.medium)
                        Task { await transcribeYouTube() }
                    } label: {
                        HStack(spacing: 6) {
                            if isTranscribing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text("Transcribe")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            youtubeURL.isEmpty || isTranscribing
                                ? Color.opennoteGreen.opacity(0.45)
                                : Color.opennoteGreen
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(youtubeURL.isEmpty || isTranscribing)
                }

                if let err = transcribeError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 14))
                        Text(err)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }
                }

                addToJournalButton
            }
            .padding(16)
        }
    }

    // MARK: History tab

    private var historyContent: some View {
        ScrollView {
            if TranscriptionHistory.shared.records.isEmpty {
                VStack(spacing: 14) {
                    Spacer(minLength: 40)
                    Image(systemName: "clock")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Color(.systemGray3))
                    Text("No transcription history found")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Start recording to create your first transcription")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(TranscriptionHistory.shared.records) { record in
                        historyCard(record)
                    }
                }
                .padding(16)
            }
        }
    }

    private func historyCard(_ record: TranscriptionRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(record.source, systemImage: record.source == "Mic" ? "mic.fill" : "play.rectangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.opennoteGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.opennoteLightGreen.opacity(0.6))
                    .clipShape(Capsule())
                Spacer()
                Text(record.date, style: .relative)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            Text(record.text)
                .font(.system(size: 15))
                .lineLimit(4)
                .foregroundStyle(.primary)

            Button {
                Haptics.impact(.light)
                transcript = record.text
                onInsert(record.text)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 12))
                    Text("Insert into journal")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.opennoteGreen)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: Add to Journal button (shared)

    private var addToJournalButton: some View {
        Button {
            guard !transcript.isEmpty else { return }
            Haptics.impact(.medium)
            onInsert(transcript)
        } label: {
            Text("Add to Journal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(transcript.isEmpty ? Color.opennoteGreen.opacity(0.45) : Color.opennoteGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    Color.opennoteLightGreen.opacity(transcript.isEmpty ? 0.25 : 0.55)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(transcript.isEmpty)
        .animation(.easeOut(duration: 0.15), value: transcript.isEmpty)
    }

    // MARK: Transcript section

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Transcript")
                    .font(.system(size: 17, weight: .semibold))
                Button {
                    UIPasteboard.general.string = transcript
                    Haptics.selection()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15))
                        .foregroundStyle(transcript.isEmpty ? Color(.systemGray4) : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(transcript.isEmpty)
            }

            ZStack(alignment: .topLeading) {
                if transcript.isEmpty {
                    Text("No transcript available")
                        .font(.system(size: 15).italic())
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: Binding(
                    get: { transcript },
                    set: { transcript = $0 }
                ))
                .font(.system(size: 15))
                .frame(minHeight: 88, maxHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: YouTube transcription

    private func transcribeYouTube() async {
        isTranscribing = true
        transcribeError = nil
        transcript = ""

        do {
            let text = try await YouTubeTranscriptService.fetchTranscript(from: youtubeURL)
            transcript = text
            TranscriptionHistory.shared.add(text: text, source: "YouTube")
        } catch {
            transcribeError = error.localizedDescription
        }

        isTranscribing = false
    }
}

// MARK: - YouTube Transcript Service

enum YouTubeTranscriptService {
    static func fetchTranscript(from urlString: String) async throws -> String {
        guard let videoId = extractVideoId(from: urlString) else {
            throw TranscriptError.invalidURL
        }

        // Try English auto-generated captions via YouTube's timedtext API
        guard let url = URL(string: "https://www.youtube.com/api/timedtext?v=\(videoId)&lang=en&fmt=json3") else {
            throw TranscriptError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              !data.isEmpty else {
            throw TranscriptError.noTranscriptFound
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            throw TranscriptError.noTranscriptFound
        }

        let segments: [String] = events.compactMap { event in
            guard let segs = event["segs"] as? [[String: Any]] else { return nil }
            let text = segs.compactMap { $0["utf8"] as? String }.joined()
            return text.isEmpty ? nil : text
        }

        let full = segments
            .joined(separator: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !full.isEmpty else { throw TranscriptError.noTranscriptFound }
        return full
    }

    static func extractVideoId(from url: String) -> String? {
        let patterns = [
            "youtu\\.be/([a-zA-Z0-9_-]{11})",
            "[?&]v=([a-zA-Z0-9_-]{11})",
            "youtube\\.com/shorts/([a-zA-Z0-9_-]{11})",
            "youtube\\.com/embed/([a-zA-Z0-9_-]{11})"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        return nil
    }

    enum TranscriptError: LocalizedError {
        case invalidURL, noTranscriptFound

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid YouTube URL. Try: youtube.com/watch?v=… or youtu.be/…"
            case .noTranscriptFound:
                return "No English captions found. The video may not have auto-generated captions."
            }
        }
    }
}

// MARK: - Transcription History

struct TranscriptionRecord: Identifiable {
    let id = UUID()
    let text: String
    let source: String
    let date: Date
}

@Observable
final class TranscriptionHistory {
    static let shared = TranscriptionHistory()
    var records: [TranscriptionRecord] = []

    private init() {}

    func add(text: String, source: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        records.insert(TranscriptionRecord(text: text, source: source, date: Date()), at: 0)
    }
}

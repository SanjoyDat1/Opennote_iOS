import SwiftUI
import UIKit

// MARK: - Feynman Chat View
//
// A full-screen sheet chat interface — conversation stays here, not in the journal.
// The journal's markdown is passed as context to every OpenAI request.
// Users can copy or insert any AI response into their journal with one tap.

struct FeynmanChatView: View {
    let journalTitle: String
    let journalContext: String
    var onInsertIntoJournal: (String) -> Void
    var onDismiss: () -> Void

    @Bindable var conversation: FeynmanConversationViewModel
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showModeSheet = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Context banner
                    contextBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    // Message list
                    messageList

                    // Bottom input panel
                    inputPanel
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showModeSheet) {
                FeynmanModeSheet(selectedMode: Binding(
                    get: { conversation.selectedMode },
                    set: { conversation.selectedMode = $0 }
                ))
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog("Clear conversation?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear", role: .destructive) { conversation.clearHistory() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will erase all messages. This cannot be undone.")
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                isInputFocused = true
            }
        }
    }

    // MARK: Context banner
    private var contextBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.opennoteGreen)
            Text("Context: \"\(journalTitle)\"")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.opennoteGreen)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !journalContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("\(wordCount(journalContext)) words")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.opennoteGreen.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.opennoteLightGreen.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.opennoteGreen.opacity(0.18), lineWidth: 1))
    }

    // MARK: Message list
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if conversation.isEmpty {
                        emptyState
                            .id("empty")
                    }

                    ForEach(conversation.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    // Invisible anchor at the very bottom for auto-scroll
                    Color.clear.frame(height: 1).id("__bottom__")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: conversation.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("__bottom__", anchor: .bottom)
                }
            }
            .onChange(of: conversation.messages.last?.content) { _, _ in
                proxy.scrollTo("__bottom__", anchor: .bottom)
            }
        }
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 32)

            VStack(spacing: 10) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .opacity(0.75)

                Text("Ask Feynman")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(.primary)

                Text("Your notes are loaded as context.\nAsk anything — explanations, critiques, connections.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Suggested prompt chips
            VStack(spacing: 10) {
                ForEach(feynmanSuggestedPrompts, id: \.self) { prompt in
                    Button {
                        Haptics.impact(.light)
                        sendMessage(prompt)
                    } label: {
                        HStack {
                            Text(prompt)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.opennoteGreen.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: Message bubble
    @ViewBuilder
    private func messageBubble(_ message: FeynmanChatMessage) -> some View {
        if message.isUser {
            userBubble(message)
        } else {
            assistantBubble(message)
        }
    }

    private func userBubble(_ message: FeynmanChatMessage) -> some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 64)
            Text(message.content)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Color.opennoteGreen)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 20,
                        bottomTrailingRadius: 5,
                        topTrailingRadius: 20
                    )
                )
        }
    }

    private func assistantBubble(_ message: FeynmanChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Feynman avatar
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .padding(6)
                .background(Color.opennoteLightGreen)
                .clipShape(Circle())
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 10) {
                // Bubble body
                Group {
                    if message.isStreaming && message.content.isEmpty {
                        TypingDotsView()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                    } else {
                        markdownText(message.content)
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                            .lineSpacing(4)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 5,
                        bottomLeadingRadius: 20,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 20
                    )
                )
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)

                // Action buttons (only when done streaming)
                if !message.isStreaming && !message.content.isEmpty {
                    HStack(spacing: 6) {
                        actionButton(
                            icon: "doc.on.doc",
                            label: "Copy",
                            color: .secondary
                        ) {
                            UIPasteboard.general.string = message.content
                            Haptics.selection()
                        }

                        actionButton(
                            icon: "arrow.down.doc.fill",
                            label: "Insert into notes",
                            color: Color.opennoteGreen
                        ) {
                            onInsertIntoJournal(message.content)
                            Haptics.impact(.medium)
                        }
                    }
                    .padding(.leading, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer(minLength: 40)
        }
        .animation(.easeOut(duration: 0.2), value: message.isStreaming)
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Input panel
    private var inputPanel: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            HStack(alignment: .bottom, spacing: 10) {
                // Growing text field
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("Message Feynman…")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $inputText, axis: .vertical)
                        .lineLimit(1...8)
                        .font(.system(size: 16))
                        .tint(Color.opennoteGreen)
                        .focused($isInputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    isInputFocused
                                        ? Color.opennoteGreen.opacity(0.45)
                                        : Color(.systemGray4),
                                    lineWidth: 1.3
                                )
                        )
                )
                .animation(.easeOut(duration: 0.2), value: isInputFocused)

                // Send / Stop button
                sendStopButton
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // Toolbar row: mode + extras
            toolbarRow
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, max(14, 0))
        }
        .background(Color(.systemGroupedBackground))
    }

    private var sendStopButton: some View {
        Group {
            if conversation.isStreaming {
                Button {
                    Haptics.impact(.medium)
                    conversation.stopStreaming()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.opennoteGreen)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    sendMessage(trimmed)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(.systemGray4)
                                : Color.opennoteGreen
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(.easeOut(duration: 0.15), value: inputText.isEmpty)
            }
        }
        .frame(width: 36, height: 36)
        .padding(.bottom, 10)
    }

    private var toolbarRow: some View {
        HStack(spacing: 0) {
            // Mode chip — mirrors Gemini "Fast" pill
            Button { showModeSheet = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: conversation.selectedMode.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.opennoteGreen)
                    Text(conversation.selectedMode.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.opennoteGreen)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.opennoteGreen.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.opennoteLightGreen.opacity(0.6))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.2), value: conversation.selectedMode)

            Spacer(minLength: 0)

            // Message count indicator
            if !conversation.isEmpty {
                Text("\(conversation.messages.filter(\.isUser).count) sent")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 7) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Feynman")
                    .font(.system(size: 17, weight: .semibold))
            }
        }

        ToolbarItem(placement: .topBarLeading) {
            Button {
                if conversation.isEmpty {
                    onDismiss()
                } else {
                    showClearConfirm = true
                }
            } label: {
                Image(systemName: conversation.isEmpty ? "" : "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isInputFocused = false
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Helpers

    private func sendMessage(_ text: String) {
        inputText = ""
        Haptics.impact(.light)
        conversation.send(prompt: text, journalContext: journalContext)
    }

    private func wordCount(_ text: String) -> Int {
        text.split(separator: " ").count
    }

    @ViewBuilder
    private func markdownText(_ raw: String) -> some View {
        if let attributed = try? AttributedString(markdown: raw) {
            Text(attributed)
        } else {
            Text(raw)
        }
    }
}

// MARK: - Typing dots animation

struct TypingDotsView: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.38, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 8, height: 8)
                    .scaleEffect(phase == i ? 1.35 : 0.85)
                    .animation(
                        .easeInOut(duration: 0.35).repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.13),
                        value: phase
                    )
            }
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

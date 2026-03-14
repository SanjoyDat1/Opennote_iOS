import SwiftUI
import UIKit

// MARK: - Inline Feynman Chat Bar
//
// Gemini-style inline experience: messages appear directly above the input pill,
// no separate sheet. Users can clear or copy any AI response inline.
//
// Layout when messages exist:
//   ┌─────────────────────────────────────┐  ← white message card (scrollable)
//   │  [User bubble]                      │
//   │  [AI text]  [× Clear chat] [□ Copy] │
//   └─────────────────────────────────────┘
//   ╔═══════════════════════════════════════╗  ← green pill input
//   ║  [+]  Ask Feynman…              [↑]  ║
//   ╚═══════════════════════════════════════╝
//
// Collapsed chip: shown while the user is typing inside a note block.

struct FeynmanChatBar: View {
    @Bindable var viewModel: FeynmanChatBarViewModel
    @Bindable var conversation: FeynmanConversationViewModel
    @FocusState.Binding var isFocused: Bool

    var isNoteFocused: Bool = false
    var journalContext: String = ""
    var onPlus: () -> Void
    var onInsertIntoJournal: ((String) -> Void)?
    var onExpandFromCollapsed: () -> Void = {}

    @State private var showClearConfirm = false
    @State private var isChatMinimized = false

    private var isCollapsed: Bool { isNoteFocused && !isFocused }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedChip
            } else {
                VStack(spacing: 0) {
                    if !conversation.messages.isEmpty && !isChatMinimized {
                        chatPanel
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                    inputBar
                }
                // Solid backing so journal text never bleeds through the input area
                .background(Color(.systemBackground))
                .overlay(alignment: .top) {
                    // Thin fade gradient at the top edge for a soft separation
                    LinearGradient(
                        colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 18)
                    .offset(y: -18)
                    .allowsHitTesting(false)
                }
                .onChange(of: conversation.messages.count) { _, _ in
                    // Auto-expand whenever a new message arrives
                    isChatMinimized = false
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isCollapsed)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: conversation.messages.isEmpty)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isChatMinimized)
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .confirmationDialog("Clear conversation?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                Haptics.notification(.warning)
                conversation.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase all Feynman messages.")
        }
    }

    // MARK: Collapsed chip ─────────────────────────────────────────────────────

    private var collapsedChip: some View {
        HStack(spacing: 10) {
            // ── Ask Feynman pill — LEFT ─────────────────────────
            Button {
                Haptics.impact(.light)
                // Dismiss the journal keyboard first, then focus the chat input
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                onExpandFromCollapsed()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.opennoteGreen)
                    Text("Ask Feynman")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.opennoteGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .background(Color.opennoteLightGreen.opacity(0.45))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.opennoteGreen.opacity(0.32), lineWidth: 1.2))
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)

            Spacer()

            // ── Keyboard dismiss — RIGHT ────────────────────────
            Button {
                Haptics.impact(.light)
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(.systemGray))
                    .frame(width: 38, height: 38)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .padding(.bottom, 10)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.88).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: Chat panel ─────────────────────────────────────────────────────────

    private var chatPanel: some View {
        VStack(spacing: 0) {
            // Header: label + active mode badge + dismiss
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.opennoteGreen)
                    Text("Feynman")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    // Active mode badge
                    HStack(spacing: 3) {
                        Image(systemName: conversation.selectedMode.icon)
                            .font(.system(size: 9, weight: .semibold))
                        Text(conversation.selectedMode.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.opennoteGreen)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.opennoteGreen.opacity(0.1))
                    .clipShape(Capsule())
                    .animation(.easeOut(duration: 0.2), value: conversation.selectedMode.title)
                }
                Spacer()
                Button {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isChatMinimized = true
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.systemGray3))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 2)

            Divider().opacity(0.5)

            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(conversation.messages.enumerated()), id: \.element.id) { index, msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                        Color.clear.frame(height: 1).id("__chat_bottom__")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: 280)
                .onChange(of: conversation.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("__chat_bottom__", anchor: .bottom)
                    }
                }
                .onChange(of: conversation.messages.last?.content) { _, _ in
                    proxy.scrollTo("__chat_bottom__", anchor: .bottom)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20
            )
            .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: -6)
    }

    // MARK: Message bubble ─────────────────────────────────────────────────────

    @ViewBuilder
    private func messageBubble(_ message: FeynmanChatMessage) -> some View {
        if message.isUser {
            userBubble(message)
        } else {
            assistantBubble(message)
        }
    }

    private func userBubble(_ message: FeynmanChatMessage) -> some View {
        HStack {
            Spacer(minLength: 52)
            Text(message.content)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.opennoteLightGreen.opacity(0.65))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 5,
                        topTrailingRadius: 18
                    )
                )
        }
    }

    private func assistantBubble(_ message: FeynmanChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if message.isStreaming && message.content.isEmpty {
                TypingDotsView()
                    .padding(.vertical, 4)
            } else {
                markdownText(message.content)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Action buttons — shown once streaming finishes
            if !message.isStreaming && !message.content.isEmpty {
                HStack(spacing: 8) {
                    // Clear chat
                    actionPill(icon: "xmark", label: "Clear chat", tint: .secondary) {
                        showClearConfirm = true
                    }

                    // Copy
                    actionPill(icon: "doc.on.doc", label: "Copy", tint: .secondary) {
                        UIPasteboard.general.string = message.content
                        Haptics.selection()
                    }

                    // Insert into journal
                    actionPill(icon: "arrow.down.doc.fill", label: "Insert", tint: Color.opennoteGreen) {
                        onInsertIntoJournal?(message.content)
                        Haptics.impact(.medium)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: message.isStreaming)
    }

    private func actionPill(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                tint == Color.opennoteGreen
                    ? Color.opennoteLightGreen.opacity(0.55)
                    : Color(.systemGray6)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Input bar ──────────────────────────────────────────────────────────

    private var inputBar: some View {
        VStack(spacing: 0) {
            // ── Main text-input row ───────────────────────────────
            HStack(alignment: .center, spacing: 12) {
                // + attachment / tools
                Button {
                    Haptics.impact(.light)
                    onPlus()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.opennoteGreen)
                }
                .buttonStyle(.plain)

                // Expanding text field
                TextField("Ask Feynman…", text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 17))
                    .tint(Color.opennoteGreen)
                    .focused($isFocused)

                // Keyboard dismiss — visible whenever keyboard is up
                if isFocused {
                    Button {
                        Haptics.impact(.light)
                        isFocused = false
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                // Send / stop button
                Button {
                    Haptics.impact(.medium)
                    handleSendOrStop()
                } label: {
                    let active = viewModel.hasText || conversation.isStreaming
                    Image(systemName: conversation.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(active ? .white : Color(.systemGray3))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(active ? Color.opennoteGreen : Color(.systemGray5)))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.hasText && !conversation.isStreaming)
                .animation(.easeOut(duration: 0.15), value: viewModel.hasText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)
            .padding(.bottom, isFocused || !conversation.messages.isEmpty ? 8 : 13)

            // ── Mode chip row (shown when bar is active) ──────────
            if isFocused || !conversation.messages.isEmpty {
                modeChipRow
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.opennoteLightGreen.opacity(0.82))
        )
        .padding(.horizontal, 12)
        .padding(.top, conversation.messages.isEmpty ? 0 : 6)
        .padding(.bottom, isFocused ? 0 : 10)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isFocused)
        .animation(.spring(response: 0.25), value: conversation.messages.isEmpty)
    }

    // MARK: Mode chip row ──────────────────────────────────────────────────────

    private var modeChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FeynmanMode.allCases) { mode in
                    modeChip(mode)
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private func modeChip(_ mode: FeynmanMode) -> some View {
        let isSelected = viewModel.selectedMode == mode
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                viewModel.selectedMode = mode
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(mode.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? Color.opennoteGreen : Color(.systemGray))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? Color.white.opacity(0.85)
                    : Color.white.opacity(0.38)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.opennoteGreen.opacity(0.45) : Color.clear,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: isSelected)
    }

    // MARK: Actions ────────────────────────────────────────────────────────────

    private func handleSendOrStop() {
        if conversation.isStreaming {
            conversation.stopStreaming()
            return
        }
        let trimmed = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.clearInput()
        conversation.selectedMode = viewModel.selectedMode
        conversation.send(prompt: trimmed, journalContext: journalContext)
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

// MARK: - Preview

private struct FeynmanChatBarPreviewContainer: View {
    @FocusState private var isFocused: Bool
    @State private var vm = FeynmanChatBarViewModel()
    @State private var conv = FeynmanConversationViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            FeynmanChatBar(
                viewModel: vm,
                conversation: conv,
                isFocused: $isFocused,
                isNoteFocused: false,
                journalContext: "",
                onPlus: {}
            )
        }
    }
}

#Preview("FeynmanChatBar — Empty") {
    FeynmanChatBarPreviewContainer()
}

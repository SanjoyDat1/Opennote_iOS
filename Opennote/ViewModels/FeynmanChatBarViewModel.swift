import SwiftUI
import UIKit

// MARK: - Feynman Mode

/// The four ways Feynman can respond.
/// `.auto` is the default — Feynman reads the question and silently picks the best style.
enum FeynmanMode: String, CaseIterable, Identifiable {
    case auto     = "Auto"
    case socratic = "Socratic"
    case direct   = "Direct"
    case explain  = "Explain"

    var id: String { rawValue }
    var title: String { rawValue }

    var icon: String {
        switch self {
        case .auto:     return "sparkles"
        case .socratic: return "bubble.left.and.bubble.right.fill"
        case .direct:   return "arrow.right.circle.fill"
        case .explain:  return "text.book.closed.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .auto:
            return "Feynman picks the best approach for your question"
        case .socratic:
            return "Guided questions so you discover the answer yourself"
        case .direct:
            return "Quick, crisp answer with one sharp insight"
        case .explain:
            return "Deep dive — examples, analogies, and first principles"
        }
    }

    /// Full system prompt sent to the LLM for this mode.
    var systemPrompt: String {
        switch self {

        case .auto:
            return """
            You are Feynman, a brilliant teacher and thinking partner. \
            For every message, silently decide which of the three styles below \
            best serves the user — then respond in that style only. \
            Do NOT announce which style you chose.

            ◉ SOCRATIC — use when the user is exploring a concept or working through \
            a problem they should reason through themselves. \
            Respond with exactly 2–3 probing questions that expose hidden assumptions, \
            surface contradictions, or open a new angle. No direct answers.

            ◉ DIRECT — use when the question is factual, definitional, or calls for \
            a quick clear answer. Respond in 2–4 crisp sentences. \
            Add one sharp "key insight" that reframes why it matters.

            ◉ EXPLAIN — use when the topic is complex, abstract, or the user clearly \
            needs deep intuitive understanding. Give a thorough breakdown using concrete \
            analogies, first-principles reasoning, and plain language. \
            Build understanding step by step. End with an "aha" reframe.

            Your north star: always make the user genuinely smarter, not just more informed.
            """

        case .socratic:
            return """
            You are Feynman using the Socratic method. \
            Do NOT give direct answers under any circumstances. \
            Respond ONLY with exactly 2–3 carefully crafted questions that guide the \
            user to discover the answer themselves. \
            Each question should expose a hidden assumption, reveal a contradiction, \
            or unlock a new angle of inquiry. \
            If the user is close to understanding, your questions should feel like \
            the final, gentle nudge across the finish line. \
            Be curious and encouraging — never condescending or vague.
            """

        case .direct:
            return """
            You are Feynman in Direct mode. Give the most precise, concise answer \
            possible in 2–4 sentences — no padding, no preamble, no hedging. \
            After the answer, add exactly one "Key insight:" on a new line that \
            reframes the concept or reveals why it matters in a surprising way. \
            Think of this as the answer you'd give a brilliant colleague in 30 seconds.
            """

        case .explain:
            return """
            You are Feynman, master explainer. Give a rich, layered explanation of \
            whatever the user asks. Start from first principles. Use at least one \
            concrete analogy drawn from everyday life. Layer complexity gradually — \
            build intuition before introducing formalism. \
            Assume the user is smart but completely new to this topic. \
            Never use jargon without immediately unpacking it. \
            End with an "aha moment" — one insight that makes the whole thing click \
            and connects it to something bigger.
            """
        }
    }

    /// Legacy alias used by OpenAIService.
    var systemPromptPrefix: String? { systemPrompt }

    var isDefault: Bool { self == .auto }
}

// MARK: - Suggested prompts

let feynmanSuggestedPrompts = [
    "Explain what I just wrote",
    "Summarize this note",
    "What should I explore next?",
    "Quiz me on this",
]

// MARK: - Chat bar view model

@Observable
final class FeynmanChatBarViewModel {
    var inputText: String = ""
    var selectedMode: FeynmanMode = .auto
    var attachedImage: UIImage?
    var isRecording: Bool = false
    var isKeyboardActive: Bool = false
    var suggestedPrompts: [String] = feynmanSuggestedPrompts
    var showSuggestedChips: Bool = false

    var hasContent: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil
    }

    var hasText: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func clearInput() {
        inputText = ""
        attachedImage = nil
    }

    func removeAttachedImage() {
        attachedImage = nil
    }

    func setAttachedImage(_ image: UIImage?) {
        attachedImage = image
    }

    func appendTranscribedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if inputText.isEmpty {
            inputText = trimmed
        } else {
            inputText += " " + trimmed
        }
    }
}

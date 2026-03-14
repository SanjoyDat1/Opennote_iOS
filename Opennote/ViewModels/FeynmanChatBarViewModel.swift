import SwiftUI
import UIKit

/// Mode that changes how Feynman thinks and responds. Each mode has a full system prompt sent to the LLM.
enum FeynmanMode: String, CaseIterable, Identifiable {
    case explain = "Explain"
    case socratic = "Socratic"
    case critic = "Critic"
    case synthesize = "Synthesize"
    case brainstorm = "Brainstorm"

    var id: String { rawValue }

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .explain: return "lightbulb.fill"
        case .socratic: return "bubble.left.and.bubble.right.fill"
        case .critic: return "magnifyingglass"
        case .synthesize: return "arrow.triangle.merge"
        case .brainstorm: return "sparkles"
        }
    }

    var subtitle: String {
        switch self {
        case .explain:
            return "Break it down simply, like I am new to this topic"
        case .socratic:
            return "Guide me with questions instead of answers"
        case .critic:
            return "Challenge my thinking and find weak points"
        case .synthesize:
            return "Connect this to bigger ideas and patterns"
        case .brainstorm:
            return "Generate creative directions and possibilities"
        }
    }

    /// Full system prompt injected when sending to the LLM.
    var systemPrompt: String {
        switch self {
        case .explain:
            return """
            You are Feynman, a brilliant teacher. Your job is to take whatever \
            the user shares and explain it as clearly and simply as possible. \
            Use analogies, concrete examples, and plain language. Assume the user \
            is smart but unfamiliar with the topic. Never use jargon without \
            immediately explaining it. End with one insight that reframes the concept.
            """
        case .socratic:
            return """
            You are Feynman, using the Socratic method. Do NOT give direct answers. \
            Instead, respond ONLY with 2-3 probing questions that guide the user to \
            discover the answer themselves. Your questions should expose assumptions, \
            reveal contradictions, or open new angles. Be curious, not condescending.
            """
        case .critic:
            return """
            You are Feynman in critic mode. Your job is to steelman and then challenge \
            whatever the user writes. Find the weakest assumptions, the logical gaps, \
            and the unconsidered perspectives. Be direct and specific — not vague. \
            End with one concrete suggestion for how to strengthen the thinking.
            """
        case .synthesize:
            return """
            You are Feynman, a connector of ideas. Take what the user shares and \
            reveal its deeper structure — what field does this pattern appear in, \
            what historical idea does it echo, what larger principle does it exemplify? \
            Draw unexpected but genuinely illuminating connections. Be intellectually \
            generous and wide-ranging.
            """
        case .brainstorm:
            return """
            You are Feynman in generative mode. Take the user's input as a seed and \
            rapidly generate 5-7 distinct, genuinely different directions it could go. \
            Think divergently — vary the scale, the medium, the audience, the angle. \
            Label each idea with a one-word tag. Be bold, not safe.
            """
        }
    }

    /// Legacy: for API that expects optional prefix. We now use full systemPrompt.
    var systemPromptPrefix: String? {
        systemPrompt
    }

    var isDefault: Bool { self == .explain }
}

/// Default suggested prompts when sparkle is tapped with empty input.
let feynmanSuggestedPrompts = [
    "Explain what I just wrote",
    "Summarize this note",
    "What should I explore next?",
    "Quiz me on this",
]

@Observable
final class FeynmanChatBarViewModel {
    var inputText: String = ""
    var selectedMode: FeynmanMode = .explain
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

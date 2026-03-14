import SwiftUI
import UIKit

/// Cached keyboard height for scroll-to-cursor (avoids depending on KeyboardObserver from Coordinator).
private enum ParagraphTextViewKeyboardHeight {
    static var height: CGFloat = 0
    static var observer: Any?
    static func ensureObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil, queue: .main
        ) { notif in
            if let frame = (notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) {
                height = frame.height
            }
        }
        _ = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil, queue: .main
        ) { _ in height = 0 }
    }
}

/// UITextView-backed paragraph editor with cursor scroll-to-visible.
/// Replaces SwiftUI TextField to fix cursor disappearing behind keyboard.
struct ParagraphTextView: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool
    var editorFont: AppSettings.EditorFont = .default
    let onSubmit: () -> Void
    var onSlashTriggered: ((String) -> Void)?
    var onBecameEmpty: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func resolvedFont() -> UIFont {
        switch editorFont {
        case .default:
            return UIFont.systemFont(ofSize: 17, weight: .regular)
        case .serif:
            return UIFont(name: "Georgia", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .regular)
        }
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = resolvedFont()
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.tintColor = UIColor(red: 94 / 255, green: 158 / 255, blue: 99 / 255, alpha: 1) // opennoteGreen
        textView.returnKeyType = .default
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.isUserInteractionEnabled = true
        textView.isEditable = true
        textView.isSelectable = true
        if textView.text != text {
            textView.text = text
        }
        let desired = resolvedFont()
        if textView.font != desired {
            textView.font = desired
        }
        let maxWidth = UIScreen.main.bounds.width - 32
        if textView.frame.width != maxWidth {
            textView.frame.size.width = maxWidth
        }
        context.coordinator.parent = self
        context.coordinator.placeholder = placeholder
        textView.setNeedsDisplay()

        if isFocused && !textView.isFirstResponder {
            textView.becomeFirstResponder()
            // Place cursor at the end so backspace-to-merge feels natural
            let end = textView.endOfDocument
            textView.selectedTextRange = textView.textRange(from: end, to: end)
        }
        if let scrollView = textView.findParentScrollView() {
            scrollView.alwaysBounceHorizontal = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.keyboardDismissMode = .none
            scrollView.delaysContentTouches = false
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: ParagraphTextView  // Updated in updateUIView so onFocusChange uses latest closure
        var placeholder: String

        init(_ parent: ParagraphTextView) {
            self.parent = parent
            placeholder = parent.placeholder
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text

            scrollToCursor(in: textView)
            checkSlashTrigger(in: textView)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let range = textView.selectedTextRange else { return }
                let rect = textView.caretRect(for: range.end)
                textView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -60), animated: true)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            scrollToCursor(in: textView)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Backspace on an already-empty field → delete block and move up
            if text.isEmpty {
                if textView.text.isEmpty {
                    parent.onBecameEmpty?()
                    return false
                }
                if range.length > 0 {
                    let newText = (textView.text as NSString).replacingCharacters(in: range, with: "")
                    if newText.isEmpty, parent.onBecameEmpty != nil {
                        parent.onBecameEmpty?()
                        return false
                    }
                }
            }

            guard text == "\n" else { return true }

            let nsText = textView.text as NSString
            let currentLineRange = nsText.lineRange(for: range)
            let currentLine = nsText.substring(with: currentLineRange)

            if currentLine.hasPrefix("• ") || currentLine.hasPrefix("- ") {
                let prefix = currentLine.hasPrefix("• ") ? "• " : "- "
                let lineContent = currentLine
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .dropFirst(prefix.count)

                if lineContent.isEmpty {
                    let newText = nsText.replacingCharacters(in: currentLineRange, with: "\n")
                    textView.text = newText
                    let newPosition = range.location - prefix.count + 1
                    textView.selectedRange = NSRange(location: max(0, newPosition), length: 0)
                    parent.text = textView.text
                    return false
                }

                let insertion = "\n" + prefix
                textView.insertText(insertion)
                parent.text = textView.text
                scrollToCursor(in: textView)
                return false
            }

            let numberedListPattern = #"^(\d+)\. "#
            if let regex = try? NSRegularExpression(pattern: numberedListPattern),
               let match = regex.firstMatch(in: currentLine, range: NSRange(currentLine.startIndex..., in: currentLine)),
               let numberRange = Range(match.range(at: 1), in: currentLine),
               let number = Int(currentLine[numberRange]) {
                let lineContent = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)
                let prefixLength = "\(number). ".count
                let content = lineContent.count > prefixLength ? String(lineContent.dropFirst(prefixLength)) : ""

                if content.isEmpty {
                    textView.insertText("\n")
                    parent.text = textView.text
                    return false
                }

                let insertion = "\n\(number + 1). "
                textView.insertText(insertion)
                parent.text = textView.text
                scrollToCursor(in: textView)
                return false
            }

            parent.onSubmit()
            return false
        }

        private func scrollToCursor(in textView: UITextView) {
            guard let selectedRange = textView.selectedTextRange,
                  let scrollView = textView.findParentScrollView()
            else { return }

            ParagraphTextViewKeyboardHeight.ensureObserving()
            let cursorRect = textView.caretRect(for: selectedRange.end)
            let cursorRectInScroll = textView.convert(cursorRect, to: scrollView)
            let keyboardHeight = ParagraphTextViewKeyboardHeight.height
            let visibleHeight = scrollView.frame.height - keyboardHeight - 80
            let visibleBottom = scrollView.contentOffset.y + visibleHeight
            let visibleTop = scrollView.contentOffset.y + 80

            if cursorRectInScroll.maxY > visibleBottom {
                let newOffset = cursorRectInScroll.maxY - visibleHeight + 20
                scrollView.setContentOffset(CGPoint(x: 0, y: max(0, newOffset)), animated: true)
            } else if cursorRectInScroll.minY < visibleTop {
                let newOffset = cursorRectInScroll.minY - 80
                scrollView.setContentOffset(CGPoint(x: 0, y: max(0, newOffset)), animated: true)
            }
        }

        private func checkSlashTrigger(in textView: UITextView) {
            let t = textView.text ?? ""
            let slashAtStart = t.hasPrefix("/") || t.contains("\n/")
            guard slashAtStart, let trigger = parent.onSlashTriggered else { return }
            let filter: String
            if let idx = t.lastIndex(of: "/") {
                let after = t.index(after: idx)
                filter = after < t.endIndex ? String(t[after...]) : ""
            } else {
                filter = ""
            }
            trigger(filter)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange?(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange?(false)
        }
    }
}

extension UIView {
    func findParentScrollView() -> UIScrollView? {
        var view = superview
        while let v = view {
            if let sv = v as? UIScrollView { return sv }
            view = v.superview
        }
        return nil
    }
}

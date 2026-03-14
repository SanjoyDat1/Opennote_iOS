import SwiftUI
import UIKit

/// Tracks keyboard visibility and height for cursor-scroll calculations.
final class KeyboardObserver: ObservableObject {
    static let shared = KeyboardObserver()

    @Published var keyboardHeight: CGFloat = 0
    @Published var isVisible: Bool = false

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) {
                self.keyboardHeight = frame.height
                self.isVisible = true
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) {
                self.keyboardHeight = 0
                self.isVisible = false
            }
        }
    }
}

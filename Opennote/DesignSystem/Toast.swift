import SwiftUI

/// Simple toast overlay for "Coming soon" and other feedback.
struct ToastModifier: ViewModifier {
    let message: String
    let isPresented: Bool
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    Text(message)
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray))
                        .clipShape(Capsule())
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { onDismiss() }
                }
            }
            .animation(.easeOut(duration: 0.3), value: isPresented)
    }
}

extension View {
    func toast(_ message: String, isPresented: Bool, onDismiss: @escaping () -> Void) -> some View {
        modifier(ToastModifier(message: message, isPresented: isPresented, onDismiss: onDismiss))
    }
}

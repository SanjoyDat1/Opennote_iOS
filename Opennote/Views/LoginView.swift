import SwiftUI

struct LoginView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field { case email, password }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text("Welcome to Opennote")
                    .opennoteMajorHeader()
                    .multilineTextAlignment(.center)
                
                Text("The notebook that thinks with you.")
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.secondary)
                
                // Continue with Google
                Button {
                    performSignIn()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text("Continue with Google")
                            .font(.system(size: 17, weight: .medium, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4).opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                
                // Or divider
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                }
                
                // Email & Password fields
                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .opennoteTextFieldStyle()
                        .focused($focusedField, equals: .email)
                    
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textContentType(.password)
                                .opennoteTextFieldStyle()
                                .focused($focusedField, equals: .password)
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .opennoteTextFieldStyle()
                                .focused($focusedField, equals: .password)
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Action buttons: Back to App | Sign In
                HStack(spacing: 12) {
                    Button("Back to App") {
                        performSignIn()
                    }
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4).opacity(0.5), lineWidth: 1)
                    )
                    
                    Button("Sign In") {
                        performSignIn()
                    }
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.opennoteGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Forgot password
                Button("Forgot Password?") {
                    // TODO: Forgot password flow
                }
                .font(.system(.body, design: .default))
                .foregroundStyle(.secondary)
                
                // Sign up
                Button {
                    performSignIn()
                } label: {
                    Text("Don't have an account? ")
                        .foregroundStyle(.secondary)
                    + Text("Sign up")
                        .foregroundStyle(.primary)
                        .fontWeight(.medium)
                }
                .font(.system(.body, design: .default))
            }
            .padding(24)
            .padding(.top, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.opennoteCream)
    }
    
    private func performSignIn() {
        // MVP: Simulate sign-in with hardcoded Sanjoy
        appViewModel.signIn(user: OpennoteUser(
            id: "mvp-user",
            email: email.isEmpty ? nil : email,
            name: "Sanjoy"
        ))
    }
}

struct OpennoteTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

extension View {
    func opennoteTextFieldStyle() -> some View {
        modifier(OpennoteTextFieldModifier())
    }
}

#Preview {
    LoginView()
        .environment(AppViewModel())
}

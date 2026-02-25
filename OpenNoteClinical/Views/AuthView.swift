import SwiftUI

/// Apple HIG-compliant login and signup screen for clinical note-taking.
struct AuthView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    enum AuthMode {
        case signIn
        case signUp
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    formSection
                    errorSection
                    primaryButton
                    switchModeButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "stethoscope.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            
            Text("OpenNote Clinical")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("AI-powered clinical note-taking for cardiology and radiology")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom, 16)
    }
    
    private var formSection: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Password", text: $password)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .textFieldStyle(.roundedBorder)
            
            if mode == .signUp {
                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if let message = authViewModel.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal)
        }
    }
    
    private var primaryButton: some View {
        Button {
            Task {
                if mode == .signIn {
                    await authViewModel.signIn(email: email, password: password)
                } else {
                    guard password == confirmPassword else {
                        authViewModel.errorMessage = "Passwords do not match"
                        return
                    }
                    guard password.count >= 6 else {
                        authViewModel.errorMessage = "Password must be at least 6 characters"
                        return
                    }
                    await authViewModel.signUp(email: email, password: password)
                }
            }
        } label: {
            HStack {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(mode == .signIn ? "Sign In" : "Create Account")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
        .controlSize(.large)
    }
    
    private var switchModeButton: some View {
        Button {
            mode = mode == .signIn ? .signUp : .signIn
            authViewModel.errorMessage = nil
        } label: {
            Text(mode == .signIn ? "Create an account" : "Already have an account? Sign in")
                .font(.subheadline)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AuthView()
        .environment(AuthViewModel())
}

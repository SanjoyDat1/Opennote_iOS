import SwiftUI

/// AI chat sidebar. Use .sheet on iPhone, .inspector on iPad.
struct AIAssistantSidebarView: View {
    @Bindable var viewModel: AIAssistantViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesList
                Divider()
                inputBar
            }
            .navigationTitle("Clinical AI Co-Pilot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { viewModel.clear() }
                }
            }
        }
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let err = viewModel.errorMessage {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                    }
                    if viewModel.messages.isEmpty {
                        emptyState
                    }
                    ForEach(viewModel.messages) { msg in
                        ChatBubbleView(message: msg)
                            .id(msg.id)
                    }
                    if viewModel.isLoading && viewModel.messages.last?.role == "user" {
                        HStack {
                            ProgressView()
                            Text("Thinking…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "stethoscope.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Ask about your notes")
                .font(.headline)
            Text("I can help structure echocardiogram, ECG, and DICOM findings. Ask clarifying questions about missing metrics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask the AI…", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit { send() }
            
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
        }
        .padding()
    }
    
    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await viewModel.send(text) }
    }
}

private struct ChatBubbleView: View {
    let message: AIChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == "user" { Spacer(minLength: 48) }
            
            Text(message.content)
                .font(.body)
                .padding(12)
                .background(message.role == "user" ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 280, alignment: .leading)
            
            if message.role == "assistant" { Spacer(minLength: 48) }
        }
    }
}

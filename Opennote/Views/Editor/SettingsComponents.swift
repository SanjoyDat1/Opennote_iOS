import SwiftUI

/// Shared components for Journal and Paper settings sheets.
struct FrequencySheet: View {
    @Bindable var appSettings: AppSettings
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List(AppSettings.SuggestionFrequency.allCases, id: \.rawValue) { freq in
                Button {
                    appSettings.suggestionFrequency = freq
                    isPresented = false
                } label: {
                    HStack {
                        Text(freq.rawValue)
                        if appSettings.suggestionFrequency == freq {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.opennoteGreen)
                        }
                    }
                }
            }
            .navigationTitle("Frequency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundStyle(Color.opennoteGreen)
                }
            }
        }
    }
}

struct IntegrationsSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Connect your apps")
                    .font(.headline)
                Text("Link Google Drive, Notion, or other tools to sync your notes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Integrations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundStyle(Color.opennoteGreen)
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

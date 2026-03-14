import SwiftUI

/// Code block with language selector (Python, Java, C++) and mock IDE: console input/output.
struct CodeCardBlockView: View {
    let code: String
    let language: String
    let stdin: String
    let stdout: String
    let blockId: UUID
    @Binding var focusedBlockId: UUID?
    let onUpdate: (String, String, String, String) -> Void  // language, code, stdin, stdout

    private static let supportedLanguages = ["Python", "Java", "C++"]

    @State private var isRunning = false
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Language selector
            HStack(spacing: 8) {
                Menu {
                    ForEach(Self.supportedLanguages, id: \.self) { lang in
                        Button(lang) {
                            Haptics.selection()
                            onUpdate(lang, code, stdin, stdout)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.opennoteGreen)
                        Text(language)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                Button {
                    Haptics.impact(.light)
                    Task { await runCode() }
                } label: {
                    HStack(spacing: 6) {
                        if isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                        }
                        Text("Run")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.opennoteGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isRunning || code.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.plain)
            }

            // Code editor
            TextEditor(text: Binding(
                get: { code },
                set: { onUpdate(language, $0, stdin, stdout) }
            ))
            .focused($isEditorFocused)
            .font(.system(size: 14, design: .monospaced))
            .onChange(of: isEditorFocused) { _, focused in
                if focused { focusedBlockId = blockId }
                else if focusedBlockId == blockId { focusedBlockId = nil }
            }
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(minHeight: 100)

            // Console: Input
            VStack(alignment: .leading, spacing: 6) {
                Text("Input")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("stdin (e.g. test input)", text: Binding(
                    get: { stdin },
                    set: { onUpdate(language, code, $0, stdout) }
                ), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(3...6)
                .padding(10)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Console: Output
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Output")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if !stdout.isEmpty {
                        Text("· \(stdout.components(separatedBy: "\n").count) lines")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                ScrollView {
                    Text(stdout.isEmpty ? "Output will appear here after running" : stdout)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(stdout.isEmpty ? .tertiary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 60, maxHeight: 150)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }
        }
    }

    private func runCode() async {
        isRunning = true
        defer { isRunning = false }
        let result = await CodeExecutionService.execute(language: language, code: code, stdin: stdin)
        let output = result.success
            ? (result.stderr.isEmpty ? result.stdout : result.stdout + "\n--- stderr ---\n" + result.stderr)
            : (result.stderr.isEmpty ? result.stdout : result.stderr)
        await MainActor.run {
            onUpdate(language, code, stdin, output)
        }
    }
}

import SwiftUI

/// Sheet for recording voice and converting to text via speech recognition.
struct VoiceInputSheet: View {
    @ObservedObject var service: SpeechToTextService
    var insertIntoPrompt: Bool = false
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if service.isListening {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.opennoteGreen)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                        Text("Listening...")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.secondary)
                        if !service.transcribedText.isEmpty {
                            ScrollView {
                                Text(service.transcribedText)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            }
                            .frame(maxHeight: 160)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 32)
                } else if !service.transcribedText.isEmpty {
                    VStack(spacing: 16) {
                        Text(service.transcribedText)
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 24)
                } else if let err = service.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)
                        Text(err)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.opennoteGreen)
                        Text("Preparing voice input...")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 48)
                }

                Spacer(minLength: 0)

                if service.isListening {
                    Button {
                        Haptics.impact(.medium)
                        service.stopListening()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                if !service.transcribedText.isEmpty && !service.isListening {
                    Button {
                        Haptics.impact(.medium)
                        onInsert(service.transcribedText)
                        service.reset()
                    } label: {
                        Text(insertIntoPrompt ? "Add to prompt" : "Insert into Journal")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.opennoteGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.opennoteCream)
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        service.stopListening()
                        service.reset()
                        onDismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await service.startListening()
                }
            }
            .onDisappear {
                service.stopListening()
            }
        }
    }
}

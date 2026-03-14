import Foundation
import Speech
import AVFoundation

/// Handles speech-to-text using the iOS Speech framework.
@MainActor
final class SpeechToTextService: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcribedText = ""
    @Published var isListening = false
    @Published var errorMessage: String?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    func startListening() async {
        guard speechRecognizer != nil else {
            errorMessage = "Speech recognition is not available for this locale."
            return
        }
        if authorizationStatus != .authorized {
            let ok = await requestAuthorization()
            guard ok else {
                errorMessage = "Speech recognition access was denied."
                return
            }
        }

        transcribedText = ""
        errorMessage = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Could not configure audio session: \(error.localizedDescription)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Could not create recognition request."
            return
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Could not start audio engine: \(error.localizedDescription)"
            return
        }

        isListening = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }
                if error != nil {
                    self?.stopListening()
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
    }

    func reset() {
        transcribedText = ""
        errorMessage = nil
    }
}

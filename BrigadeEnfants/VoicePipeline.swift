import AVFoundation
import Speech

final class VoicePipeline: NSObject, AVSpeechSynthesizerDelegate {
    var onPartialText: ((String) -> Void)?
    var onFinalText: ((String) -> Void)?
    var onSpeechFinished: (() -> Void)?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceWork: DispatchWorkItem?
    private var lastText = ""

    override init() { super.init(); synthesizer.delegate = self }

    static func frenchVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.lowercased().hasPrefix("fr") }.sorted {
            if $0.gender != $1.gender { return $0.gender == .male }
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            return $0.name < $1.name
        }
    }

    static func preferredMaleFrenchVoice() -> AVSpeechSynthesisVoice? {
        frenchVoices().first { $0.gender == .male && $0.quality == .premium }
            ?? frenchVoices().first { $0.gender == .male && $0.quality == .enhanced }
            ?? frenchVoices().first { $0.gender == .male }
            ?? frenchVoices().first
    }

    func requestPermissions() async throws {
        let speech = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        guard speech == .authorized else { throw LiveError.connection("Autorisez la reconnaissance vocale dans Réglages.") }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else { throw LiveError.connection("Autorisez le microphone dans Réglages.") }
    }

    func startListening() throws {
        stopListening(deliver: false)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers]); try session.setActive(true, options: .notifyOthersOnDeactivation)
        let request = SFSpeechAudioBufferRecognitionRequest(); request.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true { request.requiresOnDeviceRecognition = true }
        self.request = request; lastText = ""
        let input = audioEngine.inputNode; let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        audioEngine.prepare(); try audioEngine.start()
        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.lastText = result.bestTranscription.formattedString; self.onPartialText?(self.lastText); self.scheduleSilenceFinish()
                if result.isFinal { self.stopListening(deliver: true) }
            } else if error != nil { self.stopListening(deliver: !self.lastText.isEmpty) }
        }
    }

    private func scheduleSilenceFinish() {
        silenceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.stopListening(deliver: true) }; silenceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35, execute: work)
    }

    func stopListening(deliver: Bool) {
        silenceWork?.cancel(); silenceWork = nil
        if audioEngine.isRunning { audioEngine.stop(); audioEngine.inputNode.removeTap(onBus: 0) }
        request?.endAudio(); task?.cancel(); request = nil; task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let final = lastText; lastText = ""
        if deliver && !final.isEmpty { onFinalText?(final) }
    }

    func speak(_ text: String, voiceID: String) {
        stopListening(deliver: false); synthesizer.stopSpeaking(at: .immediate)
        let session = AVAudioSession.sharedInstance(); try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers]); try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceID) ?? Self.preferredMaleFrenchVoice()
        utterance.rate = 0.46; utterance.pitchMultiplier = 0.88; utterance.preUtteranceDelay = 0.12
        synthesizer.speak(utterance)
    }

    func stopAll() { stopListening(deliver: false); synthesizer.stopSpeaking(at: .immediate) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation); onSpeechFinished?()
    }
}


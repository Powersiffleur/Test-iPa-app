import Foundation
import AVFoundation

enum AIProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case gemini = "Gemini"
    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var provider: AIProvider = .openAI
    @Published var apiKey = ""
    @Published var isConfigured = false
    @Published var isCalling = false
    @Published var isListening = false
    @Published var isThinking = false
    @Published var status = "Prêt à appeler"
    @Published var heardText = ""
    @Published var replyText = ""
    @Published var errorMessage: String?
    @Published var selectedVoiceID: String

    let voice = VoicePipeline()
    private var history: [[String: String]] = []

    init() {
        selectedVoiceID = UserDefaults.standard.string(forKey: "selectedVoiceID") ?? VoicePipeline.preferredMaleFrenchVoice()?.identifier ?? ""
        loadKey()
        voice.onPartialText = { [weak self] text in Task { @MainActor in self?.heardText = text } }
        voice.onFinalText = { [weak self] text in Task { @MainActor in await self?.answer(to: text) } }
        voice.onSpeechFinished = { [weak self] in Task { @MainActor in
            guard let self, self.isCalling else { return }
            self.status = "Je vous écoute…"
            try? self.voice.startListening()
            self.isListening = true
        }}
    }

    var availableVoices: [AVSpeechSynthesisVoice] { VoicePipeline.frenchVoices() }

    func loadKey() { apiKey = KeychainStore.read(account: provider.rawValue) ?? ""; isConfigured = !apiKey.isEmpty }
    func select(_ newProvider: AIProvider) { provider = newProvider; loadKey() }
    func saveKey() {
        let clean = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        KeychainStore.save(clean, account: provider.rawValue); apiKey = clean; isConfigured = true
    }
    func removeKey() { KeychainStore.delete(account: provider.rawValue); apiKey = ""; isConfigured = false }
    func chooseVoice(_ id: String) { selectedVoiceID = id; UserDefaults.standard.set(id, forKey: "selectedVoiceID") }
    func testVoice() { voice.speak("Bonjour, Brigade des Enfants à l'appareil. Quel est le problème ?", voiceID: selectedVoiceID) }

    func toggleCall() async { if isCalling { endCall() } else { await startCall() } }

    private func startCall() async {
        guard isConfigured else { errorMessage = "Ajoutez d'abord une clé API."; return }
        do {
            try await voice.requestPermissions()
            isCalling = true; history.removeAll(); heardText = ""
            replyText = "Bonjour, Brigade des Enfants à l'appareil. Quel est le problème ?"
            status = "La Brigade répond…"
            voice.speak(replyText, voiceID: selectedVoiceID)
        } catch { errorMessage = error.localizedDescription }
    }

    func endCall() {
        voice.stopAll(); isCalling = false; isListening = false; isThinking = false; status = "Appel terminé"
    }

    private func answer(to text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isCalling, !clean.isEmpty else { return }
        isListening = false; isThinking = true; status = "La Brigade réfléchit…"
        history.append(["role": "user", "content": clean])
        if history.count > 10 { history.removeFirst(history.count - 10) }
        do {
            guard let key = KeychainStore.read(account: provider.rawValue) else { throw LiveError.connection("Clé API absente.") }
            let answer = try await TextAIService.reply(provider: provider, apiKey: key, history: history)
            replyText = answer; history.append(["role": "assistant", "content": answer])
            isThinking = false; status = "La Brigade répond…"
            voice.speak(answer, voiceID: selectedVoiceID)
        } catch { isThinking = false; errorMessage = error.localizedDescription; status = "Erreur de réponse" }
    }
}


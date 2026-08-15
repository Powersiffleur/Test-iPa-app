import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.19, blue: 0.34)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BRIGADE").font(.caption.bold()).tracking(4).foregroundStyle(.cyan)
                        Text("des Enfants").font(.title.bold()).foregroundStyle(.white)
                    }
                    Spacer()
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill").font(.title3).padding(12).background(.white.opacity(0.1), in: Circle()) }.foregroundStyle(.white)
                }

                Spacer()
                ZStack {
                    Circle().fill(model.isCalling ? .red.opacity(0.18) : .cyan.opacity(0.10)).frame(width: 260, height: 260)
                    Circle().stroke(model.isCalling ? .red.opacity(0.55) : .cyan.opacity(0.35), lineWidth: 2).frame(width: 220, height: 220)
                    Image(systemName: model.isCalling ? "waveform.circle.fill" : "phone.circle.fill")
                        .resizable().scaledToFit().frame(width: 150).foregroundStyle(model.isCalling ? .red : .cyan).symbolEffect(.pulse, isActive: model.isCalling)
                }
                Text(model.status).font(.headline).foregroundStyle(.white)
                Text(model.provider.rawValue + " Texte • Voix locale").font(.subheadline).foregroundStyle(.white.opacity(0.6))

                if !model.heardText.isEmpty || !model.replyText.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if !model.heardText.isEmpty {
                            Text("Vous : \(model.heardText)").foregroundStyle(.white.opacity(0.72))
                        }
                        if !model.replyText.isEmpty {
                            Text("Brigade : \(model.replyText)").foregroundStyle(.white)
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    Task { await model.toggleCall() }
                } label: {
                    Label(model.isCalling ? "Raccrocher" : "Appeler la Brigade", systemImage: model.isCalling ? "phone.down.fill" : "mic.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(model.isCalling ? Color.red : Color.cyan, in: RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(model.isCalling ? .white : Color(red: 0.03, green: 0.08, blue: 0.15))
                }

                Text("Jeu de rôle fictif réservé aux adultes accompagnant un enfant. Ce n'est pas un service de police ni un service d'urgence.")
                    .font(.caption).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.5))
            }.padding(24)
        }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        .alert("Impossible de continuer", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .onAppear { if !model.isConfigured { showSettings = true } }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Moteur vocal") {
                    Picker("Fournisseur", selection: Binding(get: { model.provider }, set: { model.select($0) })) {
                        ForEach(AIProvider.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("Clé API \(model.provider.rawValue)") {
                    SecureField(model.provider == .openAI ? "sk-…" : "AIza…", text: $model.apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Enregistrer dans le trousseau iPhone") { model.saveKey(); dismiss() }.disabled(model.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if model.isConfigured { Button("Supprimer la clé", role: .destructive) { model.removeKey() } }
                }
                Section("Voix française masculine") {
                    Picker("Voix installée", selection: Binding(get: { model.selectedVoiceID }, set: { model.chooseVoice($0) })) {
                        ForEach(model.availableVoices, id: \.identifier) { voice in
                            Text("\(voice.name) — \(qualityName(voice.quality))").tag(voice.identifier)
                        }
                    }
                    Button("Écouter un exemple") { model.testVoice() }
                    Text("Pour obtenir une voix très réaliste : Réglages iPhone → Accessibilité → Contenu énoncé → Voix → Français, puis téléchargez une voix Premium ou Améliorée. Revenez ensuite ici pour la sélectionner.")
                        .font(.caption)
                }
                Section("Important") {
                    Text("La reconnaissance et la voix sont assurées par l'iPhone. Seule la courte réponse texte de l'IA utilise votre crédit API.")
                    Text("L'abonnement ChatGPT Plus n'est pas une clé API. Les appels API sont facturés séparément par le fournisseur choisi.")
                    Text("Pour une diffusion publique, remplacez la clé enregistrée sur l'iPhone par des jetons temporaires délivrés par votre serveur.")
                }
            }
            .navigationTitle("Connexion IA")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
        }
    }

    private func qualityName(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: return "Premium"
        case .enhanced: return "Améliorée"
        default: return "Standard"
        }
    }
}

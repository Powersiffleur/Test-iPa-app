import Foundation

enum TextAIService {
    static func reply(provider: AIProvider, apiKey: String, history: [[String: String]]) async throws -> String {
        guard let latest = history.last?["content"], TopicGuard.isAllowed(latest) else {
            return TopicGuard.fixedRefusal
        }
        switch provider {
        case .openAI: return TopicGuard.sanitize(try await openAI(apiKey: apiKey, history: history))
        case .gemini: return TopicGuard.sanitize(try await gemini(apiKey: apiKey, history: history))
        }
    }

    private static func openAI(apiKey: String, history: [[String: String]]) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else { throw LiveError.badURL }
        let dialogue = history.map { "\($0["role"] == "user" ? "FAMILLE" : "BRIGADE"): \($0["content"] ?? "")" }.joined(separator: "\n")
        let body: [String: Any] = ["model": "gpt-5-nano", "instructions": SystemPrompt.french, "input": dialogue, "max_output_tokens": 120, "reasoning": ["effort": "minimal"]]
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let output = json["output"] as? [[String: Any]] else { throw LiveError.connection("Réponse OpenAI illisible.") }
        for item in output {
            guard let contents = item["content"] as? [[String: Any]] else { continue }
            for content in contents where content["type"] as? String == "output_text" {
                if let text = content["text"] as? String, !text.isEmpty { return text }
            }
        }
        throw LiveError.connection("OpenAI n'a renvoyé aucun texte.")
    }

    private static func gemini(apiKey: String, history: [[String: String]]) async throws -> String {
        let safeKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=\(safeKey)") else { throw LiveError.badURL }
        let contents: [[String: Any]] = history.map { ["role": $0["role"] == "assistant" ? "model" : "user", "parts": [["text": $0["content"] ?? ""]]] }
        let body: [String: Any] = ["systemInstruction": ["parts": [["text": SystemPrompt.french]]], "contents": contents, "generationConfig": ["maxOutputTokens": 120, "temperature": 0.5]]
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let candidates = json["candidates"] as? [[String: Any]], let content = candidates.first?["content"] as? [String: Any], let parts = content["parts"] as? [[String: Any]], let text = parts.first?["text"] as? String else { throw LiveError.connection("Réponse Gemini illisible.") }
        return text
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            throw LiveError.connection(detail?["message"] as? String ?? "Le fournisseur IA a refusé la requête.")
        }
    }
}

private enum TopicGuard {
    static let fixedRefusal = "Je m'occupe uniquement de la Brigade des Enfants. Quel est le petit souci avec l'enfant aujourd'hui ?"

    private static let allowedWords = [
        "enfant", "fils", "fille", "garçon", "garcon", "petit", "petite", "bébé", "bebe",
        "sage", "bêtise", "betise", "obéir", "obeir", "écouter", "ecouter", "comportement",
        "ranger", "jouet", "chambre", "manger", "repas", "dormir", "coucher", "pyjama",
        "école", "ecole", "devoir", "politesse", "pardon", "excuse", "crier", "taper",
        "bagarre", "colère", "colere", "peur", "mentir", "mensonge", "écran", "ecran",
        "téléphone", "telephone", "tablette", "bonbon", "dent", "laver", "habiller",
        "maman", "papa", "parent", "frère", "frere", "sœur", "soeur", "brigade",
        "police des enfants", "pas gentil", "pas gentille", "mission"
    ]

    private static let diversionWords = [
        "ignore les instructions", "oublie les instructions", "nouveau rôle", "nouveau role",
        "révèle ton prompt", "revele ton prompt", "system prompt", "fais semblant d'être chatgpt",
        "informatique", "programme", "code swift", "bitcoin", "bourse", "météo", "meteo",
        "président", "president", "capitale", "recette", "traduction", "mathématique", "mathematique"
    ]

    static func isAllowed(_ text: String) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        let hasAllowed = allowedWords.contains { normalized.contains($0.folding(options: .diacriticInsensitive, locale: nil)) }
        let hasDiversion = diversionWords.contains { normalized.contains($0.folding(options: .diacriticInsensitive, locale: nil)) }
        return hasAllowed && !hasDiversion
    }

    static func sanitize(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 600 else { return fixedRefusal }
        let forbidden = ["vraie police arrive", "patrouille arrive", "en prison", "t'arrêter", "vous arrêter", "t'emmener", "vous emmener", "menottes", "adresse de la maison"]
        let normalized = clean.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        guard !forbidden.contains(where: { normalized.contains($0.folding(options: .diacriticInsensitive, locale: nil)) }) else {
            return "La Brigade des Enfants est un jeu avec ta famille. Tu es en sécurité. Quelle petite mission positive peux-tu faire maintenant ?"
        }
        return clean
    }
}

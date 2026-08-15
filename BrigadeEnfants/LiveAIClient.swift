import Foundation

enum LiveError: LocalizedError {
    case badURL, connection(String)
    var errorDescription: String? {
        switch self {
        case .badURL: return "Adresse de connexion invalide."
        case .connection(let text): return text
        }
    }
}

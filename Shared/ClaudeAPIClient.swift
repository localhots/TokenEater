import Foundation

final class ClaudeAPIClient {
    static let shared = ClaudeAPIClient()

    private let baseURL = "https://claude.ai"

    /// Whether this client runs from the host app (not sandboxed) or the widget (sandboxed)
    var isHostApp = false

    var config: SharedConfig? {
        SharedStorage.readConfig(fromHost: isHostApp)
    }

    // MARK: - Fetch Usage

    func fetchUsage() async throws -> UsageResponse {
        guard let config = config, !config.sessionKey.isEmpty else {
            throw ClaudeAPIError.noSessionKey
        }

        guard !config.organizationID.isEmpty else {
            throw ClaudeAPIError.noOrganizationID
        }

        guard let url = URL(string: "\(baseURL)/api/organizations/\(config.organizationID)/usage") else {
            throw ClaudeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sessionKey=\(config.sessionKey)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
            // Cache the data
            let cached = CachedUsage(usage: usage, fetchDate: Date())
            SharedStorage.writeCache(cached, fromHost: isHostApp)
            return usage
        case 401, 403:
            throw ClaudeAPIError.sessionExpired
        default:
            throw ClaudeAPIError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Test Connection

    func testConnection(sessionKey: String, orgID: String) async -> ConnectionTestResult {
        guard let url = URL(string: "\(baseURL)/api/organizations/\(orgID)/usage") else {
            return ConnectionTestResult(success: false, message: "URL invalide")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return ConnectionTestResult(success: false, message: "Reponse invalide")
            }

            if httpResponse.statusCode == 200 {
                let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
                let sessionPct = usage.fiveHour?.utilization ?? 0
                return ConnectionTestResult(success: true, message: "Connexion OK — Session: \(Int(sessionPct))%")
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return ConnectionTestResult(success: false, message: "Session expiree ou invalide (HTTP \(httpResponse.statusCode))")
            } else {
                return ConnectionTestResult(success: false, message: "Erreur HTTP \(httpResponse.statusCode)")
            }
        } catch {
            return ConnectionTestResult(success: false, message: "Erreur reseau: \(error.localizedDescription)")
        }
    }

    // MARK: - Cache

    func loadCachedUsage() -> CachedUsage? {
        SharedStorage.readCache(fromHost: isHostApp)
    }
}

// MARK: - Error

enum ClaudeAPIError: LocalizedError {
    case noSessionKey
    case noOrganizationID
    case invalidURL
    case invalidResponse
    case sessionExpired
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .noSessionKey:
            return "Pas de cle de session configuree. Ouvrez l'app pour la configurer."
        case .noOrganizationID:
            return "Organization ID non configure. Entrez-le dans l'app."
        case .invalidURL:
            return "URL invalide"
        case .invalidResponse:
            return "Reponse invalide du serveur"
        case .sessionExpired:
            return "Session expiree — reconnectez-vous sur claude.ai et mettez a jour le cookie"
        case .httpError(let code):
            return "Erreur HTTP \(code)"
        }
    }
}

// MARK: - Test Result

struct ConnectionTestResult {
    let success: Bool
    let message: String
}

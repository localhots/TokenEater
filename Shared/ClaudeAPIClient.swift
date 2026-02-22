import Foundation

enum AuthMethod {
    case oauth(token: String)
    case cookies(sessionKey: String, orgId: String)
}

final class ClaudeAPIClient {
    static let shared = ClaudeAPIClient()

    private let baseURL = "https://claude.ai"

    /// Whether this client runs from the host app (not sandboxed) or the widget (sandboxed)
    var isHostApp = false

    var config: SharedConfig? {
        SharedStorage.readConfig(fromHost: isHostApp)
    }

    // MARK: - Auth Resolution

    func resolveAuthMethod() -> AuthMethod? {
        // Priority 1: OAuth from Keychain
        if let oauth = KeychainOAuthReader.readClaudeCodeToken() {
            return .oauth(token: oauth.accessToken)
        }
        // Priority 2: Stored cookies
        if let config = config, !config.sessionKey.isEmpty, !config.organizationID.isEmpty {
            return .cookies(sessionKey: config.sessionKey, orgId: config.organizationID)
        }
        return nil
    }

    // MARK: - Fetch Usage

    func fetchUsage() async throws -> UsageResponse {
        guard let method = resolveAuthMethod() else {
            throw ClaudeAPIError.noSessionKey
        }
        return try await fetchUsage(with: method)
    }

    private func fetchUsage(with method: AuthMethod) async throws -> UsageResponse {
        let request: URLRequest
        switch method {
        case .oauth(let token):
            guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
                throw ClaudeAPIError.invalidURL
            }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request = req

        case .cookies(let sessionKey, let orgId):
            guard let url = URL(string: "\(baseURL)/api/organizations/\(orgId)/usage") else {
                throw ClaudeAPIError.invalidURL
            }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
            request = req
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
            let cached = CachedUsage(usage: usage, fetchDate: Date())
            SharedStorage.writeCache(cached, fromHost: isHostApp)
            return usage
        case 401, 403:
            // If cookies failed, try OAuth as fallback
            if case .cookies = method, let oauth = KeychainOAuthReader.readClaudeCodeToken() {
                return try await fetchUsage(with: .oauth(token: oauth.accessToken))
            }
            throw ClaudeAPIError.sessionExpired
        default:
            throw ClaudeAPIError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Test Connection

    func testConnection(method: AuthMethod) async -> ConnectionTestResult {
        let request: URLRequest
        switch method {
        case .oauth(let token):
            guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
                return ConnectionTestResult(success: false, message: String(localized: "error.invalidurl"))
            }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            request = req

        case .cookies(let sessionKey, let orgId):
            guard let url = URL(string: "\(baseURL)/api/organizations/\(orgId)/usage") else {
                return ConnectionTestResult(success: false, message: String(localized: "error.invalidurl"))
            }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
            request = req
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return ConnectionTestResult(success: false, message: String(localized: "error.invalidresponse.short"))
            }

            if httpResponse.statusCode == 200 {
                guard let usage = try? JSONDecoder().decode(UsageResponse.self, from: data) else {
                    return ConnectionTestResult(success: false, message: String(localized: "error.unsupportedplan"))
                }
                let sessionPct = usage.fiveHour?.utilization ?? 0
                return ConnectionTestResult(success: true, message: String(format: String(localized: "test.success"), Int(sessionPct)))
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return ConnectionTestResult(success: false, message: String(format: String(localized: "test.expired"), httpResponse.statusCode))
            } else {
                return ConnectionTestResult(success: false, message: String(format: String(localized: "test.http"), httpResponse.statusCode))
            }
        } catch {
            return ConnectionTestResult(success: false, message: String(format: String(localized: "error.network"), error.localizedDescription))
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
    case unsupportedPlan
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .noSessionKey:
            return String(localized: "error.nosessionkey")
        case .noOrganizationID:
            return String(localized: "error.noorgid")
        case .invalidURL:
            return String(localized: "error.invalidurl")
        case .invalidResponse:
            return String(localized: "error.invalidresponse")
        case .sessionExpired:
            return String(localized: "error.sessionexpired")
        case .unsupportedPlan:
            return String(localized: "error.unsupportedplan")
        case .httpError(let code):
            return String(format: String(localized: "error.http"), code)
        }
    }
}

// MARK: - Test Result

struct ConnectionTestResult {
    let success: Bool
    let message: String
}

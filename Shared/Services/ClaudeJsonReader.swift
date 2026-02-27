import Foundation

final class ClaudeJsonReader: @unchecked Sendable {
    private let filePath: String

    init() {
        guard let pw = getpwuid(getuid()) else {
            filePath = ""
            return
        }
        filePath = String(cString: pw.pointee.pw_dir) + "/.claude.json"
    }

    init(filePath: String) {
        self.filePath = filePath
    }

    func readModelStats() -> [ModelTokenStats] {
        guard let data = FileManager.default.contents(atPath: filePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any]
        else { return [] }

        var totals: [String: Int] = [:]
        for (_, projectValue) in projects {
            guard let project = projectValue as? [String: Any],
                  let modelUsage = project["lastModelUsage"] as? [String: Any]
            else { continue }

            for (modelId, usageValue) in modelUsage {
                guard let usage = usageValue as? [String: Any] else { continue }
                let tokens = (usage["inputTokens"] as? Int ?? 0)
                    + (usage["outputTokens"] as? Int ?? 0)
                    + (usage["cacheReadInputTokens"] as? Int ?? 0)
                    + (usage["cacheCreationInputTokens"] as? Int ?? 0)
                let name = shortModelName(modelId)
                totals[name, default: 0] += tokens
            }
        }

        return totals
            .filter { $0.value > 0 }
            .map { ModelTokenStats(modelName: $0.key, totalTokens: $0.value) }
            .sorted { $0.totalTokens > $1.totalTokens }
    }

    private func shortModelName(_ id: String) -> String {
        let lower = id.lowercased()

        let displayName: String
        if lower.contains("opus") { displayName = "Opus" }
        else if lower.contains("sonnet") { displayName = "Sonnet" }
        else if lower.contains("haiku") { displayName = "Haiku" }
        else { return id }

        // e.g. "claude-sonnet-4-6-20251101" → drop first 2, strip 8-digit date → "4.6"
        let parts = lower.components(separatedBy: "-")
        let version = parts.dropFirst(2)
            .filter { !($0.count == 8 && Int($0) != nil) }
            .joined(separator: ".")

        return version.isEmpty ? displayName : "\(displayName) \(version)"
    }
}

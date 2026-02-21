import Foundation

// MARK: - API Response

struct UsageResponse: Codable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDaySonnet: UsageBucket?
    let sevenDayOauthApps: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDayCowork: UsageBucket?
    let extraUsage: ExtraUsageInfo?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDayCowork = "seven_day_cowork"
        case extraUsage = "extra_usage"
    }
}

struct UsageBucket: Codable {
    let utilization: Double
    let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        // Try with fractional seconds first (API format), then without
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: resetsAt) {
            return date
        }
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        return withoutFractional.date(from: resetsAt)
    }
}

// Flexible decoding: ignore unknown structure for extra_usage
struct ExtraUsageInfo: Codable {
    init(from decoder: Decoder) throws {
        // Accept any JSON structure without failing
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

// MARK: - App Constants

enum AppConstants {
    static let widgetBundleID = "com.claudeusagewidget.app.widget"
    static let configFileName = "claude-usage-config.json"
    static let cacheFileName = "claude-usage-cache.json"
}

// MARK: - Shared Config (written by app, read by widget)

struct SharedConfig: Codable {
    var sessionKey: String
    var organizationID: String
}

// MARK: - Cached Usage (for offline support)

struct CachedUsage: Codable {
    let usage: UsageResponse
    let fetchDate: Date
}

// MARK: - Shared File Manager

enum SharedStorage {
    /// Path the widget uses (inside its own sandbox container)
    static var widgetContainerConfigURL: URL {
        // Widget reads from its own Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(AppConstants.configFileName)
    }

    static var widgetContainerCacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(AppConstants.cacheFileName)
    }

    /// Path the host app uses to write INTO the widget's container (app is not sandboxed)
    static var hostAppConfigURL: URL {
        let widgetContainer = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(AppConstants.widgetBundleID)/Data/Library/Application Support")
        // Create directory if needed
        try? FileManager.default.createDirectory(at: widgetContainer, withIntermediateDirectories: true)
        return widgetContainer.appendingPathComponent(AppConstants.configFileName)
    }

    static var hostAppCacheURL: URL {
        let widgetContainer = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(AppConstants.widgetBundleID)/Data/Library/Application Support")
        try? FileManager.default.createDirectory(at: widgetContainer, withIntermediateDirectories: true)
        return widgetContainer.appendingPathComponent(AppConstants.cacheFileName)
    }

    // MARK: - Read/Write Config

    static func writeConfig(_ config: SharedConfig, fromHost: Bool) {
        let url = fromHost ? hostAppConfigURL : widgetContainerConfigURL
        try? JSONEncoder().encode(config).write(to: url)
    }

    static func readConfig(fromHost: Bool) -> SharedConfig? {
        let url = fromHost ? hostAppConfigURL : widgetContainerConfigURL
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SharedConfig.self, from: data)
    }

    // MARK: - Read/Write Cache

    static func writeCache(_ cache: CachedUsage, fromHost: Bool) {
        let url = fromHost ? hostAppCacheURL : widgetContainerCacheURL
        try? JSONEncoder().encode(cache).write(to: url)
    }

    static func readCache(fromHost: Bool) -> CachedUsage? {
        let url = fromHost ? hostAppCacheURL : widgetContainerCacheURL
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedUsage.self, from: data)
    }
}

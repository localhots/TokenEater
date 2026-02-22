import Foundation

// MARK: - API Response

struct UsageResponse: Codable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDaySonnet: UsageBucket?
    let sevenDayOauthApps: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDayCowork: UsageBucket?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDayCowork = "seven_day_cowork"
    }

    init(fiveHour: UsageBucket? = nil, sevenDay: UsageBucket? = nil, sevenDaySonnet: UsageBucket? = nil,
         sevenDayOauthApps: UsageBucket? = nil, sevenDayOpus: UsageBucket? = nil, sevenDayCowork: UsageBucket? = nil) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.sevenDaySonnet = sevenDaySonnet
        self.sevenDayOauthApps = sevenDayOauthApps
        self.sevenDayOpus = sevenDayOpus
        self.sevenDayCowork = sevenDayCowork
    }

    // Decode tolerantly: unknown keys are ignored, broken buckets become nil
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try? container.decode(UsageBucket.self, forKey: .fiveHour)
        sevenDay = try? container.decode(UsageBucket.self, forKey: .sevenDay)
        sevenDaySonnet = try? container.decode(UsageBucket.self, forKey: .sevenDaySonnet)
        sevenDayOauthApps = try? container.decode(UsageBucket.self, forKey: .sevenDayOauthApps)
        sevenDayOpus = try? container.decode(UsageBucket.self, forKey: .sevenDayOpus)
        sevenDayCowork = try? container.decode(UsageBucket.self, forKey: .sevenDayCowork)
    }
}

struct UsageBucket: Codable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        guard let resetsAt else { return nil }
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
    var proxyEnabled: Bool
    var proxyHost: String
    var proxyPort: Int

    init(sessionKey: String = "", organizationID: String = "",
         proxyEnabled: Bool = false, proxyHost: String = "127.0.0.1", proxyPort: Int = 1080) {
        self.sessionKey = sessionKey
        self.organizationID = organizationID
        self.proxyEnabled = proxyEnabled
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionKey = try container.decode(String.self, forKey: .sessionKey)
        organizationID = try container.decode(String.self, forKey: .organizationID)
        proxyEnabled = try container.decodeIfPresent(Bool.self, forKey: .proxyEnabled) ?? false
        proxyHost = try container.decodeIfPresent(String.self, forKey: .proxyHost) ?? "127.0.0.1"
        proxyPort = try container.decodeIfPresent(Int.self, forKey: .proxyPort) ?? 1080
    }
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

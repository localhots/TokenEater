import Foundation
import CommonCrypto
import Security
import SQLite3

// MARK: - Browser Detection

struct DetectedBrowser: Identifiable {
    let id: String
    let name: String
    let icon: String
    let cookiePaths: [URL]
    let keychainService: String
}

// MARK: - Browser Cookie Reader

enum BrowserCookieReader {

    struct CookieResult {
        let sessionKey: String
        let organizationID: String
        let browser: String
        let sessionKeyExpires: Date?
    }

    enum ImportError: LocalizedError {
        case keychainDenied(String)
        case keychainNotFound(String)
        case dbCopyFailed(String)
        case dbOpenFailed(String)
        case noCookiesInDB
        case decryptionFailed(found: Int)
        case missingCookie(hasSession: Bool, hasOrg: Bool)

        var errorDescription: String? {
            switch self {
            case .keychainDenied(let svc):
                return String(format: String(localized: "error.keychain.denied"), svc)
            case .keychainNotFound(let svc):
                return String(format: String(localized: "error.keychain.notfound"), svc)
            case .dbCopyFailed(let path):
                return String(format: String(localized: "error.db.copy"), path)
            case .dbOpenFailed(let path):
                return String(format: String(localized: "error.db.open"), path)
            case .noCookiesInDB:
                return String(localized: "error.nocookies")
            case .decryptionFailed(let found):
                return String(format: String(localized: "error.decryption"), found)
            case .missingCookie(let hasSession, let hasOrg):
                let missing = !hasSession && !hasOrg ? String(localized: "error.missing.both")
                    : !hasSession ? String(localized: "error.missing.session") : String(localized: "error.missing.org")
                return String(format: String(localized: "error.missing.cookie"), missing)
            }
        }
    }

    // All supported Chromium browsers
    private static let browsers: [(id: String, name: String, icon: String, pathComponent: String, keychain: String)] = [
        ("chrome", "Google Chrome", "globe", "Google/Chrome", "Chrome Safe Storage"),
        ("arc", "Arc", "globe", "Arc/User Data", "Arc Safe Storage"),
        ("brave", "Brave", "globe", "BraveSoftware/Brave-Browser", "Brave Safe Storage"),
        ("edge", "Microsoft Edge", "globe", "Microsoft Edge", "Microsoft Edge Safe Storage"),
        ("chromium", "Chromium", "globe", "Chromium", "Chromium Safe Storage"),
    ]

    // MARK: - Public API

    static func detectBrowsers() -> [DetectedBrowser] {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")

        return browsers.compactMap { browser in
            let baseDir = appSupport.appendingPathComponent(browser.pathComponent)
            let profiles = findProfiles(in: baseDir)
            guard !profiles.isEmpty else { return nil }

            return DetectedBrowser(
                id: browser.id,
                name: browser.name,
                icon: browser.icon,
                cookiePaths: profiles,
                keychainService: browser.keychain
            )
        }
    }

    static func importCookies(from browser: DetectedBrowser) -> Result<CookieResult, ImportError> {
        let key: Data
        switch getDecryptionKey(service: browser.keychainService) {
        case .success(let k): key = k
        case .failure(let err): return .failure(err)
        }

        // Try each profile
        var lastError: ImportError = .noCookiesInDB
        for cookiePath in browser.cookiePaths {
            switch readCookies(from: cookiePath, key: key, browserName: browser.name) {
            case .success(let result): return .success(result)
            case .failure(let err): lastError = err
            }
        }

        return .failure(lastError)
    }

    // MARK: - Profile Discovery

    private static func findProfiles(in baseDir: URL) -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: baseDir.path) else { return [] }

        var paths: [URL] = []

        let defaultCookies = baseDir.appendingPathComponent("Default/Cookies")
        if fm.fileExists(atPath: defaultCookies.path) {
            paths.append(defaultCookies)
        }

        if let contents = try? fm.contentsOfDirectory(atPath: baseDir.path) {
            for item in contents where item.hasPrefix("Profile ") {
                let profileCookies = baseDir.appendingPathComponent("\(item)/Cookies")
                if fm.fileExists(atPath: profileCookies.path) {
                    paths.append(profileCookies)
                }
            }
        }

        return paths
    }

    // MARK: - Keychain

    private static func getDecryptionKey(service: String) -> Result<Data, ImportError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return .failure(.keychainNotFound(service))
        }
        if status == errSecAuthFailed || status == errSecUserCanceled {
            return .failure(.keychainDenied(service))
        }
        guard status == errSecSuccess, let passwordData = result as? Data else {
            return .failure(.keychainDenied("\(service) (code: \(status))"))
        }
        guard let passwordString = String(data: passwordData, encoding: .utf8) else {
            return .failure(.keychainDenied("\(service) (encodage invalide)"))
        }

        // Derive AES key with PBKDF2
        let salt = "saltysalt"
        let iterations: UInt32 = 1003
        let keyLength = 16

        var derivedKey = Data(count: keyLength)
        let derivationStatus = derivedKey.withUnsafeMutableBytes { derivedKeyPtr in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordString,
                passwordString.utf8.count,
                salt,
                salt.utf8.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                iterations,
                derivedKeyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                keyLength
            )
        }

        guard derivationStatus == kCCSuccess else {
            return .failure(.keychainDenied("\(service) (PBKDF2 echoue)"))
        }

        return .success(derivedKey)
    }

    // MARK: - SQLite + Decryption

    private static func readCookies(from cookiePath: URL, key: Data, browserName: String) -> Result<CookieResult, ImportError> {
        var db: OpaquePointer?

        // Try 1: copy DB + WAL to temp (reads WAL data, most reliable)
        let tp = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokeneater_cookies_\(UUID().uuidString).db")
        var opened = false
        do {
            try FileManager.default.copyItem(at: cookiePath, to: tp)
            for ext in ["-wal", "-shm", "-journal"] {
                let src = URL(fileURLWithPath: cookiePath.path + ext)
                let dst = URL(fileURLWithPath: tp.path + ext)
                try? FileManager.default.copyItem(at: src, to: dst)
            }
            opened = sqlite3_open_v2(tp.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK
        } catch {
            // Copy failed, will try immutable URI below
        }

        // Try 2: immutable URI (no WAL but works if copy fails)
        if !opened {
            sqlite3_close(db)
            db = nil
            let encodedPath = cookiePath.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cookiePath.path
            let immutableURI = "file:\(encodedPath)?immutable=1"
            opened = sqlite3_open_v2(immutableURI, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK
        }

        defer {
            sqlite3_close(db)
            try? FileManager.default.removeItem(at: tp)
            for ext in ["-wal", "-shm", "-journal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: tp.path + ext))
            }
        }

        guard opened, db != nil else {
            return .failure(.dbOpenFailed(cookiePath.path))
        }

        // Query claude.ai cookies
        let sql = """
            SELECT name, encrypted_value, expires_utc FROM cookies
            WHERE (host_key LIKE '%claude.ai' OR host_key LIKE '%claude.com')
            AND (name = 'sessionKey' OR name = 'lastActiveOrg')
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return .failure(.dbOpenFailed("SQL prepare failed"))
        }
        defer { sqlite3_finalize(stmt) }

        var sessionKey: String?
        var orgID: String?
        var sessionExpires: Date?
        var foundCount = 0

        // Chrome stores expires_utc as microseconds since 1601-01-01
        let chromeEpochOffset: Int64 = 11_644_473_600

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let namePtr = sqlite3_column_text(stmt, 0) else { continue }
            let name = String(cString: namePtr)

            let blobPtr = sqlite3_column_blob(stmt, 1)
            let blobSize = sqlite3_column_bytes(stmt, 1)

            guard let blobPtr = blobPtr, blobSize > 0 else { continue }
            let encryptedData = Data(bytes: blobPtr, count: Int(blobSize))
            foundCount += 1

            if let decrypted = decryptCookieValue(encryptedData, key: key), !decrypted.isEmpty {
                if name == "sessionKey" {
                    sessionKey = decrypted
                    let expiresUtc = sqlite3_column_int64(stmt, 2)
                    if expiresUtc > 0 {
                        let unixTimestamp = TimeInterval(expiresUtc / 1_000_000 - chromeEpochOffset)
                        sessionExpires = Date(timeIntervalSince1970: unixTimestamp)
                    }
                } else if name == "lastActiveOrg" {
                    orgID = decrypted
                }
            }
        }

        if foundCount == 0 {
            return .failure(.noCookiesInDB)
        }

        if sessionKey == nil || orgID == nil {
            if sessionKey == nil && orgID == nil && foundCount > 0 {
                return .failure(.decryptionFailed(found: foundCount))
            }
            return .failure(.missingCookie(hasSession: sessionKey != nil, hasOrg: orgID != nil))
        }

        return .success(CookieResult(sessionKey: sessionKey!, organizationID: orgID!, browser: browserName, sessionKeyExpires: sessionExpires))
    }

    private static func decryptCookieValue(_ data: Data, key: Data) -> String? {
        guard data.count > 3 else { return nil }

        let prefix = data[0..<3]
        let prefixStr = String(data: prefix, encoding: .utf8)

        // v10/v11 = AES-128-CBC
        if prefixStr == "v10" || prefixStr == "v11" {
            let payload = Data(data[3...])

            // Modern Chrome (v130+): header(16) + IV(16) + ciphertext
            if payload.count > 48 {
                let iv = Data(payload[16..<32])
                let ciphertext = Data(payload[32...])
                if let result = aesDecrypt(ciphertext, key: key, iv: iv) {
                    return result
                }
            }

            // Legacy format: IV = 16 spaces, ciphertext starts immediately
            let iv = Data(repeating: 0x20, count: 16)
            return aesDecrypt(payload, key: key, iv: iv)
        }

        // No prefix = unencrypted
        return String(data: data, encoding: .utf8)
    }

    private static func aesDecrypt(_ encrypted: Data, key: Data, iv: Data) -> String? {
        let bufferSize = encrypted.count + kCCBlockSizeAES128
        var decrypted = Data(count: bufferSize)
        var decryptedLength = 0

        let status = decrypted.withUnsafeMutableBytes { decPtr in
            encrypted.withUnsafeBytes { encPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            encPtr.baseAddress, encrypted.count,
                            decPtr.baseAddress, bufferSize,
                            &decryptedLength
                        )
                    }
                }
            }
        }

        guard status == Int32(kCCSuccess), decryptedLength > 0 else { return nil }
        return String(data: decrypted[0..<decryptedLength], encoding: .utf8)
    }
}

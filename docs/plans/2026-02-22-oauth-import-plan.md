# OAuth Import Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add OAuth (Claude Code Keychain) as primary auth method, with browser cookies as fallback, behind a single "Connect" button.

**Architecture:** `ClaudeAPIClient` gains a `resolveAuthMethod()` that checks Keychain first, then stored cookies. A new `KeychainOAuthReader` handles Keychain access. Settings UI is simplified to one "Connect" button that cascades through detection methods.

**Tech Stack:** Swift 5.9, Security framework, macOS Keychain API

---

### Task 1: Add KeychainOAuthReader

**Files:**
- Create: `Shared/KeychainOAuthReader.swift`

**Step 1: Create the reader**

```swift
import Foundation
import Security

enum KeychainOAuthReader {
    struct OAuthCredentials {
        let accessToken: String
    }

    static func readClaudeCodeToken() -> OAuthCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty
        else {
            return nil
        }

        return OAuthCredentials(accessToken: token)
    }
}
```

**Step 2: Commit**

```bash
git add Shared/KeychainOAuthReader.swift
git commit -m "feat: add KeychainOAuthReader for Claude Code OAuth tokens"
```

---

### Task 2: Add AuthMethod to ClaudeAPIClient

**Files:**
- Modify: `Shared/ClaudeAPIClient.swift`

**Step 1: Add AuthMethod enum and resolveAuthMethod()**

Add at the top of the file, after the class declaration:

```swift
enum AuthMethod {
    case oauth(token: String)
    case cookies(sessionKey: String, orgId: String)
}
```

Add method to ClaudeAPIClient:

```swift
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
```

**Step 2: Rewrite fetchUsage() to use AuthMethod**

Replace the existing `fetchUsage()` with:

```swift
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
```

**Step 3: Update testConnection() to support OAuth**

Replace the existing `testConnection()`:

```swift
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
```

Remove the old `testConnection(sessionKey:orgID:)` method.

**Step 4: Commit**

```bash
git add Shared/ClaudeAPIClient.swift
git commit -m "feat: add OAuth support to ClaudeAPIClient with auto-fallback"
```

---

### Task 3: Update MenuBarViewModel

**Files:**
- Modify: `ClaudeUsageApp/MenuBarView.swift`

**Step 1: Update hasConfig check**

In `MenuBarViewModel`, the `hasConfig` check currently looks at `ClaudeAPIClient.shared.config`. Update it to use `resolveAuthMethod()`:

In `init()`, replace:
```swift
hasConfig = ClaudeAPIClient.shared.config != nil
```
with:
```swift
hasConfig = ClaudeAPIClient.shared.resolveAuthMethod() != nil
```

In `refresh()`, replace:
```swift
guard ClaudeAPIClient.shared.config != nil else {
```
with:
```swift
guard ClaudeAPIClient.shared.resolveAuthMethod() != nil else {
```

In `reloadConfig()`, replace:
```swift
hasConfig = ClaudeAPIClient.shared.config != nil
```
with:
```swift
hasConfig = ClaudeAPIClient.shared.resolveAuthMethod() != nil
```

**Step 2: Commit**

```bash
git add ClaudeUsageApp/MenuBarView.swift
git commit -m "feat: menu bar uses resolveAuthMethod for config detection"
```

---

### Task 4: Update SettingsView — Connect button with cascade

**Files:**
- Modify: `ClaudeUsageApp/SettingsView.swift`
- Modify: `Shared/en.lproj/Localizable.strings`
- Modify: `Shared/fr.lproj/Localizable.strings`

**Step 1: Add new state variables and localization keys**

Add to SettingsView state:
```swift
@State private var authMethodLabel: String = ""
@State private var isOAuth = false
```

Add localization keys:

en.lproj:
```
"connect.button" = "Connect";
"connect.subtitle" = "Auto-detect Claude Code or browser cookies";
"connect.oauth.success" = "Connected via Claude Code";
"connect.detecting" = "Detecting...";
"connect.method.oauth" = "Claude Code (auto)";
"connect.method.cookies" = "Browser cookies";
"connect.method.manual" = "Manual";
```

fr.lproj:
```
"connect.button" = "Connexion";
"connect.subtitle" = "Detection auto Claude Code ou cookies navigateur";
"connect.oauth.success" = "Connecte via Claude Code";
"connect.detecting" = "Detection...";
"connect.method.oauth" = "Claude Code (auto)";
"connect.method.cookies" = "Cookies navigateur";
"connect.method.manual" = "Manuel";
```

**Step 2: Replace autoImportSection with unified connect section**

Replace the `autoImportSection` computed property with a new one that:
1. Shows a single "Connect" button
2. On tap: tries OAuth first, then browser cookies, then shows manual fields
3. Shows which method is active

```swift
private var autoImportSection: some View {
    VStack(spacing: 10) {
        Button {
            connectAutoDetect()
        } label: {
            HStack(spacing: 8) {
                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 13))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("connect.button")
                        .font(.system(size: 12, weight: .semibold))
                    Text("connect.subtitle")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                if !authMethodLabel.isEmpty {
                    Text(authMethodLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(green.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.white.opacity(0.85))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.15), accentRed.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(accent.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isImporting)

        if let message = importMessage {
            HStack(spacing: 8) {
                Image(systemName: importSuccess ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(importSuccess ? green : accent)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
            .transition(.opacity)
        }
    }
}
```

**Step 3: Add connectAutoDetect() method**

```swift
private func connectAutoDetect() {
    isImporting = true
    importMessage = nil

    // Step 1: Try OAuth from Keychain
    if let oauth = KeychainOAuthReader.readClaudeCodeToken() {
        Task {
            let result = await ClaudeAPIClient.shared.testConnection(method: .oauth(token: oauth.accessToken))
            await MainActor.run {
                isImporting = false
                if result.success {
                    isOAuth = true
                    authMethodLabel = String(localized: "connect.method.oauth")
                    importMessage = String(localized: "connect.oauth.success")
                    importSuccess = true
                    onConfigSaved?()
                } else {
                    // OAuth failed, try browser cookies
                    detectAndImportFromBrowser()
                }
            }
        }
        return
    }

    // Step 2: No OAuth, try browser cookies
    detectAndImportFromBrowser()
}

private func detectAndImportFromBrowser() {
    isImporting = true

    DispatchQueue.global(qos: .userInitiated).async {
        let browsers = BrowserCookieReader.detectBrowsers()

        if browsers.isEmpty {
            DispatchQueue.main.async {
                isImporting = false
                importMessage = String(localized: "import.nobroser")
                importSuccess = false
            }
            return
        }

        if browsers.count > 1 {
            DispatchQueue.main.async {
                detectedBrowsers = browsers
                showBrowserPicker = true
                isImporting = false
            }
            return
        }

        importFromBrowser(browsers[0])
    }
}
```

**Step 4: Update importFromBrowser success to set label**

In `importFromBrowser()`, in the `.success` case, add:
```swift
authMethodLabel = String(localized: "connect.method.cookies")
isOAuth = false
```

**Step 5: Update onAppear to detect current method**

In `loadConfig()`, add after loading config:
```swift
// Detect current auth method
if KeychainOAuthReader.readClaudeCodeToken() != nil {
    authMethodLabel = String(localized: "connect.method.oauth")
    isOAuth = true
} else if config != nil {
    authMethodLabel = String(localized: "connect.method.cookies")
    isOAuth = false
}
```

**Step 6: Hide sessionKey/orgId fields when OAuth is active**

Wrap the credentials fields and separator in a condition:
```swift
if !isOAuth {
    // ... existing sessionKey field ...
    // ... separator ...
    // ... orgId field ...
}
```

**Step 7: Update testConnection call**

In `testConnection()` method, replace:
```swift
let result = await ClaudeAPIClient.shared.testConnection(
    sessionKey: sessionKey,
    orgID: organizationID
)
```
with:
```swift
let method: AuthMethod = isOAuth
    ? .oauth(token: KeychainOAuthReader.readClaudeCodeToken()!.accessToken)
    : .cookies(sessionKey: sessionKey, orgId: organizationID)
let result = await ClaudeAPIClient.shared.testConnection(method: method)
```

**Step 8: Commit**

```bash
git add ClaudeUsageApp/SettingsView.swift Shared/en.lproj/Localizable.strings Shared/fr.lproj/Localizable.strings
git commit -m "feat: unified Connect button with OAuth priority and cookie fallback"
```

---

### Task 5: Build, test, and push

**Step 1: Regenerate Xcode project**

```bash
xcodegen generate
# Re-add NSExtension to widget Info.plist
plutil -insert NSExtension -json '{"NSExtensionPointIdentifier":"com.apple.widgetkit-extension"}' ClaudeUsageWidget/Info.plist 2>/dev/null || true
```

**Step 2: Build**

```bash
xcodebuild -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageApp -configuration Debug -derivedDataPath build build
```

**Step 3: Install and test**

```bash
cp -R "build/Build/Products/Debug/TokenEater.app" /Applications/
```

Test: Launch app, verify "Claude Code (auto)" badge appears, verify menu bar shows data.

**Step 4: Final commit and push**

```bash
git add -A
git commit -m "feat: OAuth auto-detect from Claude Code Keychain"
git push
```

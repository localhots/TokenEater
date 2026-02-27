# TokenEater - Project Instructions

## Language

- All communication (GitHub, conversations, code comments): **English**

## Build & Test Local

### Prerequisites
- **Xcode 16.4** (same version as CI `macos-15`) — install via `xcodes install 16.4`
- XcodeGen (`brew install xcodegen`)
- `DEVELOPMENT_TEAM` is not in `project.yml` — it is auto-detected from the local Apple certificate

### CI Toolchain (iso-prod)

CI (`macos-15`) uses **Xcode 16.4 / Swift 6.1.2**. To build a binary locally identical to what users receive via brew cask:

```bash
export DEVELOPER_DIR=/Applications/Xcode-16.4.0.app/Contents/Developer
```

**DO NOT** update the CI runner to a newer Xcode without testing — `@Observable` has Release optimization bugs with Swift 6.1.x that don't reproduce with Swift 6.2+. See Technical Notes section.

To install Xcode 16.4 alongside the current version:
```bash
brew install xcodes  # if not already installed
xcodes install 16.4 --directory /Applications
```

### Unit Tests

**80 tests** cover business logic (stores, repository, pacing, token recovery). Tests do NOT cover SwiftUI rendering or the widget under real conditions — for that, use build + nuke + install.

```bash
xcodegen generate
xcodebuild -project TokenEater.xcodeproj -scheme TokenEaterTests \
  -configuration Debug -derivedDataPath build \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  test
```

**When to run tests:**
- Before every commit touching `Shared/` (stores, services, repository, helpers, models)
- CI (`ci.yml`) runs them automatically on every PR and push to main

**When to test manually (build + nuke + install):**
- SwiftUI changes (views, layout, bindings)
- Widget changes (timeline, rendering)
- Always in **Release** with Xcode 16.4 for SwiftUI changes

**Writing tests:**
- Framework: Swift Testing (`import Testing`, `@Test`, `#expect`)
- Mocks are in `TokenEaterTests/Mocks/` — each service has a protocol-based mock
- Fixtures are in `TokenEaterTests/Fixtures/`
- Stores are `@MainActor` → test suites must also be `@MainActor`
- `UserDefaults.standard` is shared between tests → use `.serialized` on suites that write to UserDefaults + clean up in a helper

### Build Only (without install)
```bash
xcodegen generate
DEVELOPMENT_TEAM=$(security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject 2>/dev/null | grep -oE 'OU=[A-Z0-9]{10}' | head -1 | cut -d= -f2)
plutil -insert NSExtension -json '{"NSExtensionPointIdentifier":"com.apple.widgetkit-extension"}' TokenEaterWidget/Info.plist 2>/dev/null || true
xcodebuild -project TokenEater.xcodeproj -scheme TokenEaterApp -configuration Release -derivedDataPath build -allowProvisioningUpdates DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM build
```

### Build + Nuke + Install (one-liner)

**Use this command to test locally.** It does everything at once: Release build, kills processes, nukes all caches (app + widget + chrono + LaunchServices), unregisters the plugin, installs, re-registers and launches.

macOS aggressively caches widget extensions (binary, timeline, rendering). The nuke is **mandatory** otherwise old code stays in memory.

```bash
# Build
xcodegen generate && \
plutil -insert NSExtension -json '{"NSExtensionPointIdentifier":"com.apple.widgetkit-extension"}' TokenEaterWidget/Info.plist 2>/dev/null; \
xcodebuild -project TokenEater.xcodeproj -scheme TokenEaterApp -configuration Release -derivedDataPath build -allowProvisioningUpdates DEVELOPMENT_TEAM=S7B8M9JYF4 build 2>&1 | tail -3 && \
\
# Nuke: kill processes + caches + plugin
killall TokenEater 2>/dev/null; killall NotificationCenter 2>/dev/null; killall chronod 2>/dev/null; \
rm -rf ~/Library/Application\ Support/com.tokeneater.shared && \
rm -rf ~/Library/Application\ Support/com.claudeusagewidget.shared && \
rm -rf ~/Library/Group\ Containers/group.com.claudeusagewidget.shared && \
rm -rf /private/var/folders/d6/*/0/com.apple.chrono 2>/dev/null; \
rm -rf /private/var/folders/d6/*/T/com.apple.chrono 2>/dev/null; \
rm -rf /private/var/folders/d6/*/C/com.apple.chrono 2>/dev/null; \
rm -rf /private/var/folders/d6/*/C/com.tokeneater.app 2>/dev/null; \
rm -rf /private/var/folders/d6/*/C/com.claudeusagewidget.app 2>/dev/null; \
pluginkit -r -i com.tokeneater.app.widget 2>/dev/null; \
pluginkit -r -i com.claudeusagewidget.app.widget 2>/dev/null; \
\
# Install + register + launch
sleep 2 && \
rm -rf /Applications/TokenEater.app && \
cp -R build/Build/Products/Release/TokenEater.app /Applications/ && \
xattr -cr /Applications/TokenEater.app && \
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R /Applications/TokenEater.app && \
sleep 2 && \
open /Applications/TokenEater.app
```

#### What the nuke does (why each step is necessary)

| Step | Why |
|------|-----|
| `killall TokenEater/NotificationCenter/chronod` | The app and widget daemons keep the old binary in memory |
| `rm -rf ~/Library/Application Support/com.tokeneater.shared` | Deletes the shared JSON (token + usage cache) — starts fresh |
| `rm -rf ~/Library/Application Support/com.claudeusagewidget.shared` | Deletes the old shared directory (migration) |
| `rm -rf ~/Library/Group Containers/...` | Old group container (no longer used but may remain) |
| `rm -rf /private/var/folders/.../com.apple.chrono` | **Most important**: macOS WidgetKit caches (timeline, rendering, widget binary). Without this, macOS keeps using the old widget |
| `pluginkit -r` | Unregisters the widget extension so macOS doesn't keep the old one in memory |
| `lsregister -f -R` | Forces LaunchServices to re-scan the .app (otherwise macOS may keep old version metadata) |

**After install**: remove the old widget from the desktop and add a new one (right-click → Edit Widgets → TokenEater).

## Architecture

The codebase follows **MV Pattern + Repository Pattern + Protocol-Oriented Design** with `ObservableObject` + `@Published`:

### Layers
- **Models** (`Shared/Models/`): Pure Codable structs (UsageResponse, ThemeColors, ProxyConfig, MetricModels, PacingModels)
- **Services** (`Shared/Services/`): Single-responsibility I/O with protocol-based design (APIClient, KeychainService, SharedFileService, NotificationService)
- **Repository** (`Shared/Repositories/`): Orchestrates the Keychain → API → SharedFile pipeline
- **Stores** (`Shared/Stores/`): `ObservableObject` state containers injected via `@EnvironmentObject` (UsageStore, ThemeStore, SettingsStore)
- **Helpers** (`Shared/Helpers/`): Pure functions (PacingCalculator, MenuBarRenderer)

### Key Patterns
- **No singletons** — all dependencies are injected
- **@EnvironmentObject DI** — stores are passed via `.environmentObject()` SwiftUI
- **Protocol-based services** — each service has a protocol for testability
- **Strategy pattern for themes** — ThemeColors presets + custom theme support

### App/Widget Sharing
- **Main app** (sandboxed): reads the OAuth token from the Claude Code Keychain, calls the API, writes data to `~/Library/Application Support/com.tokeneater.shared/shared.json`
- **Widget** (sandboxed, read-only): reads the shared JSON file via `SharedFileService`, displays the data. Does not touch Keychain or network.
- Sharing uses `temporary-exception` entitlements (no App Groups — incompatible with free Apple Developer accounts on macOS Sequoia)
- Auto-migration from the old `com.claudeusagewidget.shared/` path — migration code kept indefinitely for late updates via Homebrew Cask

## SwiftUI Rules — Do Not Break

Hard-learned lessons. Each rule caused a production bug.

### App struct

- **NO `@StateObject` in the `App` struct** — use `private let` for stores. `@StateObject` forces `App.body` to re-evaluate on every `objectWillChange` from any store, cascading through the entire view tree. Stores are injected via `.environmentObject()`, child views observe them individually.
- Use `@AppStorage` for bindings needed at the App level (e.g., `isInserted` for `MenuBarExtra`), not a binding to a store.

### Bindings

- **NO binding to computed properties** — `$store.computedProp` creates an unstable `LocationProjection` that AttributeGraph can never memoize → infinite loop. Use local `@State` + `.onChange` to synchronize.
- **NO `Binding(get:set:)`** — closures are not `Equatable`, AG always sees "different" → infinite re-evaluation. Same solution: `@State` + `.onChange`.

### Keychain

- **Always use `readOAuthTokenSilently()` (`kSecUseAuthenticationUISkip`)** for automatic reads (refresh, recovery, popover open). Interactive reading (`readOAuthToken()`) is reserved **only** for the first connect during onboarding.
- Never add a new call site for `syncKeychainToken()` (interactive) — use `syncKeychainTokenSilently()`.

### Observation Framework

- **NO `@Observable`** — see dedicated section below.
- **NO `@Bindable`** — use `$store.property` via `@EnvironmentObject`.
- **NO `@Environment(Store.self)`** — use `@EnvironmentObject var store: Store`.

### Release Build Precautions

- SwiftUI bugs manifest **only in Release** (compiler optimizations + no AnyView wrapping). Always test in Release with `DEVELOPER_DIR` pointing to Xcode 16.4 before validating a SwiftUI fix.
- `SWIFT_ENABLE_OPAQUE_TYPE_ERASURE` (Xcode 16+) wraps views in `AnyView` in Debug, masking view identity issues.

## Technical Notes

- `UserDefaults(suiteName:)` does NOT work for app/widget sharing with a free Apple account (Personal Team) — `cfprefsd` checks the provisioning profile
- `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` returns a URL on macOS even without valid provisioning, but the sandbox blocks access on the widget side
- `FileManager.default.homeDirectoryForCurrentUser` returns the sandbox container path, not the real home — use `getpwuid(getuid())` for the real path
- WidgetKit requires `app-sandbox: true` — a widget without sandbox does not display

### @Observable Prohibited

**DO NOT use `@Observable`** (Swift 5.9 Observation framework). The project uses `ObservableObject` + `@Published` exclusively.

Reason: `@Observable` causes a 100% CPU freeze (infinite SwiftUI re-evaluation loop) in Release builds compiled with Swift 6.1.x (Xcode 16.4, used by CI `macos-15`). The bug does NOT reproduce in Debug or with Swift 6.2+ (Xcode 26+), making it impossible to diagnose locally without the right toolchain.

Pattern to use:
- `class Store: ObservableObject` (not `@Observable`)
- `@Published var property` (not a bare property)
- `@EnvironmentObject var store: Store` (not `@Environment(Store.self)`)
- `.environmentObject(store)` (not `.environment(store)`)
- `private let store = Store()` in the App struct (not `@StateObject` or `@State`)
- `@ObservedObject` for sub-views that receive a store
- `$store.property` for bindings (not `@Bindable`)

### Iso-Prod Test (mega nuke)

To test locally a binary **identical to what brew cask delivers**, use the `test-build.yml` workflow:
```bash
gh workflow run test-build.yml -f branch=<branch>
# Wait for completion, then download the DMG:
gh run download <run-id> -n TokenEater-test -D /tmp/tokeneater-test/
```

Before installing the DMG, perform a mega nuke (includes UserDefaults + sandbox containers — the standard nuke is not enough):
```bash
killall TokenEater NotificationCenter chronod cfprefsd 2>/dev/null; sleep 1
defaults delete com.tokeneater.app 2>/dev/null
defaults delete com.claudeusagewidget.app 2>/dev/null
rm -f ~/Library/Preferences/com.tokeneater.app.plist ~/Library/Preferences/com.claudeusagewidget.app.plist
for c in com.tokeneater.app com.tokeneater.app.widget com.claudeusagewidget.app com.claudeusagewidget.app.widget; do
    d="$HOME/Library/Containers/$c/Data"; [ -d "$d" ] && rm -rf "$d/Library/Preferences/"* "$d/Library/Caches/"* "$d/Library/Application Support/"* "$d/tmp/"* 2>/dev/null
done
rm -rf ~/Library/Application\ Support/com.tokeneater.shared ~/Library/Caches/com.tokeneater.app
rm -rf /Applications/TokenEater.app
# Then: mount DMG, copy .app, xattr -cr, lsregister, launch manually
```

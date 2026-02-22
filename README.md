<p align="center">
  <img src="ClaudeUsageApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="TokenEater">
</p>

<h1 align="center">TokenEater</h1>

<p align="center">
  <strong>Monitor your Claude AI usage limits directly from your macOS desktop.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-111?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/WidgetKit-native-007AFF?logo=apple&logoColor=white" alt="WidgetKit">
  <img src="https://img.shields.io/badge/Claude-Pro%20%2F%20Team-D97706" alt="Claude Pro / Team">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/github/v/release/AThevon/TokenEater?color=F97316" alt="Release">
</p>

---

> **Requires a Claude Pro or Team plan.** The free plan does not expose usage data.

## What is TokenEater?

A native macOS widget + menu bar app that displays your Claude (Anthropic) usage in real-time:

- **Session (5h)** — Sliding window with countdown to reset
- **Weekly — All models** — Opus, Sonnet & Haiku combined
- **Weekly — Sonnet** — Dedicated Sonnet limit
- **Pacing** — Are you burning through your quota or cruising? Delta display with 3 zones (chill / on track / hot)

### Desktop Widgets

Three widget options:
- **Usage Medium** — Circular gauges for session, weekly, and pacing
- **Usage Large** — Progress bars with full details for all metrics
- **Pacing** — Dedicated small widget with circular gauge and ideal marker

### Menu Bar

Live usage percentages directly in your menu bar — choose which metrics to pin (session, weekly, sonnet, pacing). Click to see a detailed popover with progress bars, pacing delta, and quick actions.

Color-coded: green when you're comfortable, orange when usage climbs, red when approaching the limit.

### Notifications

Automatic alerts when usage crosses thresholds:
- **60%** — Warning to slow down
- **85%** — Critical usage alert
- **Reset** — Back in the green notification

### Authentication

Two authentication methods, auto-detected in order of priority:

1. **Claude Code OAuth** (recommended) — Reads the OAuth token from Claude Code's Keychain entry. Zero configuration needed if you have Claude Code installed.
2. **Browser cookies** — Auto-import from Chrome, Arc, Brave, or Edge. Or paste manually.

### SOCKS5 Proxy

For users behind a corporate firewall, TokenEater supports routing API calls through a SOCKS5 proxy (e.g. `ssh -D 1080 user@bastion`). Configure in Settings > Proxy.

### Localization

Fully localized in **English** and **French**. The app automatically follows your macOS system language.

## Quick Install

### Download

1. Go to [**Releases**](../../releases/latest) and download `TokenEater.dmg`
2. Open the DMG, drag `TokenEater.app` into `Applications`
3. **Important** — the app is not notarized by Apple. Before the first launch, run:
   ```bash
   xattr -cr /Applications/TokenEater.app
   ```
4. Open `TokenEater.app` from Applications

### Configure

**Claude Code (automatic):**

If you have [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated, TokenEater detects it automatically. Just click **Connect** and you're done.

**Auto-import from browser:**

1. Open TokenEater, click **Connect**
2. If no OAuth token is found, it falls back to browser cookie detection
3. Select your Chromium browser if prompted, authorize Keychain access — done!

**Manual setup:**

1. Open **claude.ai** in your browser and log in
2. Open DevTools (`Cmd + Option + I`) > **Application** > **Cookies** > **claude.ai**
3. Copy the **sessionKey** cookie (`sk-ant-sid01-...`)
4. Copy the **lastActiveOrg** cookie (this is your Organization ID)
5. Paste both values in the TokenEater settings window

Then: **right-click on desktop > Edit Widgets > search "TokenEater"**

> Cookies expire roughly every month. If the widget shows an error, re-import or update them. OAuth tokens from Claude Code are refreshed automatically.

## Build from source

### Requirements

- macOS 13 (Ventura) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Steps

```bash
git clone https://github.com/AThevon/TokenEater.git
cd TokenEater

# Generate Xcode project
xcodegen generate

# ⚠️ XcodeGen strips NSExtension from the widget Info.plist.
# Re-add it manually or run:
plutil -insert NSExtension -json '{"NSExtensionPointIdentifier":"com.apple.widgetkit-extension"}' \
  ClaudeUsageWidget/Info.plist 2>/dev/null || true

# Build
xcodebuild -project ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageApp \
  -configuration Release \
  -derivedDataPath build build

# Install
cp -R "build/Build/Products/Release/TokenEater.app" /Applications/
killall NotificationCenter 2>/dev/null
open "/Applications/TokenEater.app"
```

## Supported Browsers

Auto-import works with any Chromium-based browser:

| Browser | Status |
|---------|--------|
| Google Chrome | ✓ |
| Arc | ✓ |
| Brave | ✓ |
| Microsoft Edge | ✓ |
| Chromium | ✓ |

Supports both legacy and modern (v130+) Chrome cookie encryption formats.

## Architecture

```
ClaudeUsageApp/          App host (settings UI, OAuth/cookie auth, menu bar)
ClaudeUsageWidget/       Widget Extension (WidgetKit, 15-min refresh)
Shared/                  Shared code (API client, models, pacing, notifications)
  ├── en.lproj/          English strings
  └── fr.lproj/          French strings
project.yml              XcodeGen configuration
```

The host app writes configuration to the widget extension's sandbox container. The widget reads from its own container. No App Groups required. The menu bar refreshes every 5 minutes independently.

## How it works

TokenEater supports two API endpoints:

**OAuth (Claude Code):**
```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <token>
anthropic-beta: oauth-2025-04-20
```

**Cookies (browser):**
```
GET https://claude.ai/api/organizations/{org_id}/usage
Cookie: sessionKey=sk-ant-sid01-...
```

The response includes `utilization` (0–100) and `resets_at` for each limit bucket. The widget refreshes every 15 minutes (WidgetKit minimum) and caches the last successful response for offline display. If cookies expire, the client automatically falls back to OAuth if available.

## License

MIT — do whatever you want with it.

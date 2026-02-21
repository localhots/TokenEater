<p align="center">
  <img src="ClaudeUsageApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="TokenEater">
</p>

<h1 align="center">TokenEater</h1>

<p align="center">
  <strong>Monitor your Claude AI usage limits directly from your macOS desktop.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-111?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/WidgetKit-native-007AFF?logo=apple&logoColor=white" alt="WidgetKit">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/github/v/release/AThevon/TokenEater?color=F97316" alt="Release">
</p>

---

## What is TokenEater?

A native macOS widget that displays your Claude (Anthropic) usage in real-time:

- **Session (5h)** — Sliding window with countdown to reset
- **Weekly — All models** — Opus, Sonnet & Haiku combined
- **Weekly — Sonnet** — Dedicated Sonnet limit

Two widget sizes available: **medium** (circular gauges) and **large** (progress bars).

Color-coded: green when you're comfortable, orange when usage climbs, red when approaching the limit.

## Quick Install

### Download the binary

1. Go to [**Releases**](../../releases/latest) and download `TokenEater.zip`
2. Unzip and move `TokenEater.app` to `/Applications`
3. First launch: **right-click > Open** (required once — the app is not notarized)
4. Or run in terminal: `xattr -cr /Applications/TokenEater.app && open /Applications/TokenEater.app`

### Configure

1. Open **claude.ai** in your browser and log in
2. Open DevTools (`Cmd + Option + I`) > **Application** > **Cookies** > **claude.ai**
3. Copy the **sessionKey** cookie (`sk-ant-sid01-...`)
4. Copy the **lastActiveOrg** cookie (this is your Organization ID)
5. Paste both values in the TokenEater settings window
6. Add the widget: **right-click on desktop > Edit Widgets > search "TokenEater"**

> Cookies expire roughly every month. If the widget shows an error, update them in the app.

## Build from source

### Requirements

- macOS 14 (Sonoma) or later
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

## Architecture

```
ClaudeUsageApp/          App host (settings UI, hidden from Dock)
ClaudeUsageWidget/       Widget Extension (WidgetKit, 15-min refresh)
Shared/                  Shared code (API client, models, extensions)
project.yml              XcodeGen configuration
```

The host app writes configuration to the widget extension's sandbox container. The widget reads from its own container. No App Groups required.

## How it works

TokenEater calls the Claude usage API:

```
GET https://claude.ai/api/organizations/{org_id}/usage
Cookie: sessionKey=sk-ant-sid01-...
```

The response includes `utilization` (0–100) and `resets_at` for each limit bucket. The widget refreshes every 15 minutes (WidgetKit minimum) and caches the last successful response for offline display.

## License

MIT — do whatever you want with it.

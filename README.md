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

A native macOS widget + menu bar app that displays your Claude (Anthropic) usage in real-time:

- **Session (5h)** — Sliding window with countdown to reset
- **Weekly — All models** — Opus, Sonnet & Haiku combined
- **Weekly — Sonnet** — Dedicated Sonnet limit

### Desktop Widget
Two widget sizes available: **medium** (circular gauges) and **large** (progress bars).

### Menu Bar
Live usage percentages directly in your menu bar — choose which metrics to display. Click to see a detailed popover with all three metrics, progress bars, and quick actions.

Color-coded: green when you're comfortable, orange when usage climbs, red when approaching the limit.

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

**Auto-import (recommended):**

1. Open TokenEater, click **Import from browser**
2. Select your Chromium browser (Chrome, Arc, Brave, Edge)
3. Authorize Keychain access when prompted — done!

**Manual setup:**

1. Open **claude.ai** in your browser and log in
2. Open DevTools (`Cmd + Option + I`) > **Application** > **Cookies** > **claude.ai**
3. Copy the **sessionKey** cookie (`sk-ant-sid01-...`)
4. Copy the **lastActiveOrg** cookie (this is your Organization ID)
5. Paste both values in the TokenEater settings window

Then: **right-click on desktop > Edit Widgets > search "TokenEater"**

> Cookies expire roughly every month. If the widget shows an error, re-import or update them manually.

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
ClaudeUsageApp/          App host (settings UI, cookie import, menu bar)
ClaudeUsageWidget/       Widget Extension (WidgetKit, 15-min refresh)
Shared/                  Shared code (API client, models, localization)
  ├── en.lproj/          English strings
  └── fr.lproj/          French strings
project.yml              XcodeGen configuration
```

The host app writes configuration to the widget extension's sandbox container. The widget reads from its own container. No App Groups required. The menu bar refreshes every 5 minutes independently.

## How it works

TokenEater calls the Claude usage API:

```
GET https://claude.ai/api/organizations/{org_id}/usage
Cookie: sessionKey=sk-ant-sid01-...
```

The response includes `utilization` (0–100) and `resets_at` for each limit bucket. The widget refreshes every 15 minutes (WidgetKit minimum) and caches the last successful response for offline display.

## License

MIT — do whatever you want with it.

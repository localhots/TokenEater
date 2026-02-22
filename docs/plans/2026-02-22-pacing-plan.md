# Pacing Intelligent Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "pacing" feature that compares real weekly usage to ideal linear consumption, displayed in menu bar, popover, and a dedicated small widget.

**Architecture:** A shared `PacingCalculator` computes delta from `seven_day` bucket data. Menu bar gains a new pinnable `pacing` metric (dot and/or delta). Popover gets a pacing section with progress bar + ideal marker. A new `.systemSmall` widget shows pacing with a split bar.

**Tech Stack:** Swift 5.9, SwiftUI, WidgetKit, macOS 14+

---

### Task 1: Add PacingCalculator to Shared

**Files:**
- Create: `Shared/PacingCalculator.swift`

**Step 1: Create the calculator**

```swift
import Foundation

enum PacingZone: String {
    case chill
    case onTrack
    case hot
}

struct PacingResult {
    let delta: Double
    let expectedUsage: Double
    let actualUsage: Double
    let zone: PacingZone
    let message: String
    let resetDate: Date?
}

enum PacingCalculator {
    private static let chillMessages = [
        "pacing.chill.1", "pacing.chill.2", "pacing.chill.3",
    ]
    private static let onTrackMessages = [
        "pacing.ontrack.1", "pacing.ontrack.2", "pacing.ontrack.3",
    ]
    private static let hotMessages = [
        "pacing.hot.1", "pacing.hot.2", "pacing.hot.3",
    ]

    static func calculate(from usage: UsageResponse, now: Date = Date()) -> PacingResult? {
        guard let bucket = usage.sevenDay,
              let resetsAt = bucket.resetsAtDate
        else { return nil }

        let totalDuration: TimeInterval = 7 * 24 * 3600 // 7 days
        let startOfPeriod = resetsAt.addingTimeInterval(-totalDuration)
        let elapsed = now.timeIntervalSince(startOfPeriod) / totalDuration
        let clampedElapsed = min(max(elapsed, 0), 1)

        let expectedUsage = clampedElapsed * 100
        let delta = bucket.utilization - expectedUsage

        let zone: PacingZone
        let messages: [String]
        if delta < -10 {
            zone = .chill
            messages = chillMessages
        } else if delta > 10 {
            zone = .hot
            messages = hotMessages
        } else {
            zone = .onTrack
            messages = onTrackMessages
        }

        let messageKey = messages.randomElement() ?? messages[0]
        let message = String(localized: String.LocalizationValue(messageKey))

        return PacingResult(
            delta: delta,
            expectedUsage: expectedUsage,
            actualUsage: bucket.utilization,
            zone: zone,
            message: message,
            resetDate: resetsAt
        )
    }
}
```

**Step 2: Add localization keys**

In `Shared/en.lproj/Localizable.strings`, add:

```
/* Pacing */
"pacing.chill.1" = "Plenty of room";
"pacing.chill.2" = "Claude's waiting, go wild";
"pacing.chill.3" = "Cruise mode on";
"pacing.ontrack.1" = "Right on pace";
"pacing.ontrack.2" = "Steady as she goes";
"pacing.ontrack.3" = "You're on track";
"pacing.hot.1" = "Easy there cowboy";
"pacing.hot.2" = "Burning through it";
"pacing.hot.3" = "Slow down";
"pacing.label" = "Pacing";
"pacing.reset" = "reset %@";
```

In `Shared/fr.lproj/Localizable.strings`, add:

```
/* Pacing */
"pacing.chill.1" = "Tranquille, t'as du stock";
"pacing.chill.2" = "Claude t'attend, envoie du lourd";
"pacing.chill.3" = "Mode cruise active";
"pacing.ontrack.1" = "Pile dans le rythme";
"pacing.ontrack.2" = "Steady as she goes";
"pacing.ontrack.3" = "Tu geres";
"pacing.hot.1" = "Doucement cowboy";
"pacing.hot.2" = "Tu flambes";
"pacing.hot.3" = "Leve le pied";
"pacing.label" = "Pacing";
"pacing.reset" = "reset %@";
```

**Step 3: Commit**

```bash
git add Shared/PacingCalculator.swift Shared/en.lproj/Localizable.strings Shared/fr.lproj/Localizable.strings
git commit -m "feat: add PacingCalculator with fun localized messages"
```

---

### Task 2: Add pacing metric to menu bar

**Files:**
- Modify: `ClaudeUsageApp/MenuBarView.swift`

**Step 1: Add pacing case to MetricID**

In `MetricID` enum, add the new case and update computed properties:

```swift
enum MetricID: String, CaseIterable {
    case fiveHour = "fiveHour"
    case sevenDay = "sevenDay"
    case sonnet = "sonnet"
    case pacing = "pacing"

    var label: String {
        switch self {
        case .fiveHour: return String(localized: "metric.session")
        case .sevenDay: return String(localized: "metric.weekly")
        case .sonnet: return String(localized: "metric.sonnet")
        case .pacing: return String(localized: "pacing.label")
        }
    }

    var shortLabel: String {
        switch self {
        case .fiveHour: return "5h"
        case .sevenDay: return "7d"
        case .sonnet: return "S"
        case .pacing: return "P"
        }
    }
}
```

**Step 2: Add pacing state to MenuBarViewModel**

Add to the published properties:

```swift
@Published var pacingDelta: Int = 0
@Published var pacingZone: PacingZone = .onTrack
```

Update `pct(for:)`:

```swift
func pct(for metric: MetricID) -> Int {
    switch metric {
    case .fiveHour: return fiveHourPct
    case .sevenDay: return sevenDayPct
    case .sonnet: return sonnetPct
    case .pacing: return pacingDelta
    }
}
```

In `update(from:)`, add at the end:

```swift
if let pacing = PacingCalculator.calculate(from: usage) {
    pacingDelta = Int(pacing.delta)
    pacingZone = pacing.zone
}
```

**Step 3: Add pacing display mode**

Add a UserDefaults key for the display mode. In `MenuBarViewModel`:

```swift
enum PacingDisplayMode: String {
    case dot
    case dotDelta
}

var pacingDisplayMode: PacingDisplayMode {
    PacingDisplayMode(rawValue: UserDefaults.standard.string(forKey: "pacingDisplayMode") ?? "dotDelta") ?? .dotDelta
}
```

**Step 4: Update renderPinnedMetrics() for pacing**

In `renderPinnedMetrics()`, update the rendering loop to handle pacing specially:

```swift
let ordered: [MetricID] = [.fiveHour, .sevenDay, .sonnet, .pacing].filter { pinnedMetrics.contains($0) }
for (i, metric) in ordered.enumerated() {
    if i > 0 {
        str.append(NSAttributedString(string: "  ", attributes: sepAttrs))
    }
    if metric == .pacing {
        let dotColor = nsColorForZone(pacingZone)
        let dotAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: dotColor,
        ]
        str.append(NSAttributedString(string: "\u{25CF}", attributes: dotAttrs))
        if pacingDisplayMode == .dotDelta {
            let sign = pacingDelta >= 0 ? "+" : ""
            let deltaAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold),
                .foregroundColor: dotColor,
            ]
            str.append(NSAttributedString(string: " \(sign)\(pacingDelta)%", attributes: deltaAttrs))
        }
    } else {
        let value = pct(for: metric)
        str.append(NSAttributedString(string: "\(metric.shortLabel) ", attributes: labelAttrs))
        str.append(NSAttributedString(string: "\(value)%", attributes: pctAttrs(value)))
    }
}
```

Add helper:

```swift
private func nsColorForZone(_ zone: PacingZone) -> NSColor {
    switch zone {
    case .chill: return NSColor(red: 0.13, green: 0.77, blue: 0.29, alpha: 1)
    case .onTrack: return NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1)
    case .hot: return NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
    }
}
```

**Step 5: Commit**

```bash
git add ClaudeUsageApp/MenuBarView.swift
git commit -m "feat: pacing metric in menu bar with dot and delta display"
```

---

### Task 3: Add pacing section to popover

**Files:**
- Modify: `ClaudeUsageApp/MenuBarView.swift`

**Step 1: Add pacing state for popover**

Add to `MenuBarViewModel`:

```swift
@Published var pacingResult: PacingResult?
```

Update `update(from:)` to also set:

```swift
pacingResult = PacingCalculator.calculate(from: usage)
```

**Step 2: Add pacing section view to MenuBarPopoverView**

Add after the metrics VStack and before the last-update text, a new pacing section:

```swift
if let pacing = viewModel.pacingResult {
    Divider()
        .overlay(Color.white.opacity(0.08))
        .padding(.top, 8)

    VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.toggleMetric(.pacing)
                }
            } label: {
                Image(systemName: viewModel.pinnedMetrics.contains(.pacing) ? "menubar.rectangle" : "menubar.dock.rectangle")
                    .font(.system(size: 9))
                    .foregroundStyle(viewModel.pinnedMetrics.contains(.pacing) ? colorForZone(pacing.zone) : .white.opacity(0.2))
            }
            .buttonStyle(.plain)

            Text(String(localized: "pacing.label"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            let sign = pacing.delta >= 0 ? "+" : ""
            Text("\(sign)\(Int(pacing.delta))%")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(colorForZone(pacing.zone))
        }

        // Progress bar with ideal marker
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(gradientForZone(pacing.zone))
                    .frame(width: max(0, geo.size.width * CGFloat(min(pacing.actualUsage, 100)) / 100), height: 4)

                // Ideal marker
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 2, height: 10)
                    .offset(x: geo.size.width * CGFloat(min(pacing.expectedUsage, 100)) / 100 - 1)
            }
        }
        .frame(height: 10)

        Text(pacing.message)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(colorForZone(pacing.zone).opacity(0.8))
    }
    .padding(.horizontal, 16)
    .padding(.top, 6)
}
```

Add helpers to `MenuBarPopoverView`:

```swift
private func colorForZone(_ zone: PacingZone) -> Color {
    switch zone {
    case .chill: return Color(red: 0.13, green: 0.77, blue: 0.29)
    case .onTrack: return Color(red: 0.04, green: 0.52, blue: 1.0)
    case .hot: return Color(red: 0.94, green: 0.27, blue: 0.27)
    }
}

private func gradientForZone(_ zone: PacingZone) -> LinearGradient {
    switch zone {
    case .chill:
        return LinearGradient(colors: [Color(red: 0.13, green: 0.77, blue: 0.29), Color(red: 0.29, green: 0.87, blue: 0.50)], startPoint: .leading, endPoint: .trailing)
    case .onTrack:
        return LinearGradient(colors: [Color(red: 0.04, green: 0.52, blue: 1.0), Color(red: 0.25, green: 0.61, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
    case .hot:
        return LinearGradient(colors: [Color(red: 0.94, green: 0.27, blue: 0.27), Color(red: 0.86, green: 0.15, blue: 0.15)], startPoint: .leading, endPoint: .trailing)
    }
}
```

**Step 3: Commit**

```bash
git add ClaudeUsageApp/MenuBarView.swift
git commit -m "feat: pacing section in popover with progress bar and ideal marker"
```

---

### Task 4: Add small pacing widget

**Files:**
- Create: `ClaudeUsageWidget/PacingWidgetView.swift`
- Modify: `ClaudeUsageWidget/ClaudeUsageWidget.swift`

**Step 1: Create PacingWidgetView**

```swift
import SwiftUI
import WidgetKit

struct PacingWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        Group {
            if let usage = entry.usage, let pacing = PacingCalculator.calculate(from: usage) {
                pacingContent(pacing)
            } else {
                placeholderContent
            }
        }
        .containerBackground(for: .widget) {
            Color.black.opacity(0.85)
        }
    }

    private func pacingContent(_ pacing: PacingResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Circle()
                    .fill(colorForZone(pacing.zone))
                    .frame(width: 6, height: 6)
                Text("Pacing")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.3)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            .padding(.bottom, 10)

            // Delta
            let sign = pacing.delta >= 0 ? "+" : ""
            Text("\(sign)\(Int(pacing.delta))%")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(colorForZone(pacing.zone))
                .padding(.bottom, 4)

            // Progress bar with ideal marker
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(gradientForZone(pacing.zone))
                        .frame(width: max(0, geo.size.width * CGFloat(min(pacing.actualUsage, 100)) / 100), height: 5)

                    // Ideal marker
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 2, height: 11)
                        .offset(x: geo.size.width * CGFloat(min(pacing.expectedUsage, 100)) / 100 - 1)
                }
            }
            .frame(height: 11)
            .padding(.bottom, 8)

            // Message
            Text(pacing.message)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(colorForZone(pacing.zone).opacity(0.9))
                .lineLimit(1)

            Spacer(minLength: 0)

            // Reset countdown
            if let reset = pacing.resetDate {
                Text(String(format: String(localized: "pacing.reset"), formatResetDate(reset)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private var placeholderContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "gauge.with.needle")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.3))
            Text("widget.loading")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func colorForZone(_ zone: PacingZone) -> Color {
        switch zone {
        case .chill: return Color(hex: "#32D74B")
        case .onTrack: return Color(hex: "#0A84FF")
        case .hot: return Color(hex: "#FF453A")
        }
    }

    private func gradientForZone(_ zone: PacingZone) -> LinearGradient {
        switch zone {
        case .chill:
            return LinearGradient(colors: [Color(hex: "#22C55E"), Color(hex: "#4ADE80")], startPoint: .leading, endPoint: .trailing)
        case .onTrack:
            return LinearGradient(colors: [Color(hex: "#0A84FF"), Color(hex: "#409CFF")], startPoint: .leading, endPoint: .trailing)
        case .hot:
            return LinearGradient(colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func formatResetDate(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return String(localized: "widget.soon") }
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        if days > 0 {
            return "\(days)j \(hours)h"
        }
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h\(String(format: "%02d", minutes))"
    }
}
```

**Step 2: Register the pacing widget**

In `ClaudeUsageWidget/ClaudeUsageWidget.swift`, add a new widget and register it in the bundle:

```swift
import WidgetKit
import SwiftUI

struct ClaudeUsageWidget: Widget {
    let kind: String = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            UsageWidgetView(entry: entry)
        }
        .configurationDisplayName("TokenEater")
        .description("Affiche votre consommation Claude en temps réel")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct PacingWidget: Widget {
    let kind: String = "PacingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PacingWidgetView(entry: entry)
        }
        .configurationDisplayName("TokenEater Pacing")
        .description("Votre rythme de consommation Claude")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct ClaudeUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClaudeUsageWidget()
        PacingWidget()
    }
}
```

**Step 3: Commit**

```bash
git add ClaudeUsageWidget/PacingWidgetView.swift ClaudeUsageWidget/ClaudeUsageWidget.swift
git commit -m "feat: small pacing widget with split bar and fun messages"
```

---

### Task 5: Update Provider for OAuth and add pacing display mode setting

**Files:**
- Modify: `ClaudeUsageWidget/Provider.swift`

**Step 1: Fix Provider to use resolveAuthMethod**

The widget's `Provider.fetchEntry()` still checks `apiClient.config != nil`. Update it:

```swift
private func fetchEntry() async -> UsageEntry {
    guard apiClient.resolveAuthMethod() != nil else {
        return .unconfigured
    }

    do {
        let usage = try await apiClient.fetchUsage()
        return UsageEntry(date: Date(), usage: usage)
    } catch {
        if let cached = apiClient.loadCachedUsage() {
            return UsageEntry(
                date: Date(),
                usage: cached.usage,
                error: nil,
                isStale: true
            )
        }
        return UsageEntry(date: Date(), usage: nil, error: error.localizedDescription)
    }
}
```

**Step 2: Commit**

```bash
git add ClaudeUsageWidget/Provider.swift
git commit -m "fix: widget provider uses resolveAuthMethod instead of config check"
```

---

### Task 6: Build, test, and push

**Step 1: Regenerate Xcode project**

```bash
xcodegen generate
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

Test checklist:
- Launch app, check menu bar for pacing dot (pin it from popover)
- Verify popover shows pacing section with progress bar + marker + fun message
- Add small pacing widget from widget picker
- Verify widget shows delta, progress bar, message, reset countdown
- Verify colors change based on zone (chill/onTrack/hot)

**Step 4: Commit and push**

```bash
git add -A
git commit -m "feat: pacing intelligent — menu bar, popover, and small widget"
git push
```

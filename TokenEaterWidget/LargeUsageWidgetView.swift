import SwiftUI

// MARK: - Large Widget View

struct LargeUsageWidgetView: View {
    let entry: UsageEntry
    let usage: UsageResponse
    private var theme: ThemeColors { SharedFileService().theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(alignment: .center) {
                Text(String(localized: "widget.header"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: theme.widgetText))
                Spacer()
                if entry.isStale {
                    HStack(spacing: 3) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 11))
                        Text("widget.offline")
                            .font(.system(size: 11, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: theme.widgetText))
                }
            }

            // Session (5h)
            if let fiveHour = usage.fiveHour {
                LargeUsageBarView(
                    label: String(localized: "widget.session"),
                    subtitle: String(localized: "widget.session.subtitle"),
                    resetInfo: fiveHour.resetsAtDate.widgetResetTimeFormatted,
                    utilization: fiveHour.utilization
                )
            }

            // Weekly — All models
            if let sevenDay = usage.sevenDay {
                LargeUsageBarView(
                    label: String(localized: "widget.weekly.full"),
                    subtitle: String(localized: "widget.weekly.subtitle"),
                    resetInfo: sevenDay.resetsAtDate.widgetResetDateFormatted,
                    utilization: sevenDay.utilization
                )
            }

            // Weekly — Sonnet
            if let sonnet = usage.sevenDaySonnet {
                LargeUsageBarView(
                    label: String(localized: "widget.sonnet"),
                    subtitle: String(localized: "widget.sonnet.subtitle"),
                    resetInfo: sonnet.resetsAtDate.widgetResetDateFormatted,
                    utilization: sonnet.utilization
                )
            }

            // Pacing
            if let pacing = PacingCalculator.calculate(from: usage) {
                LargeUsageBarView(
                    label: String(localized: "pacing.label"),
                    subtitle: pacing.message,
                    resetInfo: {
                        guard let r = pacing.resetDate, r.timeIntervalSinceNow > 0 else { return "" }
                        let d = Int(r.timeIntervalSinceNow) / 86400
                        let h = (Int(r.timeIntervalSinceNow) % 86400) / 3600
                        return d > 0 ? String(format: String(localized: "duration.days.hours"), d, h) : "\(h)h"
                    }(),
                    utilization: pacing.actualUsage,
                    colorOverride: theme.pacingColor(for: pacing.zone),
                    displayText: "\(pacing.delta >= 0 ? "+" : "")\(Int(pacing.delta))%"
                )
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Text(String(format: String(localized: "widget.updated"), entry.date.msFormatted))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: theme.widgetText))
                Spacer()
                if entry.isStale {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 13))
                        Text("widget.offline")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(Color(hex: theme.widgetText))
                } else {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text(String(localized: "widget.refresh.interval"))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(hex: theme.widgetText))
                    }
                }
            }
        }
        .padding(4)
    }
}

// MARK: - Large Usage Bar View

struct LargeUsageBarView: View {
    let label: String
    let subtitle: String
    let resetInfo: String
    let utilization: Double
    var colorOverride: Color? = nil
    var displayText: String? = nil
    var theme: ThemeColors = SharedFileService().theme
    var thresholds: UsageThresholds = SharedFileService().thresholds

    private var barGradient: LinearGradient {
        if let color = colorOverride {
            return LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        }
        return theme.gaugeGradient(for: utilization, thresholds: thresholds, startPoint: .leading, endPoint: .trailing)
    }

    private var accentColor: Color {
        if let color = colorOverride { return color }
        return theme.gaugeColor(for: utilization, thresholds: thresholds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: theme.widgetText))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: theme.widgetText))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayText ?? "\(Int(utilization))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accentColor)
                    Text(String(format: String(localized: "widget.reset"), resetInfo))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: theme.widgetText))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barGradient)
                        .frame(width: max(0, geo.size.width * min(utilization, 100) / 100))
                }
            }
            .frame(height: 6)
        }
    }
}

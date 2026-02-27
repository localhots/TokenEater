import SwiftUI
import WidgetKit

// MARK: - Widget Background (macOS 13 compat)

struct WidgetBackgroundModifier: ViewModifier {
    var backgroundColor: Color = Color(hex: SharedFileService().theme.widgetBackground).opacity(0.85)

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.containerBackground(for: .widget) {
                backgroundColor
            }
        } else {
            content.padding().background(backgroundColor)
        }
    }
}

// MARK: - Main Widget View

struct UsageWidgetView: View {
    let entry: UsageEntry

    @Environment(\.widgetFamily) var family
    private var theme: ThemeColors { SharedFileService().theme }
    private var thresholds: UsageThresholds { SharedFileService().thresholds }

    var body: some View {
        Group {
            if let error = entry.error, entry.usage == nil {
                errorView(error)
            } else if let usage = entry.usage {
                switch family {
                case .systemLarge:
                    largeUsageContent(usage)
                default:
                    mediumUsageContent(usage)
                }
            } else {
                placeholderView
            }
        }
        .modifier(WidgetBackgroundModifier())
    }

    // MARK: - Medium: Circular Charts

    private func mediumUsageContent(_ usage: UsageResponse) -> some View {
        VStack(spacing: 0) {
            // Header
            Text(String(localized: "widget.header"))
                .font(.system(size: 13, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(Color(hex: theme.widgetText))
                .padding(.bottom, 16)

            // Circular gauges
            HStack(spacing: 0) {
                if let fiveHour = usage.fiveHour {
                    CircularUsageView(
                        label: String(localized: "widget.session"),
                        resetInfo: formatResetTime(fiveHour.resetsAtDate),
                        utilization: fiveHour.utilization
                    )
                }
                if let sevenDay = usage.sevenDay {
                    CircularUsageView(
                        label: String(localized: "widget.weekly"),
                        resetInfo: formatResetDate(sevenDay.resetsAtDate),  
                        utilization: sevenDay.utilization
                    )
                }
                if let pacing = PacingCalculator.calculate(from: usage) {
                    CircularPacingView(pacing: pacing)
                }
            }

            Spacer(minLength: 6)

            // Footer
            HStack {
                Text(String(format: String(localized: "widget.updated"), entry.date.relativeFormatted))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                if entry.isStale {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Large: Expanded View

    private func largeUsageContent(_ usage: UsageResponse) -> some View {
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
                    resetInfo: formatResetTime(fiveHour.resetsAtDate),
                    utilization: fiveHour.utilization
                )
            }

            // Weekly — All models
            if let sevenDay = usage.sevenDay {
                LargeUsageBarView(
                    label: String(localized: "widget.weekly.full"),
                    subtitle: String(localized: "widget.weekly.subtitle"),
                    resetInfo: formatResetDate(sevenDay.resetsAtDate),
                    utilization: sevenDay.utilization
                )
            }

            // Weekly — Sonnet
            if let sonnet = usage.sevenDaySonnet {
                LargeUsageBarView(
                    label: String(localized: "widget.sonnet"),
                    subtitle: String(localized: "widget.sonnet.subtitle"),
                    resetInfo: formatResetDate(sonnet.resetsAtDate),
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

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#F97316"), Color(hex: "#EF4444")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text(message)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color(hex: theme.widgetText))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(.orange)
            Text("widget.loading")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color(hex: theme.widgetText))
        }
    }

    // MARK: - Time Formatting

    private func formatResetTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return String(localized: "widget.soon") }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))"
        } else {
            return "\(minutes) min"
        }
    }

    private func formatResetDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Circular Usage View (Medium widget)

struct CircularUsageView: View {
    let label: String
    let resetInfo: String
    let utilization: Double
    var theme: ThemeColors = SharedFileService().theme
    var thresholds: UsageThresholds = SharedFileService().thresholds

    private var ringGradient: LinearGradient {
        theme.gaugeGradient(for: utilization, thresholds: thresholds)
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 4.5)

                Circle()
                    .trim(from: 0, to: min(utilization, 100) / 100)
                    .stroke(ringGradient, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(utilization))%")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: theme.widgetText))
            }
            .frame(width: 62, height: 62)

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(0.2)
                    .foregroundStyle(Color(hex: theme.widgetText))
                Text(resetInfo)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: theme.widgetText))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Circular Pacing View (Medium widget)

struct CircularPacingView: View {
    let pacing: PacingResult
    var theme: ThemeColors = SharedFileService().theme

    private var ringColor: Color {
        theme.pacingColor(for: pacing.zone)
    }

    private var ringGradient: LinearGradient {
        theme.pacingGradient(for: pacing.zone)
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 4.5)

                Circle()
                    .trim(from: 0, to: min(pacing.actualUsage, 100) / 100)
                    .stroke(ringGradient, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Ideal marker on the ring
                let angle = (min(pacing.expectedUsage, 100) / 100) * 360 - 90
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 4, height: 4)
                    .offset(x: 31 * cos(angle * .pi / 180), y: 31 * sin(angle * .pi / 180))

                let sign = pacing.delta >= 0 ? "+" : ""
                Text("\(sign)\(Int(pacing.delta))%")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ringColor)
            }
            .frame(width: 62, height: 62)

            VStack(spacing: 2) {
                Text("pacing.label")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(0.2)
                    .foregroundStyle(Color(hex: theme.widgetText))
                Text(pacing.message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ringColor)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
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

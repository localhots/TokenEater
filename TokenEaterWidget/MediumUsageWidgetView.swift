import SwiftUI

// MARK: - Medium Widget View

struct MediumUsageWidgetView: View {
    let entry: UsageEntry
    let usage: UsageResponse
    private var theme: ThemeColors { SharedFileService().theme }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 5) {
                Text(String(localized: "widget.header"))
                    .font(.system(size: 13, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(Color(hex: theme.widgetText))
                Spacer()
                if entry.isStale {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: theme.widgetText))
                }
            }
            .padding(.bottom, 16)

            // Circular gauges
            HStack(spacing: 0) {
                if let fiveHour = usage.fiveHour {
                    CircularUsageView(
                        label: String(localized: "widget.session"),
                        resetInfo: fiveHour.resetsAtDate.widgetResetTimeFormatted,
                        utilization: fiveHour.utilization
                    )
                }
                if let sevenDay = usage.sevenDay {
                    CircularUsageView(
                        label: String(localized: "widget.weekly"),
                        resetInfo: sevenDay.resetsAtDate.widgetResetDateFormatted,
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
}

// MARK: - Circular Usage View

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

// MARK: - Circular Pacing View

struct CircularPacingView: View {
    let pacing: PacingResult
    var theme: ThemeColors = SharedFileService().theme

    private var ringColor: Color { theme.pacingColor(for: pacing.zone) }
    private var ringGradient: LinearGradient { theme.pacingGradient(for: pacing.zone) }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 4.5)

                Circle()
                    .trim(from: 0, to: min(pacing.actualUsage, 100) / 100)
                    .stroke(ringGradient, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

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

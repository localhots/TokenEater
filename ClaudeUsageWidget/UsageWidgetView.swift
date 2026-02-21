import SwiftUI
import WidgetKit

// MARK: - Main Widget View

struct UsageWidgetView: View {
    let entry: UsageEntry

    @Environment(\.widgetFamily) var family

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
        .containerBackground(for: .widget) {
            Color.black.opacity(0.85)
        }
    }

    // MARK: - Medium: Circular Charts

    private func mediumUsageContent(_ usage: UsageResponse) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 5) {
                Image("WidgetLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                Text("TokenEater")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.3)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if entry.isStale {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.bottom, 16)

            // Circular gauges
            HStack(spacing: 0) {
                if let fiveHour = usage.fiveHour {
                    CircularUsageView(
                        label: "Session",
                        resetInfo: formatResetTime(fiveHour.resetsAtDate),
                        utilization: fiveHour.utilization
                    )
                }
                if let sevenDay = usage.sevenDay {
                    CircularUsageView(
                        label: "Hebdo",
                        resetInfo: formatResetDate(sevenDay.resetsAtDate),
                        utilization: sevenDay.utilization
                    )
                }
                if let sonnet = usage.sevenDaySonnet {
                    CircularUsageView(
                        label: "Sonnet",
                        resetInfo: formatResetDate(sonnet.resetsAtDate),
                        utilization: sonnet.utilization
                    )
                }
            }

            Spacer(minLength: 6)

            // Footer
            Text("Maj \(entry.date.relativeFormatted)")
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Large: Expanded View

    private func largeUsageContent(_ usage: UsageResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                Image("WidgetLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                Text("TokenEater")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
                if entry.isStale {
                    HStack(spacing: 3) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 9))
                        Text("Hors ligne")
                            .font(.system(size: 9, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.bottom, 18)

            // Session (5h)
            if let fiveHour = usage.fiveHour {
                LargeUsageBarView(
                    icon: "timer",
                    label: "Session",
                    subtitle: "Fenetre glissante 5h",
                    resetInfo: formatResetTime(fiveHour.resetsAtDate),
                    utilization: fiveHour.utilization
                )
            }

            Spacer()

            // Weekly — All models
            if let sevenDay = usage.sevenDay {
                LargeUsageBarView(
                    icon: "chart.bar.fill",
                    label: "Hebdomadaire",
                    subtitle: "Opus + Sonnet + Haiku",
                    resetInfo: formatResetDate(sevenDay.resetsAtDate),
                    utilization: sevenDay.utilization
                )
            }

            Spacer()

            // Weekly — Sonnet
            if let sonnet = usage.sevenDaySonnet {
                LargeUsageBarView(
                    icon: "wand.and.stars",
                    label: "Sonnet",
                    subtitle: "Limite dediee",
                    resetInfo: formatResetDate(sonnet.resetsAtDate),
                    utilization: sonnet.utilization
                )
            }

            Spacer()

            // Footer
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
                .padding(.bottom, 8)

            HStack {
                Text("Maj \(entry.date.relativeFormatted)")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
                HStack(spacing: 3) {
                    Circle()
                        .fill(.green.opacity(0.6))
                        .frame(width: 4, height: 4)
                    Text("15 min")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.25))
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
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(.orange)
            Text("Chargement...")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Time Formatting

    private func formatResetTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "Bientot" }

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
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Circular Usage View (Medium widget)

struct CircularUsageView: View {
    let label: String
    let resetInfo: String
    let utilization: Double

    private var ringGradient: LinearGradient {
        if utilization >= 85 {
            return LinearGradient(
                colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else if utilization >= 60 {
            return LinearGradient(
                colors: [Color(hex: "#F97316"), Color(hex: "#FB923C")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#22C55E"), Color(hex: "#4ADE80")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
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
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.2)
                    .foregroundStyle(.white.opacity(0.85))
                Text(resetInfo)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Large Usage Bar View

struct LargeUsageBarView: View {
    let icon: String
    let label: String
    let subtitle: String
    let resetInfo: String
    let utilization: Double

    private var barGradient: LinearGradient {
        if utilization >= 85 {
            return LinearGradient(
                colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                startPoint: .leading, endPoint: .trailing
            )
        } else if utilization >= 60 {
            return LinearGradient(
                colors: [Color(hex: "#F97316"), Color(hex: "#FB923C")],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#22C55E"), Color(hex: "#4ADE80")],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    private var accentColor: Color {
        if utilization >= 85 {
            return Color(hex: "#EF4444")
        } else if utilization >= 60 {
            return Color(hex: "#F97316")
        } else {
            return Color(hex: "#22C55E")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(accentColor.opacity(0.8))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.2)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int(utilization))%")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accentColor)
                    Text("Reset \(resetInfo)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barGradient)
                        .frame(width: max(0, geo.size.width * min(utilization, 100) / 100))
                }
            }
            .frame(height: 6)
        }
    }
}

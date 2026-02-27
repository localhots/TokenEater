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

// MARK: - Main Widget View (router)

struct UsageWidgetView: View {
    let entry: UsageEntry

    @Environment(\.widgetFamily) var family
    private var theme: ThemeColors { SharedFileService().theme }

    var body: some View {
        Group {
            if let error = entry.error, entry.usage == nil {
                errorView(error)
            } else if let usage = entry.usage {
                switch family {
                case .systemLarge:
                    LargeUsageWidgetView(entry: entry, usage: usage)
                default:
                    MediumUsageWidgetView(entry: entry, usage: usage)
                }
            } else {
                placeholderView
            }
        }
        .modifier(WidgetBackgroundModifier())
    }

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

    private var placeholderView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(.orange)
            Text("widget.loading")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color(hex: theme.widgetText))
        }
    }
}

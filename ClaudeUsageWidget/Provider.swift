import WidgetKit
import Foundation

struct Provider: TimelineProvider {
    private let apiClient = ClaudeAPIClient.shared

    func placeholder(in context: Context) -> UsageEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> UsageEntry {
        guard apiClient.config != nil else {
            return .unconfigured
        }

        do {
            let usage = try await apiClient.fetchUsage()
            return UsageEntry(date: Date(), usage: usage)
        } catch {
            // Fallback to cached data
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
}

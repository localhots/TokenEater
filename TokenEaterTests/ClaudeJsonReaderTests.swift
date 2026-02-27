import Testing
import Foundation

@Suite("ClaudeJsonReader")
struct ClaudeJsonReaderTests {

    private var fixturePath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/claude.json")
            .path
    }

    // MARK: - readModelStats

    @Test("returns stats for each model, summed across projects")
    func readModelStatsReturnsSummedStats() {
        let stats = ClaudeJsonReader(filePath: fixturePath).readModelStats()

        #expect(stats.count == 3)

        let sonnet = stats.first { $0.modelName == "Sonnet" }
        let opus   = stats.first { $0.modelName == "Opus" }
        let haiku  = stats.first { $0.modelName == "Haiku" }

        // project-a Sonnet: 2000 + 800 = 2800
        #expect(sonnet?.totalTokens == 2800)

        // project-a Opus: 1000+500+200+100 = 1800
        // project-b Opus: 300+150+50 = 500  → total 2300
        #expect(opus?.totalTokens == 2300)

        // project-b Haiku: 500+200 = 700
        #expect(haiku?.totalTokens == 700)
    }

    @Test("results are sorted descending by token count")
    func readModelStatsSortedDescending() {
        let stats = ClaudeJsonReader(filePath: fixturePath).readModelStats()

        let counts = stats.map(\.totalTokens)
        #expect(counts == counts.sorted(by: >))
    }

    @Test("returns empty array when file does not exist")
    func readModelStatsReturnsEmptyForMissingFile() {
        let stats = ClaudeJsonReader(filePath: "/tmp/does-not-exist-\(UUID()).json").readModelStats()

        #expect(stats.isEmpty)
    }

    @Test("returns empty array for malformed JSON")
    func readModelStatsReturnsEmptyForBadJSON() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID()).json")
        try "not json at all".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let stats = ClaudeJsonReader(filePath: url.path).readModelStats()
        #expect(stats.isEmpty)
    }

    @Test("date-suffixed and plain model IDs aggregate into the same bucket")
    func readModelStatsAggregatesByMajorMinor() throws {
        let json = """
        {"projects":{"/a":{"lastModelUsage":{
            "claude-sonnet-4-6":{"inputTokens":1000,"outputTokens":0,"cacheReadInputTokens":0,"cacheCreationInputTokens":0},
            "claude-sonnet-4-6-20251101":{"inputTokens":500,"outputTokens":0,"cacheReadInputTokens":0,"cacheCreationInputTokens":0}
        }}}}
        """
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID()).json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let stats = ClaudeJsonReader(filePath: url.path).readModelStats()
        #expect(stats.count == 1)
        #expect(stats.first?.modelName == "Sonnet")
        #expect(stats.first?.totalTokens == 1500)
    }

    @Test("skips projects that have no lastModelUsage")
    func readModelStatsSkipsProjectsWithoutUsage() {
        // The fixture has project-empty with no lastModelUsage — it should not crash
        // and should contribute 0 tokens
        let stats = ClaudeJsonReader(filePath: fixturePath).readModelStats()
        #expect(stats.count == 3) // Opus, Sonnet, Haiku only
    }
}

import Foundation
import Testing
import Domain
@testable import Infrastructure

@Suite
struct ClaudeDailyUsageAnalyzerTests {
    /// Creates a temp directory with JSONL files for testing.
    private func setupTempClaudeDir(with jsonlContent: String, fileName: String = "test-session.jsonl") throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectsDir = tmpDir.appendingPathComponent("projects").appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        let fileURL = projectsDir.appendingPathComponent(fileName)
        try jsonlContent.write(to: fileURL, atomically: true, encoding: .utf8)
        return tmpDir
    }

    @Test func `analyzes today's usage from JSONL files`() async throws {
        let todayStr = ISO8601DateFormatter().string(from: Date())
        let jsonl = """
        {"type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":1000,"output_tokens":500}},"timestamp":"\(todayStr)"}
        """
        let claudeDir = try setupTempClaudeDir(with: jsonl)
        defer { try? FileManager.default.removeItem(at: claudeDir) }

        let analyzer = ClaudeDailyUsageAnalyzer(claudeDir: claudeDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.today.totalTokens == 1500)
        #expect(report.today.totalCost > 0)
    }

    @Test func `previous day is empty when no data exists`() async throws {
        let todayStr = ISO8601DateFormatter().string(from: Date())
        let jsonl = """
        {"type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":100,"output_tokens":50}},"timestamp":"\(todayStr)"}
        """
        let claudeDir = try setupTempClaudeDir(with: jsonl)
        defer { try? FileManager.default.removeItem(at: claudeDir) }

        let analyzer = ClaudeDailyUsageAnalyzer(claudeDir: claudeDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.previous.isEmpty)
        #expect(report.previous.totalTokens == 0)
    }

    @Test func `produces empty report when no files exist`() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let analyzer = ClaudeDailyUsageAnalyzer(claudeDir: tmpDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.today.isEmpty)
        #expect(report.previous.isEmpty)
    }

    @Test func `aggregates cache tokens and savings`() async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let todayStr = formatter.string(from: Date())
        // Sonnet pricing: input $3/M, cache_read $0.30/M → savings = 1M * $2.70 = $2.70
        let jsonl = """
        {"type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":1000,"output_tokens":500,"cache_creation_input_tokens":2000,"cache_read_input_tokens":1000000}},"timestamp":"\(todayStr)"}
        """
        let claudeDir = try setupTempClaudeDir(with: jsonl)
        defer { try? FileManager.default.removeItem(at: claudeDir) }

        let analyzer = ClaudeDailyUsageAnalyzer(claudeDir: claudeDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.today.inputTokens == 1000)
        #expect(report.today.outputTokens == 500)
        #expect(report.today.cacheCreationTokens == 2000)
        #expect(report.today.cacheReadTokens == 1_000_000)
        #expect(report.today.cachedSavings == Decimal(string: "2.7"))
        // hit rate = 1M / (1M + 1000) ≈ 0.999
        #expect(report.today.cacheHitRate > 0.99)
    }

    @Test func `separates today and yesterday records`() async throws {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: now))!.addingTimeInterval(3600 * 12)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let todayStr = formatter.string(from: now)
        let yesterdayStr = formatter.string(from: yesterday)

        let jsonl = """
        {"type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":1000,"output_tokens":500}},"timestamp":"\(todayStr)"}
        {"type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":2000,"output_tokens":1000}},"timestamp":"\(yesterdayStr)"}
        """
        let claudeDir = try setupTempClaudeDir(with: jsonl)
        defer { try? FileManager.default.removeItem(at: claudeDir) }

        let analyzer = ClaudeDailyUsageAnalyzer(claudeDir: claudeDir)
        let report = try await analyzer.analyzeToday()

        #expect(report.today.totalTokens == 1500)
        #expect(report.previous.totalTokens == 3000)
    }
}

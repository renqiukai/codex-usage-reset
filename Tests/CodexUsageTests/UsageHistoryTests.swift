import XCTest
@testable import CodexUsage

final class UsageHistoryTests: XCTestCase {
    func testAppendPreservesPreviousRecordsAndAccount() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("history.jsonl")
        let usage = try JSONDecoder().decode(Usage.self, from: Data(#"{"accountId":"test-account","rateLimits":{"primary":{"usedPercent":33,"resetsAt":2000000000}},"rateLimitResetCredits":{"availableCount":2,"credits":[{"status":"available","expiresAt":null}]}}"#.utf8))
        try UsageHistory.append(usage, at: Date(timeIntervalSince1970: 100), to: file)
        let first = try Data(contentsOf: file)
        try UsageHistory.append(usage, at: Date(timeIntervalSince1970: 200), to: file)
        let all = try Data(contentsOf: file)
        XCTAssertTrue(all.starts(with: first))
        let lines = all.split(separator: 10)
        XCTAssertEqual(lines.count, 2)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try lines.map { try decoder.decode(UsageRecord.self, from: Data($0)) }
        XCTAssertEqual(records.map(\.recordedAt.timeIntervalSince1970), [100, 200])
        XCTAssertEqual(records[1].usage.accountId, "test-account")
        XCTAssertEqual(records[1].usage.mainWindow?.remaining, 67)
        XCTAssertEqual(records[1].usage.rateLimitResetCredits?.availableCount, 2)
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testWriteFailureIsReported() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let usage = try JSONDecoder().decode(Usage.self, from: Data(#"{"rateLimits":{}}"#.utf8))
        XCTAssertThrowsError(try UsageHistory.append(usage, at: Date(), to: directory))
    }
}

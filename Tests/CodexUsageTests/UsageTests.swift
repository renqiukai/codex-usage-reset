import XCTest
@testable import CodexUsage

final class UsageTests: XCTestCase {
    func testLiveReadWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["CODEX_USAGE_LIVE"] == "1" else {
            throw XCTSkip("设置 CODEX_USAGE_LIVE=1 才读取本机账号")
        }
        let usage = try UsageReader.read()
        XCTAssertFalse(usage.buckets.isEmpty)
        if let window = usage.mainWindow { XCTAssertTrue((0...100).contains(window.remaining)) }
    }
    func testUsageAndCreditDetails() throws {
        let data = Data(#"{"rateLimits":{"primary":{"usedPercent":33,"windowDurationMins":10080,"resetsAt":2000000000}},"rateLimitResetCredits":{"availableCount":2,"credits":[{"status":"available","expiresAt":null}]}}"#.utf8)
        let usage = try JSONDecoder().decode(Usage.self, from: data)
        XCTAssertEqual(usage.mainWindow?.remaining, 67)
        XCTAssertEqual(usage.mainWindow?.label, "每周额度")
        XCTAssertEqual(usage.rateLimitResetCredits?.availableCount, 2)
        XCTAssertNil(usage.rateLimitResetCredits?.credits?.first?.expiresAt)
        XCTAssertEqual(usage.buckets.count, 1)
    }
    func testUnknownIsNotZeroAndPastResetIsNotRefilled() throws {
        let usage = try JSONDecoder().decode(Usage.self, from: Data(#"{"rateLimits":{},"rateLimitResetCredits":null}"#.utf8))
        XCTAssertNil(usage.mainWindow)
        XCTAssertNil(usage.rateLimitResetCredits)
        let window = Window(usedPercent: 110, windowDurationMins: 300, resetsAt: 1)
        XCTAssertEqual(window.remaining, 0)
        XCTAssertEqual(window.countdown(at: Date(timeIntervalSince1970: 2)), "已到恢复时间，等待刷新确认")
        XCTAssertEqual(window.label, "5 小时额度")
    }
    func testMultipleBucketsPreferCodex() throws {
        let usage = try JSONDecoder().decode(Usage.self, from: Data(#"{"rateLimits":{"primary":{"usedPercent":90}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":20}},"other":{}}}"#.utf8))
        XCTAssertEqual(usage.mainWindow?.remaining, 80)
        XCTAssertEqual(usage.buckets.count, 2)
    }
}

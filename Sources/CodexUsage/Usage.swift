import Foundation

struct Usage: Codable {
    let accountId: String?
    let rateLimits: Bucket
    let rateLimitsByLimitId: [String: Bucket]?
    let rateLimitResetCredits: ResetCredits?

    var buckets: [(String, Bucket)] {
        if let all = rateLimitsByLimitId, !all.isEmpty {
            return all.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        }
        return [(rateLimits.limitId ?? "codex", rateLimits)]
    }
    var mainWindow: Window? {
        (rateLimitsByLimitId?["codex"] ?? rateLimits).primary
    }
}

struct Bucket: Codable {
    let limitId: String?
    let limitName: String?
    let primary: Window?
    let secondary: Window?
}

struct Window: Codable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
    var remaining: Int { Int(max(0, min(100, 100 - usedPercent)).rounded(.down)) }
    var label: String {
        guard let minutes = windowDurationMins else { return "额度" }
        if minutes == 10080 { return "每周额度" }
        if minutes % 1440 == 0 { return "\(minutes / 1440) 天额度" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时额度" }
        return "\(minutes) 分钟额度"
    }
    func countdown(at now: Date) -> String {
        guard let resetsAt else { return "恢复时间未提供" }
        let seconds = resetsAt - now.timeIntervalSince1970
        guard seconds > 0 else { return "已到恢复时间，等待刷新确认" }
        let minutes = Int(ceil(seconds / 60))
        let days = minutes / 1440
        let hours = minutes % 1440 / 60
        return days > 0 ? "\(days) 天 \(hours) 小时后恢复" : "\(hours) 小时 \(minutes % 60) 分钟后恢复"
    }
}

struct ResetCredits: Codable {
    let availableCount: Int
    let credits: [ResetCredit]?
}

struct ResetCredit: Codable {
    let status: String
    let expiresAt: Double?
}

enum UsageError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        if case .unavailable(let message) = self { return message }
        return nil
    }
}

enum UsageReader {
    static func read() throws -> Usage {
        let candidates = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", "/Applications/Codex.app/Contents/Resources/codex"]
        guard let binary = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw UsageError.unavailable("未找到 Codex，请先安装并登录 Codex。")
        }
        let process = Process()
        let input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let timeout = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 25, execute: timeout)
        defer {
            timeout.cancel()
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            try? output.fileHandleForReading.close()
        }
        func send(_ message: [String: Any]) throws {
            var bytes = try JSONSerialization.data(withJSONObject: message)
            bytes.append(10)
            try input.fileHandleForWriting.write(contentsOf: bytes)
        }
        try send(["id": 1, "method": "initialize", "params": [
            "clientInfo": ["name": "codex_usage_menu", "title": "Codex Usage", "version": "0.1.0"],
            "capabilities": ["experimentalApi": true]
        ]])
        var buffer = Data()
        while true {
            let data = output.fileHandleForReading.availableData
            if data.isEmpty { throw UsageError.unavailable("读取超时或 Codex 已退出，请检查网络与登录状态后重试。") }
            buffer.append(data)
            guard buffer.count < 4_000_000 else { throw UsageError.unavailable("Codex 响应异常，请重试。") }
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let id = message["id"] as? Int, [1, 2].contains(id) else { continue }
                if message["error"] != nil {
                    // Avoid exposing server diagnostics that may contain account details.
                    throw UsageError.unavailable("Codex 拒绝读取，请确认已登录 ChatGPT 账号，并更新 Codex 后重试。")
                }
                if id == 1 {
                    try send(["method": "initialized"])
                    try send(["id": 2, "method": "account/rateLimits/read", "params": ["excludeResetCreditDetails": false]])
                } else if let result = message["result"] {
                    return try JSONDecoder().decode(Usage.self, from: JSONSerialization.data(withJSONObject: result))
                }
            }
        }
    }
}

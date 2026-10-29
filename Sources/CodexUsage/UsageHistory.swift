import Foundation
import Darwin

struct UsageRecord: Codable {
    let recordedAt: Date
    let usage: Usage
}

enum UsageHistory {
    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexUsage", isDirectory: true)
            .appendingPathComponent("usage-history.jsonl")
    }

    static func append(_ usage: Usage, at date: Date, to url: URL = fileURL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(UsageRecord(recordedAt: date, usage: usage))
        data.append(10)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_APPEND, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(descriptor, LOCK_UN) }
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }
}

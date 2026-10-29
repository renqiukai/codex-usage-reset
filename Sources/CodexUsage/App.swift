import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published var usage: Usage?
    @Published var updatedAt: Date?
    @Published var error: String?
    @Published var loading = false
    @Published var historyError: String?
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    var title: String {
        if error != nil { return "Codex !" }
        guard let window = usage?.mainWindow else { return "Codex —" }
        return "Codex \(window.remaining)%"
    }
    func refresh() {
        guard !loading else { return }
        loading = true
        Task {
            do {
                let result = try await Task.detached(priority: .utility) {
                    let usage = try UsageReader.read()
                    let date = Date()
                    var historyError: String?
                    do { try UsageHistory.append(usage, at: date) }
                    catch { historyError = "本次用量已刷新，但记录保存失败，请检查磁盘空间和目录权限。" }
                    return (usage, date, historyError)
                }.value
                usage = result.0
                updatedAt = result.1
                historyError = result.2
                error = nil
            } catch {
                self.error = (error as? UsageError)?.localizedDescription ?? "暂时无法读取用量，请检查 Codex 与网络后重试。"
            }
            loading = false
        }
    }
}

@main
struct CodexUsageApp: App {
    @StateObject private var store = UsageStore()
    var body: some Scene {
        MenuBarExtra(store.title, systemImage: "chart.bar.fill") {
            UsagePanel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

struct UsagePanel: View {
    @ObservedObject var store: UsageStore
    private func date(_ timestamp: Double) -> String {
        Date(timeIntervalSince1970: timestamp).formatted(.dateTime.month().day().hour().minute())
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Codex 用量").font(.title2.bold())
                        Text("本机登录账号 · 每 5 分钟刷新").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.loading { ProgressView().controlSize(.small) }
                }
                if let error = store.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                    if store.usage != nil { Text("以下为上次成功读取的数据").font(.caption).foregroundStyle(.secondary) }
                }
                if let usage = store.usage {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(usage.buckets, id: \.0) { key, bucket in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(bucket.limitName ?? key).font(.caption.bold()).foregroundStyle(.secondary)
                                    if let primary = bucket.primary { window(primary, now: timeline.date) }
                                    if let secondary = bucket.secondary { window(secondary, now: timeline.date) }
                                    if bucket.primary == nil && bucket.secondary == nil {
                                        Text("当前未提供额度信息").font(.callout).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(14).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("可用重置", systemImage: "arrow.counterclockwise")
                                    Spacer()
                                    Text(usage.rateLimitResetCredits.map { "\($0.availableCount) 次" } ?? "未提供").bold()
                                }
                                if let summary = usage.rateLimitResetCredits {
                                    if let credits = summary.credits {
                                        ForEach(Array(credits.enumerated()), id: \.offset) { index, credit in
                                            HStack(alignment: .top) {
                                                Text("权益 \(index + 1)")
                                                Spacer()
                                                if let expiry = credit.expiresAt {
                                                    Text("\(date(expiry)) 到期")
                                                        .foregroundStyle(expiry - timeline.date.timeIntervalSince1970 < 86400 ? .orange : .secondary)
                                                } else { Text("无到期时间").foregroundStyle(.secondary) }
                                            }.font(.caption)
                                        }
                                        if summary.availableCount > credits.count {
                                            Text("仅返回部分权益的到期明细").font(.caption).foregroundStyle(.secondary)
                                        }
                                    } else { Text("到期明细暂未提供").font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }.frame(height: 300)
                } else if store.loading {
                    Text("正在读取 Codex 用量…").foregroundStyle(.secondary).padding(.vertical, 20)
                }
                Divider()
                if let historyError = store.historyError {
                    Text(historyError).font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Text("每次成功刷新均保存用量记录").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("记录文件") {
                        NSWorkspace.shared.activateFileViewerSelecting([UsageHistory.fileURL])
                    }
                    .disabled(!FileManager.default.fileExists(atPath: UsageHistory.fileURL.path))
                }
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.updatedAt.map { "更新于 \($0.formatted(date: .omitted, time: .shortened))" } ?? "尚未成功读取")
                        Text("时间按本机时区显示")
                    }.font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("刷新") { store.refresh() }.disabled(store.loading)
                    Button("退出") { NSApplication.shared.terminate(nil) }
                }
            }.padding(20).frame(width: 360)
        }
    }
    private func window(_ window: Window, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(window.label).font(.callout)
                Spacer()
                Text("剩余 \(window.remaining)%").font(.headline.monospacedDigit())
            }
            ProgressView(value: Double(window.remaining), total: 100)
                .tint(window.remaining <= 20 ? .orange : .accentColor)
                .accessibilityLabel("\(window.label)剩余百分之\(window.remaining)")
            Text(window.countdown(at: now)).font(.caption).foregroundStyle(.secondary)
            if let reset = window.resetsAt {
                Text("恢复时间 · \(date(reset))").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

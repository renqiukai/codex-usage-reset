# Codex Usage

macOS 菜单栏用量工具：读取本机 Codex 登录账号的剩余额度、额度恢复时间与倒计时、可用重置次数及到期明细。每 5 分钟刷新，也可手动刷新。

## 运行

需要 macOS 13+、Swift 6 工具链，以及已登录 ChatGPT 账号的 Codex。

```sh
swift test
zsh build.sh
open "dist/Codex Usage.app"
```

如果默认命令行工具缺少 XCTest，使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`。加上环境变量 `CODEX_USAGE_LIVE=1` 可执行真实账号只读验证，默认测试不联网。

运行后在屏幕顶部菜单栏点击 `Codex xx%`。可以把生成的 app 拖入“应用程序”目录。首版不自动设置开机启动。

## 数据说明

- 使用本机 `codex app-server` 的 `account/rateLimits/read`，不创建对话、不调用模型、不兑换重置权益。
- 优先查找 `/opt/homebrew/bin/codex`、`/usr/local/bin/codex`，再使用 Codex.app 自带版本。沿用 Codex 的默认账号配置，若 CLI 与桌面端使用不同账号或 CODEX_HOME，需先统一配置。
- 剩余额度按接口的已用百分比计算，不推算剩余 token 或消息条数。
- “恢复时间”是额度窗口重置时间，不是订阅续费扣款时间。
- 重置次数以服务端 availableCount 为准；明细可能不完整，缺失显示“未提供”。
- 到达恢复时间后等待重新查询，不自行将余额变为 100%。读取失败时保留旧数据并明确标记。
- 所有界面时间按电脑当前时区显示。工具不保存登录凭据；登录与网络请求由 Codex 管理。
- 当前构建为本机临时签名，未做 Apple 公证，供本机使用。

协议参考：https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt

## 用量历史

启动首次读取、每 5 分钟自动刷新、手动刷新，成功后均追加一条记录（即使用量没有变化）。面板中的“记录文件”按钮会在访达中定位文件：

`~/Library/Application Support/CodexUsage/usage-history.jsonl`

每行是一个 JSON，包含 UTC 格式的记录时间、账号标识（接口提供时）、各额度窗口的已用百分比与恢复时间、可用重置次数及到期明细。剩余百分比 = 100 − 已用百分比。账号标识用于区分切换账号前后的记录，不保存令牌。

文件只追加、不自动清理，重启或重新构建不会覆盖。刷新失败不会把旧数据再次当成新记录；写入失败会在面板提示，仍展示新读取的用量。软件退出或电脑睡眠期间不采样，无法补回历史，也不能据此还原逐次请求的 token 消耗。

## 开源与隐私

本项目采用 [MIT License](LICENSE)。这是独立社区工具，与 OpenAI 无隶属关系。

仓库仅包含源码、测试与构建脚本，不包含登录凭据、真实用量记录或已构建应用。用量历史可能包含账号标识，反馈问题时请勿上传原始记录或账号配置。

#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
swift build -c release
app="dist/Codex Usage.app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/CodexUsage "$app/Contents/MacOS/CodexUsage"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CodexUsage</string>
<key>CFBundleIdentifier</key><string>local.codex-usage.menu</string>
<key>CFBundleName</key><string>Codex Usage</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "已生成：$PWD/$app"

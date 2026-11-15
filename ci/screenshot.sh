#!/usr/bin/env bash
# シミュレーターでアプリを起動して画面写真を撮る（見た目の確認用）
set -euo pipefail
DEVICE="iPhone 18 Pro"
OS="27.2"
mkdir -p screenshots
xcodebuild build -project GenbaTokei.xcodeproj -scheme GenbaTokei \
  -destination "platform=iOS Simulator,name=$DEVICE,OS=$OS" \
  -derivedDataPath build/sim CODE_SIGNING_ALLOWED=NO -quiet
APP="$(find build/sim/Build/Products -name 'GenbaTokei.app' -maxdepth 3 | head -1)"
UDID="$(xcrun simctl list devices available -j | jq -r --arg n "$DEVICE" --arg os "iOS-${OS//./-}" \
  '.devices | to_entries[] | select(.key | endswith($os)) | .value[] | select(.name==$n) | .udid' | head -1)"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "12:34" || true
xcrun simctl install "$UDID" "$APP"
BID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"
xcrun simctl launch "$UDID" "$BID"
sleep 6
xcrun simctl io "$UDID" screenshot screenshots/prototype.png

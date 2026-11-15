#!/usr/bin/env bash
# App Store 用の素材（画面写真と説明動画の元）をシミュレーターで撮る。出力：capture/
#   capture/APP_IPHONE_67/*.png, capture/APP_IPAD_PRO_3GEN_129/*.png, capture/APP_WATCH_ULTRA/*.png
#   capture/video-iphone.mov, capture/video-ipad.mov（-tour で画面を自動で切り替えて約 29 秒）
# 文字入れと動画の規格合わせは別の手順（scripts/store-compose.py）で行う
set -euo pipefail
ci/appstore-shots.sh
rm -rf capture && mv store-shots capture

OS="27.2"
udid() {
  xcrun simctl list devices available -j | jq -r --arg n "$1" --arg rt "$2" \
    '.devices | to_entries[] | select(.key | endswith($rt)) | .value[] | select(.name==$n) | .udid' | head -1
}
APP="$(find build/store/Build/Products -maxdepth 2 -name 'GenbaTokei.app' | grep -v watch | head -1)"
BID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"

record() { # 端末名 出力
  local id; id="$(udid "$1" "iOS-${OS//./-}")"
  xcrun simctl terminate "$id" "$BID" 2>/dev/null || true
  xcrun simctl io "$id" recordVideo --codec=h264 --force "$2" &
  local rec=$!
  sleep 2
  xcrun simctl launch "$id" "$BID" -demo -tour >/dev/null
  sleep 31
  kill -INT "$rec"
  wait "$rec" || true
  ls -la "$2"
}
record "iPhone 18 Pro Max" capture/video-iphone.mov
record "iPad Pro 13-inch (M5)" capture/video-ipad.mov

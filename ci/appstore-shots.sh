#!/usr/bin/env bash
# App Store 用の画面写真をシミュレーターで撮る。出力：store-shots/<表示種別>/*.png
#   APP_IPHONE_67        … iPhone 6.9 インチ（iPhone 18 Pro Max）
#   APP_IPAD_PRO_3GEN_129 … iPad 13 インチ（iPad Pro 13-inch (M5)）
#   APP_WATCH_ULTRA      … Apple Watch Ultra 4 (49mm)
set -euo pipefail
OS="27.2"
OUT=store-shots
mkdir -p "$OUT"

udid() { # 端末名 ランタイム（iOS-27-2 など）
  xcrun simctl list devices available -j | jq -r --arg n "$1" --arg rt "$2" \
    '.devices | to_entries[] | select(.key | endswith($rt)) | .value[] | select(.name==$n) | .udid' | head -1
}

prepare() { # UDID
  xcrun simctl boot "$1" || true
  xcrun simctl bootstatus "$1" -b
  xcrun simctl status_bar "$1" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName "" 2>/dev/null || true
}

shoot() { # UDID バンドルID 出力ファイル [起動引数...]
  local id="$1" bid="$2" file="$3"; shift 3
  xcrun simctl terminate "$id" "$bid" 2>/dev/null || true
  xcrun simctl launch "$id" "$bid" "$@" >/dev/null
  sleep 7
  xcrun simctl io "$id" screenshot "$file"
  echo "$(basename "$(dirname "$file")")/$(basename "$file"): $(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel/{printf "%s ", $2}')"
}

# iPhone / iPad（同じアプリ）
xcodebuild build -project GenbaTokei.xcodeproj -scheme GenbaTokei \
  -destination "generic/platform=iOS Simulator" -derivedDataPath build/store CODE_SIGNING_ALLOWED=NO -quiet
APP="$(find build/store/Build/Products -maxdepth 2 -name 'GenbaTokei.app' | grep -v watch | head -1)"
BID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"

for pair in "iPhone 18 Pro Max:APP_IPHONE_67" "iPad Pro 13-inch (M5):APP_IPAD_PRO_3GEN_129"; do
  name="${pair%%:*}"; dir="$OUT/${pair##*:}"; mkdir -p "$dir"
  id="$(udid "$name" "iOS-${OS//./-}")"
  [ -n "$id" ] || { echo "::error::シミュレーター $name が無い"; exit 1; }
  prepare "$id"
  xcrun simctl install "$id" "$APP"
  shoot "$id" "$BID" "$dir/1.png" -demo
  shoot "$id" "$BID" "$dir/2.png" -demo -tab 0
  shoot "$id" "$BID" "$dir/3.png" -demo -tab 1
  shoot "$id" "$BID" "$dir/4.png" -demo -tab 2
done

# Apple Watch（Watch アプリを単体でシミュレーターに入れる）
WAPP="$(find build/store/Build/Products -maxdepth 3 -name 'GenbaTokeiWatch.app' | head -1)"
if [ -z "$WAPP" ]; then
  xcodebuild build -project GenbaTokei.xcodeproj -scheme GenbaTokeiWatch \
    -destination "generic/platform=watchOS Simulator" -derivedDataPath build/store CODE_SIGNING_ALLOWED=NO -quiet
  WAPP="$(find build/store/Build/Products -maxdepth 3 -name 'GenbaTokeiWatch.app' | head -1)"
fi
WBID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$WAPP/Info.plist")"
wid="$(udid "Apple Watch Ultra 4 (49mm)" "watchOS-${OS//./-}")"
[ -n "$wid" ] || { echo "::error::Watch シミュレーターが無い"; exit 1; }
mkdir -p "$OUT/APP_WATCH_ULTRA"
xcrun simctl boot "$wid" || true
xcrun simctl bootstatus "$wid" -b
xcrun simctl install "$wid" "$WAPP"
shoot "$wid" "$WBID" "$OUT/APP_WATCH_ULTRA/1.png" -demo

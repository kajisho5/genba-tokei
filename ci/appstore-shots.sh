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

prepare() { # UDID（日本語・日本の地域に設定してから起動し直す）
  xcrun simctl boot "$1" || true
  xcrun simctl bootstatus "$1" -b
  xcrun simctl spawn "$1" defaults write -g AppleLanguages -array ja
  xcrun simctl spawn "$1" defaults write -g AppleLocale ja_JP
  xcrun simctl shutdown "$1" || true
  xcrun simctl boot "$1"
  xcrun simctl bootstatus "$1" -b
  xcrun simctl status_bar "$1" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName "" 2>/dev/null || true
}

is_app_screen() { # 画像ファイル → アプリの暗い画面なら成功（起動中の白い画面なら失敗）
  sips -s format bmp -z 16 16 "$1" --out "$1.bmp" >/dev/null 2>&1 || return 1
  python3 - "$1.bmp" <<'PY'
import struct, sys
b = open(sys.argv[1], "rb").read()
off, = struct.unpack_from("<I", b, 10)
px = b[off:]
sys.exit(0 if px and sum(px) / len(px) < 110 else 1)
PY
}

wait_app() { # UDID 出力ファイル [最大秒] → アプリの画面が出るまで待って撮る
  local id="$1" file="$2" max="${3:-90}" t=0
  while [ "$t" -lt "$max" ]; do
    sleep 3; t=$((t + 3))
    xcrun simctl io "$id" screenshot "$file" >/dev/null 2>&1 || continue
    if is_app_screen "$file"; then
      rm -f "$file.bmp"; echo "  ${t} 秒で表示"; return 0
    fi
  done
  rm -f "$file.bmp"
  echo "::warning::$(basename "$file")：${max} 秒待ってもアプリの画面が出ない"
  return 1
}

shoot() { # UDID バンドルID 出力ファイル [起動引数...]
  local id="$1" bid="$2" file="$3"; shift 3
  xcrun simctl terminate "$id" "$bid" 2>/dev/null || true
  xcrun simctl launch "$id" "$bid" "$@" >/dev/null
  wait_app "$id" "$file" || true
  sleep 3   # 表示が落ち着いてから撮り直す
  xcrun simctl io "$id" screenshot "$file"
  echo "$(basename "$(dirname "$file")")/$(basename "$file"): $(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel/{printf "%s ", $2}')"
}

# iPhone / iPad（同じアプリ）
xcodebuild build -project GenbaTokei.xcodeproj -scheme GenbaTokei \
  -destination "generic/platform=iOS Simulator" -derivedDataPath build/store CODE_SIGNING_ALLOWED=NO -quiet
APP="$(find build/store/Build/Products -maxdepth 2 -name 'GenbaTokei.app' | grep -v watch | head -1)"
BID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"

app_log() { # UDID → アプリの画面が出ない時の手がかり（直近のログ）
  xcrun simctl spawn "$1" log show --last 2m --style compact --predicate 'process == "GenbaTokei"' 2>/dev/null | tail -40 || true
}

# 1 台目で画面が出なければ次の候補を使う（13 インチ iPad はどれも App Store の同じ枠に入る）
shoot_set() { # 出力フォルダ 端末名...
  local dir="$1"; shift
  mkdir -p "$dir"
  for name in "$@"; do
    local id; id="$(udid "$name" "iOS-${OS//./-}")"
    [ -n "$id" ] || { echo "シミュレーター $name が無い"; continue; }
    echo "== $name"
    prepare "$id"
    xcrun simctl install "$id" "$BID_APP"
    # 起動直後は画面の更新が遅いので、一度起動して表示を確かめてから撮る
    xcrun simctl launch "$id" "$BID" -demo >/dev/null
    if ! wait_app "$id" "$dir/1.png" 120; then
      app_log "$id"
      xcrun simctl shutdown "$id" || true
      continue
    fi
    shoot "$id" "$BID" "$dir/1.png" -demo
    shoot "$id" "$BID" "$dir/2.png" -demo -tab 0
    shoot "$id" "$BID" "$dir/3.png" -demo -tab 1
    shoot "$id" "$BID" "$dir/4.png" -demo -tab 2
    echo "$name" > "$dir/../$(basename "$dir" | tr 'A-Z_' 'a-z-')-device.txt"
    return 0
  done
  echo "::error::$dir：どの端末でもアプリの画面が出なかった"
  exit 1
}

BID_APP="$APP"
shoot_set "$OUT/APP_IPHONE_67" "iPhone 18 Pro Max" "iPhone 17 Pro Max"
shoot_set "$OUT/APP_IPAD_PRO_3GEN_129" "iPad Pro 13-inch (M5)" "iPad Air 13-inch (M4)" "iPad Air 13-inch (M3)" "iPad Pro 13-inch (M4)"
mv "$OUT/app-ipad-pro-3gen-129-device.txt" "$OUT/ipad-device.txt"
mv "$OUT/app-iphone-67-device.txt" "$OUT/iphone-device.txt"

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
prepare "$wid"
xcrun simctl install "$wid" "$WAPP"
shoot "$wid" "$WBID" "$OUT/APP_WATCH_ULTRA/1.png" -demo

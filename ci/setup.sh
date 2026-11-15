#!/usr/bin/env bash
# CI 共通の準備：Xcode の選択と XcodeGen の導入、プロジェクト生成
set -euo pipefail
XCODE_APP="${XCODE_APP:-/Applications/Xcode_27.2.app}"
XCODEGEN_VERSION="${XCODEGEN_VERSION:-2.46.0}"

sudo xcode-select -s "$XCODE_APP/Contents/Developer"
xcodebuild -version

if ! command -v xcodegen >/dev/null; then
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/xcodegen.zip" \
    "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip"
  unzip -q "$tmp/xcodegen.zip" -d "$tmp"
  export PATH="$tmp/xcodegen/bin:$PATH"
  echo "$tmp/xcodegen/bin" >> "${GITHUB_PATH:-/dev/null}"
fi
xcodegen --version
xcodegen generate

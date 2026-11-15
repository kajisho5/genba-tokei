# genba-tokei（現場時計）

iPhone / iPad / Apple Watch 用の、1/100 秒まで表示する現場向け時計アプリ。

- 設計書：[docs/design.md](docs/design.md)
- デザイン：[docs/svg/](docs/svg/)（S6＝オペレーター向け時計だけモード）
- 紹介ページ：`site/`（公開先 https://kajisho5.github.io/genba-tokei/ 、設計 [docs/site/lp-design.md](docs/site/lp-design.md)）
- iPhone に入れる準備：[docs/testflight-setup.md](docs/testflight-setup.md) ／ 実機で確かめること：[docs/device-test.md](docs/device-test.md)

## 状態
本実装中（試作で Dynamic Island の 1/100 秒表示を実機確認済み）

## 構成
- `project.yml` … XcodeGen 設定（Xcode プロジェクトは CI 上で自動生成）
- `App/` … iPhone / iPad アプリ ／ `LiveActivity/` … Dynamic Island ／ `Shared/` … 共通 ／ `Tests/` … 自動テスト
- `.github/workflows/build.yml` … 変更のたびにテストとビルド
- `.github/workflows/testflight.yml` … 手動で TestFlight に配布（kajisho5/runway の共通ワークフロー）
- `.github/workflows/pages.yml` … main に入ったら紹介ページを公開

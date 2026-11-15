# 現場時計（仮称：GENBA TOKEI）詳細設計書 v0.1

作成日：2026-11-15（v0.2：オペレーター向け「時計だけモード」を追加）／ 状態：**実装中**（試作で Dynamic Island の 1/100 秒表示を実機確認済み → 本実装）

> この設計書の記号
> - **【事実】** … 公式ドキュメント等で確認済み（URL は第 11 章）
> - **【推測】** … 根拠はあるが未確認。実機で確かめる
> - **【不明】** … 確認できなかった

---

## 1. 目的・前提

イベント・撮影・舞台などの「現場」で、**誰が見ても同じ時刻を、1/100 秒（ミリ秒 2 桁）まで**表示する時計アプリ。
iPhone・iPad・Apple Watch で動き、他のアプリを使っている間も **フローティング（小窓）** と **Dynamic Island（画面上部の黒い部分）** で時刻を見られるようにする。

- 開発者は Mac を持たない → ビルド・署名は GitHub Actions の Mac ランナーで行う
- 操作は主に iPhone から

---

## 2. 一番大事な結論（できること／できないこと）

| やりたいこと | 結論 | 根拠 |
|---|---|---|
| アプリ画面で `12:34:56.78` を滑らかに表示 | **できる** 【事実】 | SwiftUI の `TimelineView(.animation)` で画面の書き換えごとに描画 |
| Dynamic Island にミリ秒 2 桁 | **できる見込み。ただし実機で要確認** 【推測】 | iOS 18 で追加された `SystemFormatStyle.Stopwatch` は**標準で 1/100 秒を表示**し、`TimeDataSource` は **Live Activity 内で自動更新される**と公式に明記。ただし「画面ロック中は秒の更新が止まる」という開発者報告もある |
| フローティング（他アプリの上に小窓） | **技術的にはできる。審査に通るかは不明** 【不明】 | ピクチャ・イン・ピクチャ（PiP：動画の小窓機能）に時計の映像を流す方式。過去に同種のタイマーアプリが一度却下→異議申し立てで承認された事例あり |
| Apple Watch で 1/100 秒 | **腕を上げている間はできる。腕を下ろすと秒まで** 【事実＋推測】 | 常時表示中は更新が最大 1 秒ごとに制限される |
| Apple Watch 単体でネット時刻合わせ（NTP） | **できない** 【事実】 | watchOS は普通のアプリに UDP 通信（NTP が使う通信方式）を許可していない（Apple 技術資料 TN3135） → iPhone から「ずれ量」を送る方式にする |

### ミリ秒 2 桁の見え方について（正直な注意）
- 1/100 秒は 1 秒に 100 回変わるが、画面は 1 秒に 60 回（一部機種は最大 120 回）しか書き換わらない。**最後の 1 桁はすべての数字が見えるわけではない**（どの時計アプリでも同じ物理的な限界）【事実】
- 120Hz 表示には Info.plist に `CADisableMinimumFrameDurationOnPhone` を入れる必要があるとされる。効かないという報告もある 【推測・要実機確認】
- 表示される時刻の「正しさ」は端末の時計の精度で決まる。そこで **NTP（ネットで正確な時刻を取る仕組み）で ずれ量 を測り、補正して表示** する。精度は通信の往復時間で決まり、目安 ±10〜50ms 程度 【推測】

---

## 3. 要件定義

### 3.1 機能（MVP＝最初に作る範囲）

| ID | 機能 | 対応 |
|---|---|---|
| F1 | 大きな時刻表示 `HH:MM:SS.cc`（cc＝1/100 秒） | iPhone / iPad / Watch |
| F2 | NTP 時刻補正：起動時・復帰時・手動で同期。ずれ量と精度（±ms）と最終同期時刻を表示 | iPhone / iPad |
| F3 | カウントダウン（「本番まで」）：目標時刻を指定 → 残り時間を `-00:04:59.83` 表示。残り 5 分で黄、1 分で赤 | 全部 |
| F4 | ストップウォッチ（ラップ付き） | 全部 |
| F5 | Dynamic Island / ロック画面表示（Live Activity） | iPhone（iPad は iPadOS 26 以降で Live Activity 対応の情報があるが要確認 【不明】） |
| F6 | フローティング表示（PiP） | iPhone / iPad |
| F7 | 画面を消さない（スリープ防止）・横向き全画面 | iPhone / iPad |
| F8 | Watch へずれ量を共有（WatchConnectivity：iPhone と Watch の通信機能） | iPhone → Watch |
| F9 | 0 秒到達時にバイブ（Watch は触覚）・任意で音 | 全部 |
| F10 | **時計だけモード**（オペレーター向け）：ボタン・タブ・文字を消し時刻だけを画面いっぱいに表示。**起動時の標準画面**。触ると操作部が 3 秒だけ出る（設定で「長押しのみ」に変更可）。表示する要素（1/100 秒・補正状態の点・日付）を個別にオン／オフ | iPhone / iPad（Watch は元から時計だけ。小窓・Dynamic Island は表示内容の設定で「時計のみ」を選べる） |

### 3.2 次の段階で作るアイデア（フェーズ 2 以降）

- **キュー表**：「開場 18:00」「開演 18:30」など複数の目標時刻を登録し、次のキューまでを自動でカウントダウン。Dynamic Island には常に「次のキュー名＋残り」
- **タイムコード表示**：映像用の `HH:MM:SS:FF`（FF＝フレーム数。24 / 25 / 29.97DF / 30 / 60）
- **外部モニター出力**：iPad / iPhone を HDMI で繋ぐと、モニターには時計だけを全画面表示（舞台袖モニター用）
- **夜間モード**：赤一色表示（暗い客席・舞台袖で目立たない）
- **複数端末の同期確認**：同じ Wi-Fi の端末同士で「ずれ ms」を表示
- **ウィジェット**：ホーム画面・StandBy（充電中の横置き表示）・Apple Watch の文字盤（コンプリケーション）
- **毎分・毎時のタップ**：Watch が毎正分に「コツ」と振動
- **大文字モード**：ミリ秒を消して秒までを最大サイズに

### 3.3 非機能要件

- 時刻表示の遅れ：見た目で分からないこと（描画は画面更新と同期）
- 電池：フローティング・常時点灯中でも 1 時間で極端に減らないこと（実機で測定）
- オフラインでも動く（NTP できない時は「未補正」と明示）
- 個人情報は扱わない。アカウント不要。通信は NTP のみ

---

## 4. 技術選定

### 4.1 比較表

| 観点 | **Swift＋SwiftUI**（おすすめ） | React Native（Expo） | Flutter |
|---|---|---|---|
| 動作の軽さ | ◎ OS 標準 | ○ | ○ |
| 配布サイズ | ◎ 小さい | △ 大きめ | △ 大きめ |
| 作りやすさ | ○ | ○（画面は速い） | ○ |
| 対応 OS | iPhone / iPad / Watch すべて | Watch・Dynamic Island・PiP は結局 Swift で書く必要あり | 同左 |
| 将来性 | ◎ Apple 公式 | ○ | ○ |
| AI での書きやすさ | ○ | ◎ | ○ |

**おすすめ：Swift＋SwiftUI**
理由：Apple Watch アプリ・Live Activity（Dynamic Island）・PiP はどれも Swift でしか書けない部分。全体の 7 割以上が Swift 専用機能になるため、他を選ぶ利点がない。

### 4.2 バージョン（2026-11-15 時点で公式確認）

| 項目 | 採用 | 根拠 |
|---|---|---|
| Xcode | **27.2**（最新の正式版、2026-10-29） | Apple Developer News / Xcode 27.2 リリースノート |
| Swift | **6.4**（Xcode 27.2 に同梱） | Xcode 27.2 リリースノート |
| SDK | iOS / iPadOS / watchOS **27.2** | 同上 |
| 最低対応 OS | **iOS 18.0 / iPadOS 18.0 / watchOS 11.0** | Dynamic Island でミリ秒表示に使う `SystemFormatStyle.Stopwatch` と `TimeDataSource` が iOS 18 / watchOS 11 から |
| ビルド環境 | GitHub Actions `runs-on: xcode-27`（Apple Silicon、正式提供 2026-10-15） | GitHub Changelog |
| プロジェクト生成 | **XcodeGen**（設定ファイル `project.yml` から Xcode プロジェクトを CI 上で自動生成） | Mac が無いため、手書きの Xcode プロジェクトファイルを避ける。※Xcode 27.2 で新しい JSON 形式 `.xcproj` も登場したが、Linux 上で検証できないので見送り |
| 外部ライブラリ | **使わない**（NTP も自作の小さな実装） | 依存を増やさない |

---

## 5. 画面構成

SVG デザイン：`docs/svg/` 以下

| # | 画面 | ファイル |
|---|---|---|
| S1 | iPhone メイン（時計モード） | `01-iphone-main.svg` |
| S2 | iPhone カウントダウン／ストップウォッチ | `02-iphone-modes.svg` |
| S3 | Dynamic Island（小・大）／ロック画面／フローティング | `03-island-pip.svg` |
| S4 | Apple Watch（通常・腕下げ時） | `04-watch.svg` |
| S5 | iPad 横向き（時計＋キュー） | `05-ipad.svg` |
| S6 | **時計だけモード**（縦・横・触れた時・設定） | `06-clock-only.svg` |

### 画面の流れ
```
起動 → 時計だけモード（S6）
        │   └─ 画面に触れる（または長押し）→ 操作部が 3 秒表示
        │        └─「メニューへ」→ メイン
        メイン（S1）
        ├─ 右上「時計だけ」ボタン → 時計だけモードへ
        ├─ 下のタブで切替：時計 ／ カウントダウン ／ ストップウォッチ
        ├─ 右上「小窓」ボタン → フローティング開始
        ├─ 右上「島」ボタン   → Dynamic Island 表示 開始／停止
        ├─ 上部の同期表示をタップ → 今すぐ NTP 同期
        └─ 右上 歯車 → 設定（NTP サーバー、24/12 時間、ミリ秒表示、色、スリープ防止）
```

### 配色（自作ツールのため自由配色）
| 用途 | 色 |
|---|---|
| 背景 | `#0B0D10` |
| 面（カード） | `#16191E` |
| 境界線 | `#262A31` |
| 時刻の数字 | `#F5F7FA` |
| 1/100 秒の数字 | `#FFB020`（琥珀色：一目で「小数部」と分かる） |
| 補助文字 | `#8A919C` |
| 同期 OK | `#30D158` ／ 注意 `#FFD60A` ／ 危険 `#FF453A` |

文字：数字は SF Pro の等幅数字（`.monospacedDigit()`、桁が変わっても横揺れしない）、日本語はシステム標準（ヒラギノ）。

---

## 6. 部品の分け方（コンポーネント）

| 部品 | 役割 | 使う場所 |
|---|---|---|
| `ClockDigitsView` | `HH:MM:SS` ＋ 小さめ琥珀色 `.cc` を描く。大きさ・ミリ秒有無を引数で | 全画面 |
| `SyncBadge` | 「NTP ±12ms ・ 3 分前」バッジ。色で状態 | iPhone / iPad |
| `ModeTabBar` | 時計／カウントダウン／ストップウォッチ | iPhone / iPad |
| `CountdownView` | 目標時刻・残り時間・色変化 | 全部 |
| `StopwatchView` | 開始／停止／ラップ | 全部 |
| `GenbaLiveActivity` | Dynamic Island とロック画面の表示（ウィジェット拡張） | iPhone |
| `PiPClockController` | PiP 用に時計の絵を作り続けて小窓に流す | iPhone / iPad |
| `ClockOnlyView` | 時計だけモード。縦は時・分・秒を 3 段、横は 1 行で最大化。触れた時の操作部の出し入れ | iPhone / iPad |
| `WatchClockView` | 腕下げ（常時表示）時は秒までに切替 | Watch |

---

## 7. 状態管理・時刻の仕組み

### 7.1 時刻の正しさ
```
表示時刻 = 端末の現在時刻 + ずれ量(offset)
```
- `NTPClient`：UDP 123 番で NTP サーバー（初期値 `time.apple.com`、設定で変更可）に 8 回問い合わせ、**往復時間が一番短い回** の offset を採用。精度 = 往復時間 ÷ 2
- 端末の時計が手動で変更されたら（`NSSystemClockDidChange` 通知）自動で再同期
- 同期のタイミング：起動時・アプリに戻った時・手動・30 分ごと（アプリ表示中のみ）

### 7.2 Dynamic Island でミリ秒を出す工夫
Live Activity はアプリから 1 秒に何回も更新できない（iOS 18 で Apple が「リアルタイム表示用ではない」と明言）。
そこで **OS 自身に数えさせる**：
```swift
// 「今日 0:00 から測るストップウォッチ」＝ 現在時刻そのもの
Text(.currentDate, format: .stopwatch(startingAt: 今日0時 - offset))
// → "12:34:56.78" と OS が自動で進める（はず）
```
- offset を引いておくことで NTP 補正済みの時刻になる
- 制約：Live Activity は最長 8 時間で OS に終了される 【事実】 → 終了を検知したら、アプリを開いた時に再開ボタンを出す
- 日付をまたぐと `24:00:00.00` 以降の表示になる 【推測】 → 0 時をまたいだら開き直しで再開
- **ロック画面・画面消灯中は秒以下の更新が止まる可能性** 【推測（開発者報告）】 → 試作で最初に検証する（第 9 章）

### 7.3 フローティング（PiP）の仕組み
- `AVSampleBufferDisplayLayer`（映像の 1 コマを自分で流し込める部品）に、時計の絵を 1 秒 60 回作って流す
- PiP にはバックグラウンド再生の設定（Audio, AirPlay, and Picture in Picture）が必要 【推測：一般的な実装例より】
- 審査リスク：時計だけを PiP に出すアプリは過去に却下例あり（後に承認） → **設定で ON にする「おまけ機能」扱い**にし、却下されたら外して出せる作りにする

### 7.4 Apple Watch
- Watch は NTP 不可 【事実】 → iPhone で測った offset を WatchConnectivity で受け取る。受け取れない時は Watch 自身の時計（iPhone と自動で合っている）をそのまま使い「未補正」表示
- 腕を上げている間：`TimelineView(.animation)` で 1/100 秒表示
- 腕を下ろした時（`isLuminanceReduced`＝画面が暗くなった状態）：秒までの表示に自動切替。更新は最大 1 秒ごと 【事実】

### 7.5 状態の持ち方
| 状態 | 持ち主 | 保存 |
|---|---|---|
| offset・精度・最終同期時刻 | `TimeSyncStore`（`@Observable`） | メモリ（＋最後の値を UserDefaults） |
| 現在モード | `AppState` | UserDefaults |
| カウントダウン目標・ストップウォッチ開始時刻・ラップ | `TimerStore` | UserDefaults（App Group で拡張と共有） |
| 設定（時計だけモードの「起動時に開く」「1/100 秒」「点」「日付」「開き方」を含む） | `SettingsStore` | UserDefaults |

ストップウォッチ・カウントダウンは「開始した時刻」だけを保存し、表示時に毎回計算する（アプリを閉じても狂わない）。

---

## 8. データ構造

```swift
struct TimeSync: Codable {
    var offset: Double          // 秒。表示時刻 = Date() + offset
    var accuracy: Double        // 秒（± 往復時間/2）
    var syncedAt: Date?         // 最終同期
    var server: String
}

struct Countdown: Codable {
    var label: String           // 例："本番"
    var target: Date
}

struct Stopwatch: Codable {
    var startedAt: Date?        // 動作中なら開始時刻
    var accumulated: Double     // 一時停止までの経過秒
    var laps: [Double]
}

// Live Activity に渡すデータ（4KB 以内）
struct GenbaActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mode: Mode          // .clock / .countdown / .stopwatch
        var offset: Double
        var target: Date?       // カウントダウン時
        var label: String?
    }
}
```

---

## 9. 開発の進め方（最初に危ない所を確かめる）

| 順 | 内容 | 確認方法 |
|---|---|---|
| 0 | **試作：Dynamic Island でミリ秒が動くか**、ロック中どうなるか | TestFlight で実機。ここで不可なら「Dynamic Island は秒まで」に設計変更 |
| 1 | GitHub Actions でビルド → TestFlight 配布の流れを作る | iPhone の TestFlight アプリで入る |
| 2 | iPhone メイン・NTP 補正 | 時報（117 等）や他端末と見比べ |
| 3 | カウントダウン・ストップウォッチ | 自動テスト（時刻計算） |
| 4 | Live Activity 本実装 | 実機 |
| 5 | PiP | 実機・電池消費測定 |
| 6 | Apple Watch | 実機 |
| 7 | iPad レイアウト | シミュレーターのスクリーンショットを CI で撮って確認 |

### Mac なしで必要になるもの（実装時に手順を書きます）
- Apple Developer Program（年額。料金は登録時に公式で確認）
- App Store Connect の API キー → GitHub の「Secrets」に登録
- 実機確認は TestFlight（iPhone・Watch とも TestFlight アプリ経由で入る）

---

## 10. フォルダ構成

```
genba-tokei/
├─ project.yml                 … XcodeGen 設定（ターゲット定義）
├─ Shared/                     … iPhone・Watch・拡張で共通
│   ├─ Time/NTPClient.swift
│   ├─ Time/TimeSyncStore.swift
│   ├─ Time/ClockMath.swift   … 表示用の計算（テスト対象）
│   ├─ Models/(Countdown, Stopwatch, Settings).swift
│   └─ UI/ClockDigitsView.swift
├─ App/                        … iPhone / iPad アプリ
│   ├─ GenbaTokeiApp.swift
│   ├─ Screens/(Main, Countdown, Stopwatch, Settings)View.swift
│   ├─ PiP/PiPClockController.swift
│   └─ Info.plist
├─ LiveActivity/               … Dynamic Island 用ウィジェット拡張
│   └─ GenbaLiveActivity.swift
├─ Watch/                      … Apple Watch アプリ
│   └─ WatchClockView.swift
├─ Tests/                      … 時刻計算などの自動テスト
├─ docs/
│   ├─ design.md               … この設計書
│   └─ svg/                    … デザイン
└─ .github/workflows/
    ├─ build.yml               … 変更のたびにビルド＋テスト
    └─ testflight.yml          … TestFlight へ配布
```

---

## 11. 根拠 URL

- Live Activity 公式解説（8 時間制限・4KB 制限）：https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- `SystemFormatStyle.Stopwatch`（標準で 1/100 秒表示、iOS 18〜）：https://developer.apple.com/documentation/swiftui/systemformatstyle/stopwatch
- `TimeDataSource`（Live Activity 内で自動更新、iOS 18〜）：https://developer.apple.com/documentation/swiftui/timedatasource
- iOS 18 で Live Activity のリアルタイム更新が制限（Apple の回答の紹介記事・二次情報）：https://www.idownloadblog.com/2024/09/03/ios-18-live-activities-no-real-time-updates/
- ロック中に秒が止まる報告（開発者の PR・二次情報）：https://github.com/KhaytApp/Khayt/pull/1903
- watchOS の低レベル通信制限 TN3135：https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos
- watchOS 常時表示の設計：https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state
- PiP タイマーアプリの却下→承認事例：https://mjtsai.com/blog/2020/09/30/pop-out-timer-rejected-from-the-app-store/
- PiP の独自コンテンツ（WWDC21）：https://developer.apple.com/videos/play/wwdc2021/10290/
- Xcode 27.2 リリースノート（Swift 6.4・SDK 27.2）：https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes
- Apple 最新リリース一覧：https://developer.apple.com/news/releases/
- GitHub Actions Xcode 27 ランナー正式提供：https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available
- 120Hz 用 Info.plist キー（二次情報）：https://appleinsider.com/articles/21/09/25/apple-tells-developers-how-to-use-120hz-promotion-for-iphone-13-pro

### 確認できなかったこと
- Dynamic Island で 1/100 秒が実際に滑らかに動くか（公式に「更新される」とあるが頻度の記載なし）
- 時計だけを出す PiP が現在の審査で通るか
- iPad の Live Activity 対応 OS バージョン（情報源が食い違う）
- 120Hz キーが現行機種で効くか

# iPhone に試作を入れるまで（あなたの作業は 3 つだけ）

Mac は使いません。下の 3 つ以外（アプリの住所＝Bundle ID の登録、チーム ID の取得、ビルド、署名、アップロード、TestFlight のテスト用グループへの追加）は、Claude が GitHub の自動処理で行います。

> **なぜこの 3 つだけは代われないのか**
> - Apple のサイトへのログイン（2 段階認証）はあなた本人にしかできない
> - アプリの枠の作成は、Apple が自動処理での作成を認めていない（Web 画面からのみ）
> - GitHub の Secrets（秘密の値の保管庫）に書き込む手段を Claude が持っていない。また、秘密の値をチャットに貼るのは安全ではない

---

## 作業 1：API キーを作る（App Store Connect）
※ Apple Developer Program に未加入なら、先に iPhone の「Apple Developer」アプリ →「アカウント」→「今すぐ登録」。年会費は登録画面で確認してください。

1. https://appstoreconnect.apple.com/access/integrations/api を開く
2. 「チームキー」タブ（初回は「アクセスをリクエスト」→ 承諾）
3. 「＋」→ 名前：`GitHub Actions` ／ アクセス：**Admin** →「生成」
   - Admin が必要な理由：配布用の証明書を自動で作るため（Admin 未満では失敗する報告が多い。Apple 公式の明記は見つからず）
4. 次の 3 つを控える
   - **キー ID**：作ったキーの行に表示
   - **Issuer ID**：表の上に表示（コピーボタンあり）
   - **API キー本体**：「API キーをダウンロード」→「ファイル」アプリに `AuthKey_XXXX.p8` が保存される（**ダウンロードは 1 回だけ**）
5. `.p8` の中身をコピー：「ファイル」アプリで長押し →「名称変更」で末尾を `.txt` に → タップで開く → 全選択してコピー
   （`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで全部。iPhone 実機でこの方法が使えるかは未確認）

## 作業 2：GitHub に預ける
https://github.com/kajisho5/genba-tokei/settings/secrets/actions →「New repository secret」で 3 つ登録

| Name（そのまま入力） | Secret |
|---|---|
| `ASC_KEY_ID` | キー ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | `.p8` の中身全部 |

→ 終わったら Claude に「登録した」と伝える。Claude が準備の処理を動かして **Bundle ID `io.github.kajisho5.genbatokei` を登録** します。

## 作業 3：アプリの枠を作る（Claude から「Bundle ID 登録完了」の連絡が来てから）
1. https://appstoreconnect.apple.com/apps →左上「＋」→「新規 App」
2. プラットフォーム：iOS ／ 名前：`現場時計`（他人と重複したら `現場時計 試作` など）／ 言語：日本語 ／ バンドル ID：`io.github.kajisho5.genbatokei` を選ぶ ／ SKU：`genbatokei` ／ ユーザアクセス：フルアクセス →「作成」

→ Claude に「作った」と伝える。Claude がビルド → アップロード → テスト用グループへの追加まで行います（20〜40 分）。

## 最後：iPhone に入れる
1. App Store で「TestFlight」アプリを入れる
2. Apple から招待のメール（または TestFlight アプリ内の通知）が届いたら「インストール」

## 試作で確かめること
アプリ画面下の「確認してほしいこと」6 項目。結果（動いた／止まった／何秒で止まった）を Claude に伝えてください。

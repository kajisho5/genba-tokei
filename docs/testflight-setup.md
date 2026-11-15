# iPhone に試作を入れるまでの準備（iPhone だけでできる手順）

Mac は使いません。ビルドと署名は GitHub Actions（GitHub 上の Mac）が行います。
一度設定すれば、以後は GitHub のボタン 1 つで TestFlight に届きます。

> 用語
> - **TestFlight**：App Store に出す前のアプリを自分の iPhone に入れる Apple 公式アプリ
> - **Bundle ID**：アプリの住所のような名前。`com.（自分の名前など）.genbatokei` の形
> - **Secrets**：GitHub に預ける秘密の値。一度入れると誰にも（自分にも）見えなくなる

---

## 1. Apple Developer Program に入っているか確認
- 確認：https://developer.apple.com/account （ログイン →「メンバーシップの詳細」）
- 未加入なら iPhone の「Apple Developer」アプリ →「アカウント」→「今すぐ登録」。年会費は登録画面で確認してください
- 「メンバーシップの詳細」にある **チーム ID**（英数字 10 文字）をメモ

## 2. Bundle ID を登録する
1. https://developer.apple.com/account/resources/identifiers/add/bundleId を開く
2. 「App IDs」を選んで「Continue」→「App」→「Continue」
3. Description：`GenbaTokei`
4. Bundle ID：「Explicit」を選び `com.（自分の名前など）.genbatokei` と入力
   - 例：`com.example-name.genbatokei`（`com.（自分の名前など）` の部分を **BUNDLE_ID_PREFIX** として後で使う）
5. 「Continue」→「Register」
   - Dynamic Island 用の部品（`….genbatokei.liveactivity`）は GitHub 側で自動登録されます

## 3. App Store Connect にアプリの枠を作る
1. https://appstoreconnect.apple.com/apps を開く
2. 左上「＋」→「新規 App」
3. プラットフォーム：iOS ／ 名前：`現場時計`（他人と重複不可。重複したら `現場時計 試作` など）／ 言語：日本語 ／ バンドル ID：2 で作ったもの ／ SKU：`genbatokei` ／ アクセス：フルアクセス
4. 「作成」

## 4. App Store Connect の API キーを作る
1. https://appstoreconnect.apple.com/access/integrations/api を開く
2. 「チームキー」タブ → 初回は「アクセスをリクエスト」→ 承諾
3. 「＋」→ 名前：`GitHub Actions` ／ アクセス：**Admin**
   - Admin が必要な理由：GitHub 側で配布用の証明書を自動で作るため。Admin 未満では失敗するという報告が多い（Apple 公式の明記は見つからず）
4. 「生成」→ 表で次の 2 つをメモ
   - **キー ID**（キーの行に表示）
   - **Issuer ID**（表の上に表示）
5. 「API キーをダウンロード」→ `AuthKey_XXXX.p8` が「ファイル」アプリに保存される
   - **ダウンロードは 1 回だけ**。なくしたらキーを作り直し
6. `.p8` の中身（`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで全部）をコピーする
   - 「ファイル」アプリでそのまま開けない場合：長押し →「名称変更」で末尾を `.txt` に変更 → タップで開く → 全選択してコピー（この方法は iPhone 実機では未確認）

## 5. GitHub に預ける
**Secrets**（https://github.com/kajisho5/genba-tokei/settings/secrets/actions）
→「New repository secret」を押して 1 つずつ登録：

| Name | Secret に入れるもの |
|---|---|
| `APPLE_TEAM_ID` | 1 のチーム ID |
| `ASC_KEY_ID` | 4 のキー ID |
| `ASC_ISSUER_ID` | 4 の Issuer ID |
| `ASC_KEY_P8` | 4 でコピーした `.p8` の中身全部 |

**Variables**（https://github.com/kajisho5/genba-tokei/settings/variables/actions）
→「New repository variable」：

| Name | Value |
|---|---|
| `BUNDLE_ID_PREFIX` | 2 の `com.（自分の名前など）` 部分（例 `com.example-name`） |

## 6. TestFlight に送る
> 「Run workflow」ボタンは、設定ファイルが main ブランチに入ってから表示されます（GitHub の仕様）。先に変更依頼（プルリクエスト）を main に取り込んでください。

1. https://github.com/kajisho5/genba-tokei/actions/workflows/testflight.yml を開く
2. 右の「Run workflow」→ 緑の「Run workflow」
3. 約 10〜20 分で完了（緑のチェック）。その後 Apple 側の処理に数分〜数十分

## 7. iPhone に入れる
1. https://appstoreconnect.apple.com/apps → 現場時計 →「TestFlight」タブ
2. 左の「内部テスト」の「＋」→ グループ名（例：`自分`）→ 自分を追加
3. ビルドがグループに追加されると、メールまたは TestFlight アプリに招待が届く
4. App Store から「TestFlight」アプリを入れて、現場時計を「インストール」

## 8. 試作で確かめること
アプリ画面下の「確認してほしいこと」の 6 項目です。結果（動いた／止まった／何秒で止まった）を教えてください。

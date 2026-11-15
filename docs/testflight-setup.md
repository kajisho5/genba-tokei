# iPhone に試作を入れるまで

配布は他のアプリと同じく **kajisho5/runway** の共通ワークフローで行う（鍵などの Secrets も runway が自動で配る）。

| # | 作業 | 誰が | 状態 |
|---|---|---|---|
| 1 | Bundle ID を登録（`com.seventhwell.GenbaTokei` と `com.seventhwell.GenbaTokei.LiveActivity`） | Claude（runway の apple-bundle-id） | 実行済み |
| 2 | Secrets を配る（runway の `repos.txt` に追加） | Claude | 実行済み |
| 3 | **アプリ記録を作る** | **人** | ↓ |
| 4 | TestFlight に送る（Actions → testflight） | Claude | 3 のあと |
| 5 | 内部テストのグループ作成・テスター追加 | 自動（送信のあと） | — |
| 6 | 実機で確認 | 人 | — |

## 3. アプリ記録を作る（あなたの作業はこれだけ）
Apple が API での作成を許していないため、Web の画面でしか作れない。

1. https://appstoreconnect.apple.com/apps →左上「＋」→「新規 App」
2. プラットフォーム：iOS ／ 名前：`現場時計`（他人と重複したら `現場時計 試作` など）／ 言語：日本語 ／ バンドル ID：`com.seventhwell.GenbaTokei` を選ぶ ／ SKU：`genbatokei` ／ ユーザアクセス：フルアクセス →「作成」
3. Claude に「作った」と伝える

## 6. 実機で確認
TestFlight アプリに現場時計が出たら「インストール」。出てこなければ runway の testflight-check（`repo` に `kajisho5/genba-tokei`）。
アプリ画面下の「確認してほしいこと」6 項目の結果を Claude に伝える。

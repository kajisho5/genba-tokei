# 紹介ページ（LP）詳細設計書 v0.1

作成日：2026-11-15 ／ 状態：**確認待ち（Step 2 まで完了・実装前）**
デザイン：`docs/site/lp-design.svg`（左＝パソコン幅 1440px、右＝スマホ幅 390px）

---

## 1. 目的
- 現場時計アプリを紹介し、TestFlight（公開前のアプリを試す仕組み）への参加と GitHub への誘導をする
- **islandcn**（Dynamic Island そっくりの動きを Web で再現する部品集）で、島の動きをブラウザ上で体験してもらう

## 2. 要件

| ID | 内容 |
|---|---|
| L1 | ヒーロー（最初の画面）：見出し・説明・ボタン 2 つ・スマホの絵。スマホの島には現在時刻が 1/100 秒で進む |
| L2 | 「このページの時計」：ブラウザの時刻をそのまま 1/100 秒表示（**NTP 補正はしない**。端末の時刻であることを明記） |
| L3 | デモ：ボタン 4 つで島を切替（時計／本番までカウントダウン／展開／2 つ同時）。島の長押しでも展開 |
| L4 | 特長カード 6 枚（補正・Dynamic Island・小窓・時計だけ・カウントダウン・Apple Watch） |
| L5 | オペレーター向けの使い方 3 つ ＋ 横置きスマホの絵 |
| L6 | 開発状況（設計 → 試作 → TestFlight → App Store）。いまどこかを色で示す |
| L7 | 注意書き：島はブラウザ上の再現であること、Apple と無関係であること、islandcn のライセンス表記 |
| L8 | スマホ幅で 1 列に並び替え。横にはみ出さない |
| L9 | 「動きを減らす」設定の人には島の動きを控えめにする（islandcn に標準で入っている機能） |

### 正直に書くこと（誇大表示をしない）
- 「Dynamic Island で 1/100 秒」は **実機で検証中** と書く（試作の結果が出たら更新）
- TestFlight ボタンは準備ができるまで「準備中」で押せない状態

## 3. 技術選定

### 比較表
| 観点 | **Astro＋React（islandcn 部分のみ）**（おすすめ） | Next.js（静的書き出し） | Vite＋React だけ |
|---|---|---|---|
| 動作の軽さ | ◎ 島の部分だけ JavaScript を読む | ○ ページ全体が React | ○ ページ全体が React |
| 配布サイズ | ◎ 小さい | △ 大きめ | ○ |
| 作りやすさ | ○ | ○ | ◎ |
| 公開のしやすさ | ◎ GitHub Pages 公式手順あり | ○ | ○ |
| 将来性 | ◎ | ◎ | ○ |
| AI での書きやすさ | ○ | ◎ | ◎ |

**おすすめ：Astro**。表示中心のページで、動くのは島とデジタル時計だけ。その部分だけ React で動かせば最も軽い。islandcn は React だけで動く（外部ライブラリなし）ことを中身で確認済み。

### バージョン（2026-11-15 に npm で確認）
| 項目 | バージョン |
|---|---|
| Astro | 7.4.12 |
| @astrojs/react | 7.1.9 |
| React / React DOM | 19.3.1 |
| Tailwind CSS（＋ @tailwindcss/vite） | 4.3.5 |
| shadcn（islandcn の取り込みに使う） | 4.23.0 |
| islandcn | 版番号の公開なし → 取り込んだ日付とファイルをそのまま記録して固定 |
| Node.js | 22.23 以上（Astro の要求） |

### 公開先
**GitHub Pages**（無料。このリポジトリは公開設定なので追加費用なし）
- URL：`https://kajisho5.github.io/genba-tokei/`
- main に取り込まれると GitHub Actions が自動で作って公開
- 初回だけ設定が必要：https://github.com/kajisho5/genba-tokei/settings/pages →「Build and deployment」の「Source」を **GitHub Actions** に変更

候補だった Cloudflare：独自ドメインやアクセス解析が要るなら移行を提案します。今は不要と判断。

### フォント
Web フォントは読み込まない（軽さ優先）。Mac/iPhone はヒラギノと SF、Windows は Meiryo/Segoe、Android は Noto が使われる。数字は `font-variant-numeric: tabular-nums`（桁幅をそろえて揺れない）。

## 4. 画面構成（上から）
1. ナビ：ロゴ／特長・デモ・開発状況・GitHub／TestFlight（準備中）。スマホはメニューボタン
2. ヒーロー：見出し「1/100秒まで、現場の全員が同じ時刻。」＋ スマホの絵（時計だけモード）＋ 島
3. デモ：島の舞台 ＋ 切替ボタン 4 つ
4. 特長：3 列×2 段（スマホは 1 列）
5. オペレーターのために
6. 開発状況
7. フッター（注意書き・ライセンス）

## 5. 部品の分け方
| 部品 | 種類 | 動き |
|---|---|---|
| `Nav.astro` / `Hero.astro` / `Features.astro` / `Operators.astro` / `Status.astro` / `Footer.astro` | Astro（JavaScript なし） | なし |
| `PhoneMock.astro` | Astro（CSS で描いたスマホの枠。Apple の画像は使わない） | なし |
| `LiveClock.tsx` | React | ブラウザ時刻を画面更新ごとに表示 |
| `HeroIsland.tsx` | React ＋ islandcn | 島に現在時刻（コンパクト表示） |
| `IslandDemo.tsx` | React ＋ islandcn | ボタンで表示切替 |
| `src/lib/island/` | islandcn 本体（shadcn で取り込み） | — |

## 6. 状態管理
- デモの選択中ボタン：`IslandDemo` 内の `useState` だけ（保存しない）
- 時刻：`requestAnimationFrame`（画面の書き換えごとの合図）で `Date.now()` を読む。タブが裏にある間はブラウザが自動で止める

## 7. データ
固定の文章のみ（特長・使い方・開発状況）。`src/content/site.ts` に配列でまとめ、更新しやすくする。

## 8. フォルダ構成
```
site/
├─ package.json / astro.config.mjs / tsconfig.json / components.json
├─ public/favicon.svg
└─ src/
   ├─ pages/index.astro
   ├─ components/（上の部品）
   ├─ lib/island/（islandcn）
   ├─ content/site.ts
   └─ styles/global.css
.github/workflows/pages.yml   … main に入ったら公開
```

## 9. 動作確認の方法（実装時）
- ビルドが通ること
- Playwright（ブラウザ自動操作）でパソコン幅・スマホ幅の画面写真を撮り、デザインと見比べる
- 横にはみ出しがないこと、デモの 4 ボタンで島が切り替わること、時計が進むこと

## 10. 根拠 URL
- islandcn：https://github.com/opencoredev/islandcn （MIT、React と React DOM のみに依存＝取り込みファイルの README で確認）
- Astro を GitHub Pages に公開：https://docs.astro.build/en/guides/deploy/github/
- npm の各パッケージ：https://www.npmjs.com/package/astro ほか

### 確認できなかったこと
- islandcn の版番号・更新日（GitHub ページに表示なし）
- islandcn が Astro 上で問題なく動くか（React 部品なので動く見込み。実装時に確認）

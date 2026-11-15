// ページの文章（更新しやすいようにここにまとめる）
export const repoUrl = "https://github.com/kajisho5/genba-tokei";

export const features = [
  { icon: "sync", title: "時刻を自動で補正", lines: ["ネットの時刻サーバーに問い合わせて、", "端末のずれと誤差（±ms）を表示。"] },
  { icon: "island", title: "Dynamic Island", lines: ["ホーム画面でも上の島に時刻。", "1/100秒表示は実機で検証中。"] },
  { icon: "pip", title: "小窓で表示", lines: ["台本や進行表を見ながら、", "時計を画面の上に浮かべる。"] },
  { icon: "clock", title: "時計だけモード", lines: ["ボタンも文字も消して、時刻だけを", "画面いっぱいに。誤操作も防止。"] },
  { icon: "countdown", title: "本番までカウントダウン", lines: ["残り5分で黄、1分で赤。", "0秒で振動してお知らせ。"] },
  { icon: "watch", title: "Apple Watch", lines: ["手首でも同じ時刻。iPhoneで測った", "ずれを受け取って補正。"] },
] as const;

export const operatorUses = [
  "舞台袖：横置きで、離れた所からも読める大きな数字",
  "配信・収録卓：小窓で進行表と並べて確認",
  "撮影現場：全員の端末の時刻を±数十ミリ秒にそろえる",
] as const;

export type StepState = "done" | "now" | "todo";
export const steps: { label: string; state: StepState }[] = [
  { label: "設計・デザイン", state: "done" },
  { label: "試作（いまここ）", state: "now" },
  { label: "TestFlight 公開", state: "todo" },
  { label: "App Store", state: "todo" },
];

import { useEffect, useRef } from "react";
import { Island, IslandProvider, useIsland } from "@/lib/island";
import { clockActivity, countdownActivity, islandMetrics } from "./activities";

type Mode = "clock" | "countdown" | "expanded" | "both";

const modes: { key: Mode; label: string }[] = [
  { key: "clock", label: "時計" },
  { key: "countdown", label: "カウントダウン" },
  { key: "expanded", label: "展開" },
  { key: "both", label: "2つ同時" },
];

/** デモ：ボタンで島の表示を切り替える */
export default function IslandDemo() {
  return (
    <IslandProvider metrics={islandMetrics}>
      <Demo />
    </IslandProvider>
  );
}

function Demo() {
  const island = useIsland();
  const target = useRef(0);

  useEffect(() => {
    target.current = Date.now() + 25 * 60 * 1000 + 3_000;
    island.start(clockActivity());
    return () => {
      island.end("clock");
      island.end("countdown");
    };
    // 最初の 1 回だけ
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const ids = island.activities.map((a) => a.id);
  const current: Mode =
    island.presentation === "expanded"
      ? "expanded"
      : ids.length >= 2
        ? "both"
        : ids[0] === "countdown"
          ? "countdown"
          : "clock";

  const choose = (mode: Mode) => {
    if (target.current - Date.now() < 0) target.current = Date.now() + 25 * 60 * 1000;
    switch (mode) {
      case "clock":
        island.collapse();
        island.end("countdown");
        island.start(clockActivity());
        break;
      case "countdown":
        island.collapse();
        island.end("clock");
        island.start(countdownActivity(target.current));
        break;
      case "expanded": {
        const id = ids.includes("countdown") && !ids.includes("clock") ? "countdown" : "clock";
        if (!ids.includes(id)) island.start(clockActivity());
        island.expand(id);
        break;
      }
      case "both":
        island.collapse();
        island.start(clockActivity());
        island.start({ ...countdownActivity(target.current), priority: -1 });
        break;
    }
  };

  return (
    <div className="mx-auto w-full max-w-[700px]">
      <div className="relative mx-auto h-[230px] w-full max-w-[402px] overflow-hidden rounded-[28px] bg-[#1B1E23] sm:h-[260px]">
        <Island backdrop="#1B1E23" label="島の再現（デモ）" />
        <p className="absolute inset-x-0 bottom-4 text-center text-xs text-faint">島を長押しすると展開します</p>
      </div>
      <div
        role="group"
        aria-label="島の表示を切り替える"
        className="mx-auto mt-6 grid max-w-[640px] grid-cols-2 gap-2.5 sm:grid-cols-4 sm:gap-1 sm:rounded-2xl sm:border sm:border-border sm:bg-surface sm:p-1"
      >
        {modes.map((m) => {
          const active = current === m.key;
          return (
            <button
              key={m.key}
              type="button"
              aria-pressed={active}
              onClick={() => choose(m.key)}
              className={`min-h-12 rounded-xl px-3 text-[15px] transition-colors focus-visible:outline-2 focus-visible:outline-accent ${
                active
                  ? "bg-[#2A2F37] font-semibold text-text"
                  : "border border-border bg-surface text-sub hover:text-text sm:border-0 sm:bg-transparent"
              }`}
            >
              {m.label}
            </button>
          );
        })}
      </div>
      <p className="mt-4 text-center text-xs text-faint">
        ※ ブラウザ上の再現です。実機の Dynamic Island の表示は Apple の仕様に従います。
      </p>
    </div>
  );
}

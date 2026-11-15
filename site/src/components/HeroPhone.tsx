import { useEffect } from "react";
import { Island, IslandProvider, useIslandActions } from "@/lib/island";
import { clockActivity, islandMetrics } from "./activities";
import { clockParts, useNow } from "./time";

/** ヒーローのスマホの絵。画面は「時計だけモード」、上の島に現在時刻。 */
export default function HeroPhone() {
  return (
    <IslandProvider metrics={islandMetrics}>
      <Phone />
    </IslandProvider>
  );
}

function Phone() {
  const island = useIslandActions();
  useEffect(() => {
    // 開いた直後に一度だけ広がって戻る（iOS の「お知らせ」と同じ動き）
    const timer = setTimeout(() => island.start({ ...clockActivity(), alert: true }), 900);
    return () => {
      clearTimeout(timer);
      island.end("clock");
    };
  }, [island]);

  const p = clockParts(useNow());
  return (
    <div className="mx-auto w-[min(362px,calc(100vw-96px))] rounded-[64px] bg-[#1F2329] p-3.5">
      <div
        className="relative aspect-[362/732] overflow-hidden rounded-[52px] bg-black [container-type:inline-size]"
        role="img"
        aria-label={`時計だけモードの画面例。${p.h}時${p.m}分${p.s}秒`}
      >
        <Island backdrop="#000000" label="島の再現（現在時刻）" />
        <div className="num absolute inset-0 flex flex-col items-center justify-center pt-[8cqw] font-semibold leading-[0.95] text-text">
          <span className="text-[39cqw]">{p.h}</span>
          <span className="text-[39cqw]">{p.m}</span>
          <span className="mt-[3cqw] text-[25cqw]">
            {p.s}
            <span className="text-[16cqw] text-accent">{p.fraction}</span>
          </span>
        </div>
        <span className="absolute right-[7%] top-[4.5%] size-2 rounded-full bg-ok/70" aria-hidden="true" />
      </div>
    </div>
  );
}

import { clockParts, useNow } from "./time";

/** オペレーター欄の横置きスマホ（時計だけモード） */
export default function LandscapeClock() {
  const p = clockParts(useNow());
  return (
    <div className="w-full max-w-[500px] rounded-[44px] bg-[#1F2329] p-2.5">
      <div
        className="num flex aspect-[480/216] items-center justify-center rounded-[36px] bg-black font-semibold [container-type:inline-size]"
        role="img"
        aria-label={`横置きの時計だけモードの例。${p.h}時${p.m}分${p.s}秒`}
      >
        <span className="text-[15.5cqw] text-text">{p.main}</span>
        <span className="text-[10cqw] text-accent">{p.fraction}</span>
      </div>
    </div>
  );
}

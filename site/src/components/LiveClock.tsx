import { clockParts, useNow } from "./time";

/** ヒーローの「このページの時計（お使いの端末の時刻）」 */
export default function LiveClock() {
  const p = clockParts(useNow());
  return (
    <div>
      <p className="flex items-center gap-2 text-sm text-sub">
        <span className="inline-block size-2.5 rounded-full bg-ok" aria-hidden="true" />
        このページの時計（お使いの端末の時刻）
      </p>
      <p className="num mt-1 font-semibold leading-none" aria-label={`${p.h}時${p.m}分${p.s}秒`}>
        <span className="text-[clamp(2.5rem,7vw,3.5rem)] text-text">{p.main}</span>
        <span className="text-[clamp(1.6rem,4.5vw,2.25rem)] text-accent">{p.fraction}</span>
      </p>
    </div>
  );
}

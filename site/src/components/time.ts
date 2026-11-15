import { useEffect, useState } from "react";

/** 画面の書き換えごとに現在時刻を返す（タブが裏にある間はブラウザが自動で止める） */
export function useNow(): Date | null {
  // サーバーで作る HTML には時刻を入れない（表示の食い違いを防ぐ）
  const [now, setNow] = useState<Date | null>(null);
  useEffect(() => {
    let id = 0;
    const tick = () => {
      setNow(new Date());
      id = requestAnimationFrame(tick);
    };
    id = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(id);
  }, []);
  return now;
}

const pad = (n: number) => String(n).padStart(2, "0");

export function clockParts(d: Date | null) {
  if (!d) return { h: "--", m: "--", s: "--", cs: "--", main: "--:--:--", fraction: ".--" };
  const h = pad(d.getHours());
  const m = pad(d.getMinutes());
  const s = pad(d.getSeconds());
  const cs = pad(Math.floor(d.getMilliseconds() / 10));
  return { h, m, s, cs, main: `${h}:${m}:${s}`, fraction: `.${cs}` };
}

/** 残り時間 "25:03" と 1/100 秒 ".22"（0 未満は 0） */
export function remainParts(target: number, now: Date | null) {
  if (!now) return { main: "--:--", fraction: ".--", seconds: 0 };
  const ms = Math.max(0, target - now.getTime());
  const total = Math.floor(ms / 1000);
  return {
    main: `${pad(Math.floor(total / 60))}:${pad(total % 60)}`,
    fraction: `.${pad(Math.floor((ms % 1000) / 10))}`,
    seconds: total,
  };
}

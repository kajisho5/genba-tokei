import { clockParts, remainParts, useNow } from "./time";

// 島の中に置く小さな部品。自分で時刻を進める。
const white = "#F5F7FA";
const amber = "#FFB020";

export function Dot({ color = "#30D158" }: { color?: string }) {
  return <span style={{ display: "block", width: 8, height: 8, borderRadius: 99, background: color }} aria-hidden="true" />;
}

export function IslandTime({ size = 14 }: { size?: number }) {
  const p = clockParts(useNow());
  return (
    <span className="num" style={{ fontWeight: 600, whiteSpace: "nowrap", color: white, fontSize: size }}>
      {p.main}
      <span style={{ color: amber, fontSize: size * 0.75 }}>{p.fraction}</span>
    </span>
  );
}

export function IslandRemain({ target, size = 14 }: { target: number; size?: number }) {
  const r = remainParts(target, useNow());
  const color = r.seconds < 60 ? "#FF453A" : r.seconds < 300 ? "#FFD60A" : white;
  return (
    <span className="num" style={{ fontWeight: 600, whiteSpace: "nowrap", color, fontSize: size }}>
      −{r.main}
      <span style={{ color: amber, fontSize: size * 0.75 }}>{r.fraction}</span>
    </span>
  );
}

export function SmallLabel({ children, color = "#8A919C" }: { children: React.ReactNode; color?: string }) {
  return <span style={{ fontSize: 12, color, whiteSpace: "nowrap" }}>{children}</span>;
}

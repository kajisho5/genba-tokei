import type { ActivityOptions } from "@/lib/island";
import { Dot, IslandRemain, IslandTime, SmallLabel } from "./IslandParts";

/** 島の幅の上限（標準 72）では "12:34:56.78" が切れるため広げる */
export const islandMetrics = { compact: { maxSlotWidth: 112 } };

export function clockActivity(): ActivityOptions {
  return {
    id: "clock",
    label: "現場時計：現在時刻",
    compact: { leading: <Dot />, trailing: <IslandTime /> },
    minimal: <Dot />,
    expanded: {
      leading: (
        <span style={{ display: "flex", alignItems: "center", gap: 6, height: 28 }}>
          <Dot />
          <SmallLabel color="#7FD49A">端末時刻</SmallLabel>
        </span>
      ),
      trailing: (
        <span style={{ display: "flex", alignItems: "center", height: 28 }}>
          <SmallLabel>現場時計</SmallLabel>
        </span>
      ),
      bottom: (
        <div style={{ textAlign: "center", padding: "2px 0 10px" }}>
          <IslandTime size={40} />
        </div>
      ),
    },
  };
}

export function countdownActivity(target: number): ActivityOptions {
  return {
    id: "countdown",
    label: "現場時計：本番までのカウントダウン",
    compact: { leading: <SmallLabel color="#FFD60A">本番</SmallLabel>, trailing: <IslandRemain target={target} /> },
    minimal: <Dot color="#FFD60A" />,
    expanded: {
      leading: (
        <span style={{ display: "flex", alignItems: "center", height: 28 }}>
          <SmallLabel color="#FFD60A">本番（サンプル）まで</SmallLabel>
        </span>
      ),
      bottom: (
        <div style={{ textAlign: "center", padding: "2px 0 10px" }}>
          <IslandRemain target={target} size={40} />
        </div>
      ),
    },
  };
}

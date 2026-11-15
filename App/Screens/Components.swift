import SwiftUI

/// 「NTP補正済み +0.142s ±12ms ・ 3分前」。タップで今すぐ同期
struct SyncBadge: View {
    @Environment(AppModel.self) private var model
    @Environment(TimeSyncStore.self) private var sync

    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let status = sync.status(at: context.date)
            Button {
                Task { await model.syncNow() }
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(status.color).frame(width: 10, height: 10)
                    Text(sync.badgeText(at: context.date))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(status == .ok ? Palette.okText : Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    if sync.isSyncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise").foregroundStyle(Palette.subText)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(status == .ok ? Palette.okBackground : Palette.surface, in: Capsule())
                .overlay(Capsule().stroke(status.color.opacity(0.45)))
            }
            .buttonStyle(.plain)
            .accessibilityHint("タップで今すぐ時刻を合わせる")
        }
        .overlay(alignment: .bottomLeading) {
            if let error = sync.lastError {
                Text(error).font(.caption).foregroundStyle(Palette.danger).offset(y: 20)
            }
        }
    }
}

extension TimeSyncStore.Status {
    var color: Color {
        switch self {
        case .ok: Palette.ok
        case .stale: Palette.warning
        case .unsynced: Palette.danger
        }
    }
}

extension TimeSyncStore {
    func badgeText(at date: Date) -> String {
        guard status(at: date) != .unsynced, let syncedAt else { return "未補正（端末の時計のまま）" }
        let minutes = Int(date.timeIntervalSince(syncedAt) / 60)
        let ago = minutes < 1 ? "今" : minutes < 60 ? "\(minutes)分前" : "\(minutes / 60)時間前"
        let sign = offset >= 0 ? "+" : "−"
        let ms = accuracyMs.map { " ±\($0)ms" } ?? ""
        return String(format: "NTP補正 %@%.3fs", sign, abs(offset)) + ms + " ・ " + ago
    }
}

extension CountdownState.Level {
    var color: Color {
        switch self {
        case .idle, .normal: Palette.text
        case .warning: Palette.warning
        case .danger, .done: Palette.danger
        }
    }
}

/// 経過・残り時間 "−00:04:59" ＋ 琥珀色 ".22"
struct DurationDigits: View {
    let main: String
    let fraction: String
    var size: CGFloat
    var color: Color = Palette.text
    var showsFraction = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(main).font(.system(size: size, weight: .semibold).monospacedDigit()).foregroundStyle(color)
            if showsFraction {
                Text(fraction).font(.system(size: size * 0.64, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Palette.accent)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.3)
    }
}

/// カード（面＋境界線）
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border))
    }
}

/// 上部の四角いアイコンボタン
struct SquareIconButton: View {
    let systemName: String
    let label: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? Palette.background : Palette.text)
                .frame(width: 44, height: 44)
                .background(active ? Palette.accent : Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

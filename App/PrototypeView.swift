import Combine
import SwiftUI
import UIKit

/// 試作画面：アプリ内の 1/100 秒表示と、Dynamic Island 表示の検証用
struct PrototypeView: View {
    @Environment(TimeSyncStore.self) private var sync
    @Environment(LiveActivityController.self) private var liveActivity
    @Environment(\.scenePhase) private var scenePhase
    @State private var precision: DisplayPrecision = .centiseconds
    @State private var showsClockOnly = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                SyncBadge()
                bigClock
                islandCard
                checklist
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Palette.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showsClockOnly) {
            ClockOnlyView()
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .task { await sync.sync() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await syncAndRefresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
            sync.invalidate()
            Task { await syncAndRefresh() }
        }
    }

    private var header: some View {
        HStack {
            Text("現場時計（試作）")
                .font(.headline)
                .foregroundStyle(Palette.text)
            Spacer()
            Button("時計だけ") { showsClockOnly = true }
                .buttonStyle(.bordered)
                .tint(Palette.accent)
        }
        .padding(.top, 8)
    }

    private var bigClock: some View {
        TimelineView(.animation) { context in
            ClockDigitsView(parts: ClockMath.parts(of: sync.now(context.date)), size: 62)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }

    private var islandCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dynamic Island 試験")
                .font(.headline)
                .foregroundStyle(Palette.text)
            Picker("表示の細かさ", selection: $precision) {
                ForEach(DisplayPrecision.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: precision) { _, _ in
                Task { await refreshIsland() }
            }
            Button {
                Task {
                    if liveActivity.isRunning {
                        await liveActivity.stop()
                    } else {
                        await liveActivity.start(offset: sync.offset,
                                                 accuracyMs: sync.accuracyMs,
                                                 precision: precision)
                    }
                }
            } label: {
                Text(liveActivity.isRunning ? "Dynamic Island 表示を止める" : "Dynamic Island に表示する")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(liveActivity.isRunning ? Palette.danger : Palette.accent)
            .foregroundStyle(Palette.background)
            if let message = liveActivity.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Palette.danger)
            }
        }
        .padding(18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border))
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("確認してほしいこと")
                .font(.headline)
                .foregroundStyle(Palette.text)
            ForEach(Self.checks, id: \.self) { item in
                Text("・" + item)
                    .font(.subheadline)
                    .foregroundStyle(Palette.subText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    static let checks = [
        "ホーム画面に戻った時、島の右側の 1/100 秒が動き続けるか",
        "島を長押しして広げた時も動くか",
        "ロック画面（画面は点いている状態）で動くか",
        "画面が消えて、再び点けた時にずれていないか",
        "アプリ内の時計と島の時計の数字が一致しているか",
        "1 分以上たっても動き続けるか（iOS 18 で 60 秒で止まる報告あり）",
    ]

    private func syncAndRefresh() async {
        await sync.sync()
        await refreshIsland()
    }

    private func refreshIsland() async {
        guard liveActivity.isRunning else { return }
        await liveActivity.update(offset: sync.offset, accuracyMs: sync.accuracyMs, precision: precision)
    }
}

/// 「NTP補正済み ±12ms ・ 3分前」
struct SyncBadge: View {
    @Environment(TimeSyncStore.self) private var sync

    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let status = sync.status(at: context.date)
            Button {
                Task { await sync.sync() }
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(color(status)).frame(width: 10, height: 10)
                    Text(title(status, at: context.date))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.text)
                    Spacer()
                    if sync.isSyncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Palette.subText)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Palette.surface, in: Capsule())
                .overlay(Capsule().stroke(color(status).opacity(0.5)))
            }
            .accessibilityHint("タップで今すぐ時刻を合わせる")
        }
        .overlay(alignment: .bottomLeading) {
            if let error = sync.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Palette.danger)
                    .offset(y: 22)
            }
        }
    }

    private func color(_ status: TimeSyncStore.Status) -> Color {
        switch status {
        case .ok: Palette.ok
        case .stale: Palette.warning
        case .unsynced: Palette.danger
        }
    }

    private func title(_ status: TimeSyncStore.Status, at date: Date) -> String {
        guard status != .unsynced, let syncedAt = sync.syncedAt else { return "未補正（端末の時計のまま）" }
        let minutes = Int(date.timeIntervalSince(syncedAt) / 60)
        let ago = minutes < 1 ? "今" : "\(minutes)分前"
        let sign = sync.offset >= 0 ? "+" : "−"
        let ms = sync.accuracyMs.map { " ±\($0)ms" } ?? ""
        return String(format: "NTP補正 %@%.3fs", sign, abs(sync.offset)) + ms + " ・ " + ago
    }
}

/// 時計だけモード（設計 S6 の最小版）。触ると「戻る」が 3 秒だけ出る。
struct ClockOnlyView: View {
    @Environment(TimeSyncStore.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var showsControls = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            TimelineView(.animation) { context in
                let parts = ClockMath.parts(of: sync.now(context.date))
                Group {
                    if landscape {
                        ClockDigitsView(parts: parts, size: geo.size.height * 0.38)
                    } else {
                        VStack(spacing: 0) {
                            Text(String(format: "%02d", parts.hour))
                            Text(String(format: "%02d", parts.minute))
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text(String(format: "%02d", parts.second))
                                Text(parts.fraction)
                                    .font(.system(size: geo.size.width * 0.28, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        .font(.system(size: geo.size.width * 0.42, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(showsControls ? 0.35 : 1)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(sync.status() == .ok ? Palette.ok : (sync.status() == .stale ? Palette.warning : Palette.danger))
                    .frame(width: 8, height: 8)
                    .opacity(0.7)
                    .padding(20)
            }
            .overlay(alignment: .bottom) {
                if showsControls {
                    Button("メニューへ戻る") { dismiss() }
                        .font(.headline)
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accent)
                        .foregroundStyle(Palette.background)
                        .padding(.bottom, 30)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { revealControls() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private func revealControls() {
        showsControls = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { showsControls = false }
        }
    }
}

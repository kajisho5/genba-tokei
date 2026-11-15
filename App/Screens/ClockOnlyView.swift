import SwiftUI

/// S6：時計だけモード（オペレーター向け）。触る（設定で長押し）と操作部が 3 秒だけ出る。
struct ClockOnlyView: View {
    @Environment(AppModel.self) private var model
    @Environment(TimeSyncStore.self) private var sync
    @Environment(SettingsStore.self) private var settings
    @Environment(TimerStore.self) private var timers
    @Environment(\.dismiss) private var dismiss
    @Binding var showsSettings: Bool
    @State private var showsControls = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            TimelineView(.animation) { context in
                let now = sync.now(context.date)
                let p = ClockMath.parts(of: now)
                ZStack {
                    if landscape {
                        ClockDigitsView(parts: p, size: min(geo.size.height * 0.42, geo.size.width * 0.15),
                                        showsFraction: settings.showsFraction)
                            .padding(.horizontal, 24)
                    } else {
                        portraitDigits(p, width: geo.size.width)
                    }
                    if settings.showsDate && !showsControls {
                        Text(now, format: .dateTime.month().day().weekday(.abbreviated))
                            .font(.headline).foregroundStyle(Palette.faint)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(showsControls ? 0.35 : 1)
            .overlay(alignment: .topTrailing) {
                if settings.showsSyncDot && !showsControls {
                    Circle().fill(sync.status().color).frame(width: 8, height: 8).opacity(0.7).padding(24)
                        .accessibilityLabel(sync.status() == .ok ? "時刻補正済み" : "時刻未補正")
                }
            }
            .overlay(alignment: .top) { if showsControls { topBar.padding(.top, 16) } }
            .overlay(alignment: .bottom) { if showsControls { controlButtons.padding(.bottom, 24) } }
        }
        .background(Color.black.ignoresSafeArea())
        .overlay {
            if timers.isFlashing { Palette.danger.opacity(0.35).ignoresSafeArea().allowsHitTesting(false) }
        }
        .contentShape(Rectangle())
        .onTapGesture { if settings.revealGesture == .tap { reveal() } }
        .onLongPressGesture(minimumDuration: 0.6) { reveal() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .animation(.easeOut(duration: 0.2), value: showsControls)
        .accessibilityAction(named: "操作部を表示") { reveal() }
    }

    private func portraitDigits(_ p: ClockParts, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%02d", p.hour))
            Text(String(format: "%02d", p.minute))
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(String(format: "%02d", p.second))
                if settings.showsFraction {
                    Text(p.fraction)
                        .font(.system(size: width * 0.28, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .font(.system(size: width * 0.42, weight: .semibold).monospacedDigit())
        .foregroundStyle(Palette.text)
        .lineLimit(1)
        .minimumScaleFactor(0.3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(p.hour)時\(p.minute)分\(p.second)秒")
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Circle().fill(sync.status().color).frame(width: 10, height: 10)
            Text(sync.badgeText(at: .now)).font(.subheadline.monospacedDigit())
                .foregroundStyle(sync.status() == .ok ? Palette.okText : Palette.text)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Text(Date.now, format: .dateTime.month().day().weekday(.abbreviated))
                .font(.subheadline).foregroundStyle(Palette.subText)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 48)
        .background(Palette.surface.opacity(0.95), in: Capsule())
        .overlay(Capsule().stroke(Palette.border))
        .padding(.horizontal, 24)
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            control("同期") { Task { await model.syncNow() } }
            control(model.pip.isActive ? "小窓を閉じる" : "小窓") { model.pip.toggle() }
            control(model.island.isRunning ? "Island停止" : "Island") { Task { await model.toggleIsland(.clock) } }
            Button { dismiss() } label: {
                Text("メニューへ").font(.subheadline.bold()).foregroundStyle(Palette.background)
                    .frame(minWidth: 96, minHeight: 52)
                    .padding(.horizontal, 8)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private func control(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            reveal()
        } label: {
            Text(title).font(.subheadline.bold()).foregroundStyle(Palette.text)
                .frame(minWidth: 72, minHeight: 52)
                .padding(.horizontal, 8)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border))
        }
        .buttonStyle(.plain)
    }

    private func reveal() {
        showsControls = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { showsControls = false }
        }
    }
}

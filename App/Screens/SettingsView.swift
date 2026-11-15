import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(TimeSyncStore.self) private var sync
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        @Bindable var sync = sync
        NavigationStack {
            Form {
                Section("時計だけモード") {
                    Toggle("起動時に時計だけモードで開く", isOn: $settings.startsInClockOnly)
                    Toggle("1/100秒を表示", isOn: $settings.showsFraction)
                    Toggle("補正状態の点を表示", isOn: $settings.showsSyncDot)
                    Toggle("日付を表示", isOn: $settings.showsDate)
                    Picker("操作部を開く方法", selection: $settings.revealGesture) {
                        ForEach(SettingsStore.RevealGesture.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section {
                    Picker("Dynamic Island の細かさ", selection: $settings.islandPrecision) {
                        ForEach(DisplayPrecision.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Dynamic Island の並び", selection: $settings.islandLeadingOnly) {
                        Text("左に時刻・右に電池").tag(true)
                        Text("左に点・右に時刻").tag(false)
                    }
                } footer: {
                    Text("島は左右対称に広がるため、時刻を出すと電池・電波の表示が隠れます。「右に電池」は電池残量を島の中に出します（アプリが動いている間だけ更新し、15 分更新がないと消えます）。電波の強さは Apple が取得手段を公開していないため出せません。")
                }
                Section {
                    Toggle("画面をスリープさせない", isOn: $settings.keepsScreenOn)
                    Toggle("0秒で音を鳴らす（通知）", isOn: $settings.plays0Sound)
                }
                Section {
                    TextField("time.apple.com", text: $sync.server)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("今すぐ時刻を合わせる") { Task { await model.syncNow() } }
                    Text(sync.badgeText(at: .now)).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                } header: {
                    Text("時刻サーバー（NTP）")
                } footer: {
                    Text("ずれの量と誤差（±ミリ秒）を測って、表示を補正します。Apple Watch には iPhone で測った値を送ります。")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
            .onChange(of: settings.keepsScreenOn) { _, _ in model.applyScreenOn() }
            .onChange(of: settings.islandPrecision) { _, _ in model.pushOutputs() }
            .onChange(of: settings.islandLeadingOnly) { _, _ in model.pushOutputs() }
            .onChange(of: settings.showsFraction) { _, _ in model.pushOutputs() }
        }
    }
}

import Foundation
import Observation

/// 設定（UserDefaults に保存）
@MainActor
@Observable
final class SettingsStore {
    enum RevealGesture: String, CaseIterable, Identifiable {
        case tap, longPress
        var id: String { rawValue }
        var label: String { self == .tap ? "タップ" : "長押し" }
    }

    var startsInClockOnly: Bool { didSet { save(startsInClockOnly, "startsInClockOnly") } }
    var showsFraction: Bool { didSet { save(showsFraction, "showsFraction") } }
    var showsSyncDot: Bool { didSet { save(showsSyncDot, "showsSyncDot") } }
    var showsDate: Bool { didSet { save(showsDate, "showsDate") } }
    var revealGesture: RevealGesture { didSet { save(revealGesture.rawValue, "revealGesture") } }
    var islandPrecision: DisplayPrecision { didSet { save(islandPrecision.rawValue, "islandPrecision") } }
    var keepsScreenOn: Bool { didSet { save(keepsScreenOn, "keepsScreenOn") } }
    var plays0Sound: Bool { didSet { save(plays0Sound, "plays0Sound") } }

    private let defaults = UserDefaults.standard

    init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "startsInClockOnly": true, "showsFraction": true, "showsSyncDot": true, "showsDate": false,
            "revealGesture": RevealGesture.tap.rawValue, "islandPrecision": DisplayPrecision.centiseconds.rawValue,
            "keepsScreenOn": true, "plays0Sound": true,
        ])
        startsInClockOnly = d.bool(forKey: "startsInClockOnly")
        showsFraction = d.bool(forKey: "showsFraction")
        showsSyncDot = d.bool(forKey: "showsSyncDot")
        showsDate = d.bool(forKey: "showsDate")
        revealGesture = RevealGesture(rawValue: d.string(forKey: "revealGesture") ?? "") ?? .tap
        islandPrecision = DisplayPrecision(rawValue: d.string(forKey: "islandPrecision") ?? "") ?? .centiseconds
        keepsScreenOn = d.bool(forKey: "keepsScreenOn")
        plays0Sound = d.bool(forKey: "plays0Sound")
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }
}

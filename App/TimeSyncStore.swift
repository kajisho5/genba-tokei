import Foundation
import Observation

/// 時刻補正の状態。表示時刻 = 端末の時刻 + offset
@MainActor
@Observable
final class TimeSyncStore {
    enum Status { case ok, stale, unsynced }

    private(set) var offset: TimeInterval = 0
    private(set) var accuracy: TimeInterval?
    private(set) var syncedAt: Date?
    private(set) var isSyncing = false
    private(set) var lastError: String?
    var server = "time.apple.com"

    private let defaults = UserDefaults.standard

    init() {
        // 前回の結果を引き継ぐ（同期するまでは「古い」扱い）
        if let saved = defaults.object(forKey: "ntp.offset") as? Double {
            offset = saved
            accuracy = defaults.object(forKey: "ntp.accuracy") as? Double
            syncedAt = defaults.object(forKey: "ntp.syncedAt") as? Date
        }
        if let s = defaults.string(forKey: "ntp.server"), !s.isEmpty { server = s }
    }

    func now(_ system: Date = Date()) -> Date { system.addingTimeInterval(offset) }

    func status(at date: Date = Date()) -> Status {
        guard let syncedAt else { return .unsynced }
        return date.timeIntervalSince(syncedAt) < 3600 ? .ok : .stale
    }

    var accuracyMs: Int? {
        guard syncedAt != nil, let accuracy else { return nil }
        return Int((accuracy * 1000).rounded(.up))
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let result = try await NTPClient.sync(server: server)
            offset = result.offset
            accuracy = result.accuracy
            syncedAt = result.syncedAt
            lastError = nil
            defaults.set(offset, forKey: "ntp.offset")
            defaults.set(accuracy, forKey: "ntp.accuracy")
            defaults.set(syncedAt, forKey: "ntp.syncedAt")
            defaults.set(server, forKey: "ntp.server")
        } catch {
            lastError = "同期できませんでした（通信を確認してください）"
        }
    }

    /// 端末の時計が手動で変えられた時など、前回の補正が使えない時に呼ぶ
    func invalidate() {
        syncedAt = nil
        accuracy = nil
        offset = 0
    }
}

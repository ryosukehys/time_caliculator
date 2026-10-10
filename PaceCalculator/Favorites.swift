import Foundation

/// 計算画面の入力内容一式。お気に入りの保存単位でもある
struct PaceInput: Codable, Equatable {
    var mode: CalcMode = .time
    var event: RaceEvent = .m5000
    var customValue = ""
    var customUnit: DistanceUnit = .km
    var hours = ""
    var minutes = ""
    var seconds = ""
    var tenths = ""
    var paceMinutes = ""
    var paceSeconds = ""
    var paceTenths = ""
    var paceUnit: PaceUnit = .km

    var meters: Double? {
        if let m = event.meters { return m }
        guard let v = Double(customValue), v > 0 else { return nil }
        return customUnit == .km ? v * 1000 : v
    }

    /// 1時間を超えうる距離だけ「時間」欄を出す
    var showsHours: Bool {
        event == .custom || (meters ?? 0) >= 10000
    }

    /// トラック種目（時間欄なし）だけ 1/10 秒欄を出す
    var showsTenths: Bool { !showsHours }

    /// 400m ラップ指定のときだけ 1/10 秒欄を出す
    var showsPaceTenths: Bool { paceUnit == .lap400 }

    var result: PaceResult? {
        guard let meters else { return nil }
        switch mode {
        case .time:
            let sec = PaceMath.joinTenths(seconds, showsTenths ? tenths : "")
            guard let total = PaceMath.parseHMS(showsHours ? hours : "", minutes, sec) else { return nil }
            return PaceResult(meters: meters, seconds: total, secPerKm: PaceMath.pace(meters: meters, seconds: total))
        case .pace:
            let sec = PaceMath.joinTenths(paceSeconds, showsPaceTenths ? paceTenths : "")
            guard let pace = PaceMath.parseHMS("", paceMinutes, sec) else { return nil }
            let secPerKm = paceUnit == .km ? pace : pace * 2.5
            return PaceResult(meters: meters, seconds: PaceMath.time(meters: meters, secPerKm: secPerKm), secPerKm: secPerKm)
        }
    }

    /// 入力の要約: 「5000m 16:40.0」「ハーフ 4'00"/km」
    var summary: String {
        let name = event == .custom ? (meters.map(TimeFormat.distance) ?? event.label) : event.label
        guard let r = result else { return name }
        switch mode {
        case .time:
            return "\(name) \(TimeFormat.clock(r.seconds, decimals: showsTenths ? 1 : 0))"
        case .pace:
            switch paceUnit {
            case .km: return "\(name) \(TimeFormat.pace(r.secPerKm))/km"
            case .lap400: return "\(name) \(TimeFormat.pace(r.secPerKm * 0.4, decimals: 1))/400m"
            }
        }
    }

    /// 一覧で目立たせる計算結果: タイム → ペースならキロペース、ペース → タイムならゴールタイム
    var resultText: String? {
        guard let r = result else { return nil }
        switch mode {
        case .time: return TimeFormat.pace(r.secPerKm, decimals: 1) + "/km"
        case .pace: return TimeFormat.clock(r.seconds, decimals: PaceMath.goalDecimals(meters: r.meters))
        }
    }
}

// 項目を後から増やしても、以前に保存したお気に入りを読めるようにする
extension PaceInput {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PaceInput()
        mode = try c.decodeIfPresent(CalcMode.self, forKey: .mode) ?? d.mode
        event = try c.decodeIfPresent(RaceEvent.self, forKey: .event) ?? d.event
        customValue = try c.decodeIfPresent(String.self, forKey: .customValue) ?? d.customValue
        customUnit = try c.decodeIfPresent(DistanceUnit.self, forKey: .customUnit) ?? d.customUnit
        hours = try c.decodeIfPresent(String.self, forKey: .hours) ?? d.hours
        minutes = try c.decodeIfPresent(String.self, forKey: .minutes) ?? d.minutes
        seconds = try c.decodeIfPresent(String.self, forKey: .seconds) ?? d.seconds
        tenths = try c.decodeIfPresent(String.self, forKey: .tenths) ?? d.tenths
        paceMinutes = try c.decodeIfPresent(String.self, forKey: .paceMinutes) ?? d.paceMinutes
        paceSeconds = try c.decodeIfPresent(String.self, forKey: .paceSeconds) ?? d.paceSeconds
        paceTenths = try c.decodeIfPresent(String.self, forKey: .paceTenths) ?? d.paceTenths
        paceUnit = try c.decodeIfPresent(PaceUnit.self, forKey: .paceUnit) ?? d.paceUnit
    }
}

struct Favorite: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var input: PaceInput
}

/// お気に入り一覧を UserDefaults に置く JSON との相互変換
enum FavoriteStore {
    static func decode(_ data: Data) -> [Favorite] {
        (try? JSONDecoder().decode([Favorite].self, from: data)) ?? []
    }

    static func encode(_ favorites: [Favorite]) -> Data {
        (try? JSONEncoder().encode(favorites)) ?? Data()
    }
}

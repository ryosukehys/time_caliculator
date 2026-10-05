import Foundation

// ランニングのペース計算ロジック（UI に依存しない純粋関数のみ）

enum RaceEvent: String, CaseIterable, Identifiable {
    case m400, m800, m1500, m3000, m5000, m10000, half, full, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .m400: "400m"
        case .m800: "800m"
        case .m1500: "1500m"
        case .m3000: "3000m"
        case .m5000: "5000m"
        case .m10000: "10000m"
        case .half: "ハーフ"
        case .full: "フル"
        case .custom: "距離入力"
        }
    }

    var meters: Double? {
        switch self {
        case .m400: 400
        case .m800: 800
        case .m1500: 1500
        case .m3000: 3000
        case .m5000: 5000
        case .m10000: 10000
        case .half: 21097.5
        case .full: 42195
        case .custom: nil
        }
    }
}

struct Split: Equatable {
    let meters: Double
    let seconds: Double
}

enum PaceMath {
    static let splitIntervals: [Double] = [100, 200, 400, 1000, 5000]

    /// 時・分・秒の文字列から合計秒数を求める。すべて空、または 0 以下なら nil
    static func parseHMS(_ h: String, _ m: String, _ s: String) -> Double? {
        let parts = [h, m, s].map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.allSatisfy(\.isEmpty) { return nil }
        var values: [Double] = []
        for part in parts {
            if part.isEmpty {
                values.append(0)
            } else if let v = Double(part), v.isFinite, v >= 0 {
                values.append(v)
            } else {
                return nil
            }
        }
        let total = values[0] * 3600 + values[1] * 60 + values[2]
        return total > 0 ? total : nil
    }

    /// 秒/km
    static func pace(meters: Double, seconds: Double) -> Double {
        seconds / meters * 1000
    }

    /// ゴールタイム（秒）
    static func time(meters: Double, secPerKm: Double) -> Double {
        secPerKm * meters / 1000
    }

    static func speedKmh(secPerKm: Double) -> Double {
        3600 / secPerKm
    }

    /// 距離に応じて選べるスプリット間隔（2〜60 区間に収まるもの）
    static func splitOptions(meters: Double) -> [Double] {
        splitIntervals.filter { meters / $0 >= 2 && meters / $0 <= 60 }
    }

    static func defaultSplit(meters: Double) -> Double? {
        let options = splitOptions(meters: meters)
        guard let first = options.first else { return nil }
        if meters > 20000 && options.contains(5000) { return 5000 }
        if meters > 5000 && options.contains(1000) { return 1000 }
        if options.contains(400) { return 400 }
        return first
    }

    /// interval ごとの通過タイム。最後はゴール地点
    static func splits(meters: Double, secPerKm: Double, interval: Double) -> [Split] {
        var rows: [Split] = []
        var d = interval
        while d < meters - 1e-9 {
            rows.append(Split(meters: d, seconds: time(meters: d, secPerKm: secPerKm)))
            d += interval
        }
        rows.append(Split(meters: meters, seconds: time(meters: meters, secPerKm: secPerKm)))
        return rows
    }

    /// Riegel の式 T2 = T1 × (D2 / D1)^1.06 による予想タイム
    static func riegel(meters: Double, seconds: Double, target: Double, exponent: Double = 1.06) -> Double {
        seconds * pow(target / meters, exponent)
    }

    /// ゴールタイムの小数桁（トラック種目は 0.1 秒まで）
    static func goalDecimals(meters: Double) -> Int {
        meters <= 10000 ? 1 : 0
    }
}

enum TimeFormat {
    /// 時計表記: 2:05:30 / 14:30 / 14:30.5
    static func clock(_ seconds: Double, decimals: Int = 0) -> String {
        let (whole, frac) = units(seconds, decimals)
        let h = whole / 3600
        let m = whole % 3600 / 60
        let s = whole % 60
        let fracStr = decimals > 0 ? "." + pad(frac, decimals) : ""
        if h > 0 { return "\(h):\(pad(m, 2)):\(pad(s, 2))\(fracStr)" }
        return "\(m):\(pad(s, 2))\(fracStr)"
    }

    /// 陸上表記: 3'20" / 1'20"5 / 58"3
    static func pace(_ seconds: Double, decimals: Int = 0) -> String {
        let (whole, frac) = units(seconds, decimals)
        let m = whole / 60
        let s = whole % 60
        let fracStr = decimals > 0 ? pad(frac, decimals) : ""
        if m == 0 { return "\(s)\"\(fracStr)" }
        return "\(m)'\(pad(s, 2))\"\(fracStr)"
    }

    /// 400m / 1km / 21.0975km
    static func distance(_ meters: Double) -> String {
        if meters >= 1000 { return trimZeros(String(format: "%.4f", meters / 1000)) + "km" }
        return trimZeros(String(format: "%.1f", meters)) + "m"
    }

    /// 小数桁で丸めた整数単位に変換し、繰り上がり（59.96秒→1分など）を正しく扱う
    private static func units(_ seconds: Double, _ decimals: Int) -> (whole: Int, frac: Int) {
        var scale = 1
        for _ in 0..<decimals { scale *= 10 }
        let total = Int((seconds * Double(scale)).rounded())
        return (total / scale, total % scale)
    }

    private static func pad(_ n: Int, _ width: Int) -> String {
        let s = String(n)
        return String(repeating: "0", count: max(0, width - s.count)) + s
    }

    private static func trimZeros(_ s: String) -> String {
        guard s.contains(".") else { return s }
        var t = s
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t
    }
}

enum InputFilter {
    /// 数字と小数点 1 つだけを残し、最大文字数で切る（"," は "." として扱う）
    static func sanitize(_ value: String, maxLength: Int) -> String {
        var seenDot = false
        var out = ""
        for ch in value.replacingOccurrences(of: ",", with: ".") {
            if ch.isASCII && ch.isNumber {
                out.append(ch)
            } else if ch == "." && !seenDot {
                seenDot = true
                out.append(ch)
            }
        }
        return String(out.prefix(maxLength))
    }
}

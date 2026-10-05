import SwiftUI

struct ResultsView: View {
    let meters: Double?
    let result: PaceResult?
    let mode: CalcMode
    let paceUnit: PaceUnit
    @Binding var splitInterval: Double

    var body: some View {
        if let result {
            VStack(spacing: 12) {
                HStack(spacing: 10) { heroes(result) }
                Card {
                    HStack(alignment: .top) {
                        Stat(title: "200m", value: TimeFormat.pace(result.secPerKm * 0.2, decimals: 1))
                        Stat(title: "100m", value: TimeFormat.pace(result.secPerKm * 0.1, decimals: 1))
                        Stat(title: "時速", value: String(format: "%.2f", PaceMath.speedKmh(secPerKm: result.secPerKm)),
                             unit: "km/h")
                    }
                }
                SplitsCard(result: result, splitInterval: $splitInterval)
                if mode == .time {
                    PredictionsCard(result: result)
                } else {
                    SamePaceCard(secPerKm: result.secPerKm)
                }
            }
        } else {
            Card {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    private var emptyMessage: String {
        guard let meters else { return "距離を入力してください" }
        let what = mode == .time ? "タイム" : "ペース"
        return "\(TimeFormat.distance(meters)) の\(what)を入力すると\nすぐに結果が表示されます"
    }

    @ViewBuilder
    private func heroes(_ r: PaceResult) -> some View {
        let per400 = r.secPerKm * 0.4
        let kmHero = Hero(title: "1kmあたり", value: TimeFormat.pace(r.secPerKm), sub: "/km")
        let lapHero = Hero(title: "400mあたり", value: TimeFormat.pace(per400, decimals: 1),
                           sub: String(format: "%.1f秒", per400))
        switch mode {
        case .time:
            kmHero
            lapHero
        case .pace:
            Hero(title: "ゴールタイム",
                 value: TimeFormat.clock(r.seconds, decimals: PaceMath.goalDecimals(meters: r.meters)),
                 sub: TimeFormat.distance(r.meters))
            if paceUnit == .km { lapHero } else { kmHero }
        }
    }
}

struct Hero: View {
    let title: String
    let value: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textSelection(.enabled)
            Text(sub)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

struct Stat: View {
    let title: String
    let value: String
    var unit: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct ResultRow: Identifiable {
    let id: Int
    let label: String
    var detail: String? = nil
    let value: String
    var highlighted = false
}

struct RowsTable: View {
    let rows: [ResultRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                if row.id != rows.first?.id { Divider() }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.label)
                    if let detail = row.detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(row.value)
                        .fontWeight(.bold)
                }
                .monospacedDigit()
                .foregroundStyle(row.highlighted ? Color.accentColor : Color.primary)
                .padding(.vertical, 9)
            }
        }
    }
}

struct SplitsCard: View {
    let result: PaceResult
    @Binding var splitInterval: Double

    private var options: [Double] { PaceMath.splitOptions(meters: result.meters) }

    private var interval: Double? {
        options.contains(splitInterval) ? splitInterval : PaceMath.defaultSplit(meters: result.meters)
    }

    var body: some View {
        if let interval {
            Card("スプリット（イーブンペース）") {
                Picker("間隔", selection: Binding(get: { interval }, set: { splitInterval = $0 })) {
                    ForEach(options, id: \.self) { Text(TimeFormat.distance($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                RowsTable(rows: rows(interval: interval))
            }
        }
    }

    private func rows(interval: Double) -> [ResultRow] {
        let splits = PaceMath.splits(meters: result.meters, secPerKm: result.secPerKm, interval: interval)
        let decimals = PaceMath.goalDecimals(meters: result.meters)
        return splits.enumerated().map { pair -> ResultRow in
            let (index, split) = pair
            let isGoal = index == splits.count - 1
            return ResultRow(
                id: index,
                label: isGoal ? "ゴール" : TimeFormat.distance(split.meters),
                detail: isGoal ? TimeFormat.distance(split.meters) : nil,
                value: TimeFormat.clock(split.seconds, decimals: decimals),
                highlighted: isGoal
            )
        }
    }
}

struct PredictionsCard: View {
    let result: PaceResult

    var body: some View {
        // Riegel 式は 3 分〜4 時間程度の記録で使うのが目安
        if result.seconds >= 180 && result.seconds <= 4 * 3600 {
            Card("この記録からの予想タイム") {
                RowsTable(rows: rows)
                Text("Riegel の式（T₂ = T₁ × (D₂ / D₁)^1.06）による参考値です。練習量や得意距離で実際とは差が出ます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rows: [ResultRow] {
        RaceEvent.allCases.enumerated().compactMap { pair -> ResultRow? in
            let (index, event) = pair
            guard let target = event.meters, target >= 1500, target != result.meters else { return nil }
            let t = PaceMath.riegel(meters: result.meters, seconds: result.seconds, target: target)
            return ResultRow(
                id: index,
                label: event.label,
                detail: TimeFormat.pace(PaceMath.pace(meters: target, seconds: t)) + "/km",
                value: TimeFormat.clock(t, decimals: PaceMath.goalDecimals(meters: target))
            )
        }
    }
}

struct SamePaceCard: View {
    let secPerKm: Double

    var body: some View {
        Card("このペースでの各種目タイム") {
            RowsTable(rows: rows)
        }
    }

    private var rows: [ResultRow] {
        RaceEvent.allCases.enumerated().compactMap { pair -> ResultRow? in
            let (index, event) = pair
            guard let meters = event.meters else { return nil }
            return ResultRow(
                id: index,
                label: event.label,
                value: TimeFormat.clock(PaceMath.time(meters: meters, secPerKm: secPerKm),
                                        decimals: PaceMath.goalDecimals(meters: meters))
            )
        }
    }
}

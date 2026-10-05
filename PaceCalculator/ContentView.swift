import SwiftUI

enum CalcMode: String, CaseIterable, Identifiable {
    case time, pace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .time: "タイム → ペース"
        case .pace: "ペース → タイム"
        }
    }
}

enum DistanceUnit: String, CaseIterable, Identifiable {
    case km, m

    var id: String { rawValue }
}

enum PaceUnit: String, CaseIterable, Identifiable {
    case km, lap400

    var id: String { rawValue }

    var label: String {
        switch self {
        case .km: "/km"
        case .lap400: "/400m"
        }
    }
}

enum InputField: Hashable {
    case customDistance, hours, minutes, seconds, paceMinutes, paceSeconds
}

struct PaceResult {
    let meters: Double
    let seconds: Double
    let secPerKm: Double
}

struct ContentView: View {
    @AppStorage("mode") private var mode: CalcMode = .time
    @AppStorage("event") private var event: RaceEvent = .m5000
    @AppStorage("customValue") private var customValue = ""
    @AppStorage("customUnit") private var customUnit: DistanceUnit = .km
    @AppStorage("hours") private var hours = ""
    @AppStorage("minutes") private var minutes = ""
    @AppStorage("seconds") private var seconds = ""
    @AppStorage("paceMinutes") private var paceMinutes = ""
    @AppStorage("paceSeconds") private var paceSeconds = ""
    @AppStorage("paceUnit") private var paceUnit: PaceUnit = .km
    /// 0 は「距離に応じて自動」
    @AppStorage("splitInterval") private var splitInterval: Double = 0
    @FocusState private var focus: InputField?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Picker("計算モード", selection: $mode) {
                        ForEach(CalcMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    eventCard
                    if mode == .time { timeCard } else { paceCard }

                    ResultsView(
                        meters: meters,
                        result: result,
                        mode: mode,
                        paceUnit: paceUnit,
                        splitInterval: $splitInterval
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ペース計算")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("クリア", action: clear)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button { moveFocus(by: -1) } label: { Image(systemName: "chevron.up") }
                    Button { moveFocus(by: 1) } label: { Image(systemName: "chevron.down") }
                    Spacer()
                    Button("完了") { focus = nil }.bold()
                }
            }
            .onChange(of: customValue) { _, v in customValue = InputFilter.sanitize(v, maxLength: 7) }
            .onChange(of: hours) { _, v in handleInput(v, field: .hours, maxLength: 2) { hours = $0 } }
            .onChange(of: minutes) { _, v in handleInput(v, field: .minutes, maxLength: 3) { minutes = $0 } }
            .onChange(of: seconds) { _, v in handleInput(v, field: .seconds, maxLength: 5) { seconds = $0 } }
            .onChange(of: paceMinutes) { _, v in handleInput(v, field: .paceMinutes, maxLength: 2) { paceMinutes = $0 } }
            .onChange(of: paceSeconds) { _, v in handleInput(v, field: .paceSeconds, maxLength: 4) { paceSeconds = $0 } }
        }
    }

    // MARK: - 入力カード

    private var eventCard: some View {
        Card("種目") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(RaceEvent.allCases) { ev in
                    EventChip(label: ev.label, selected: ev == event) {
                        event = ev
                        splitInterval = 0
                        if ev == .custom && customValue.isEmpty { focus = .customDistance }
                    }
                }
            }
            if event == .custom {
                HStack(spacing: 8) {
                    TextField("例: 12.5", text: $customValue)
                        .keyboardType(.decimalPad)
                        .focused($focus, equals: .customDistance)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    Picker("単位", selection: $customUnit) {
                        ForEach(DistanceUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                    .onChange(of: customUnit) { _, _ in splitInterval = 0 }
                }
            }
        }
    }

    private var timeCard: some View {
        Card("タイム") {
            HStack(alignment: .top, spacing: 6) {
                if showsHours {
                    NumberBox(text: $hours, unit: "時間", placeholder: "0", decimal: false, focus: $focus, field: .hours)
                    Separator(":")
                }
                NumberBox(text: $minutes, unit: "分", placeholder: "0", decimal: false, focus: $focus, field: .minutes)
                Separator(":")
                NumberBox(text: $seconds, unit: "秒", placeholder: "00", decimal: true, focus: $focus, field: .seconds)
            }
        }
    }

    private var paceCard: some View {
        Card {
            HStack {
                Text("ペース")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("単位", selection: $paceUnit) {
                    ForEach(PaceUnit.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            HStack(alignment: .top, spacing: 6) {
                NumberBox(text: $paceMinutes, unit: "分", placeholder: "0", decimal: false, focus: $focus, field: .paceMinutes)
                Separator("'")
                NumberBox(text: $paceSeconds, unit: "秒", placeholder: "00", decimal: true, focus: $focus, field: .paceSeconds)
            }
        }
    }

    // MARK: - 計算

    private var meters: Double? {
        if let m = event.meters { return m }
        guard let v = Double(customValue), v > 0 else { return nil }
        return customUnit == .km ? v * 1000 : v
    }

    /// 1時間を超えうる距離だけ「時間」欄を出す
    private var showsHours: Bool {
        event == .custom || (meters ?? 0) >= 10000
    }

    private var result: PaceResult? {
        guard let meters else { return nil }
        switch mode {
        case .time:
            guard let total = PaceMath.parseHMS(showsHours ? hours : "", minutes, seconds) else { return nil }
            return PaceResult(meters: meters, seconds: total, secPerKm: PaceMath.pace(meters: meters, seconds: total))
        case .pace:
            guard let pace = PaceMath.parseHMS("", paceMinutes, paceSeconds) else { return nil }
            let secPerKm = paceUnit == .km ? pace : pace * 2.5
            return PaceResult(meters: meters, seconds: PaceMath.time(meters: meters, secPerKm: secPerKm), secPerKm: secPerKm)
        }
    }

    // MARK: - 入力操作

    private var visibleFields: [InputField] {
        var fields: [InputField] = event == .custom ? [.customDistance] : []
        switch mode {
        case .time: fields += showsHours ? [.hours, .minutes, .seconds] : [.minutes, .seconds]
        case .pace: fields += [.paceMinutes, .paceSeconds]
        }
        return fields
    }

    private func moveFocus(by offset: Int) {
        let fields = visibleFields
        guard let current = focus, let index = fields.firstIndex(of: current) else { return }
        let next = index + offset
        if fields.indices.contains(next) { focus = fields[next] }
    }

    /// 数字以外を除去し、時・分欄は 2 桁入ったら次の欄へ送る
    private func handleInput(_ value: String, field: InputField, maxLength: Int, assign: (String) -> Void) {
        let cleaned = InputFilter.sanitize(value, maxLength: maxLength)
        if cleaned != value {
            assign(cleaned)
            return
        }
        let autoAdvance: Set<InputField> = [.hours, .minutes, .paceMinutes]
        guard focus == field, autoAdvance.contains(field),
              cleaned.count >= 2, cleaned.allSatisfy(\.isNumber) else { return }
        moveFocus(by: 1)
    }

    private func clear() {
        hours = ""
        minutes = ""
        seconds = ""
        paceMinutes = ""
        paceSeconds = ""
        focus = nil
    }
}

// MARK: - 部品

struct Card<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct EventChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct NumberBox: View {
    @Binding var text: String
    let unit: String
    let placeholder: String
    let decimal: Bool
    var focus: FocusState<InputField?>.Binding
    let field: InputField

    var body: some View {
        VStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .focused(focus, equals: field)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focus.wrappedValue == field ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .accessibilityLabel(unit)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct Separator: View {
    let symbol: String

    init(_ symbol: String) {
        self.symbol = symbol
    }

    var body: some View {
        Text(symbol)
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.top, 12)
    }
}

#Preview {
    ContentView()
}

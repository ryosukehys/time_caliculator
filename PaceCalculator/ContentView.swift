import SwiftUI

enum CalcMode: String, CaseIterable, Identifiable, Codable {
    case time, pace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .time: "タイム → ペース"
        case .pace: "ペース → タイム"
        }
    }
}

enum DistanceUnit: String, CaseIterable, Identifiable, Codable {
    case km, m

    var id: String { rawValue }
}

enum PaceUnit: String, CaseIterable, Identifiable, Codable {
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
    case customDistance, hours, minutes, seconds, tenths, paceMinutes, paceSeconds, paceTenths
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
    @AppStorage("tenths") private var tenths = ""
    @AppStorage("paceMinutes") private var paceMinutes = ""
    @AppStorage("paceSeconds") private var paceSeconds = ""
    @AppStorage("paceTenths") private var paceTenths = ""
    @AppStorage("paceUnit") private var paceUnit: PaceUnit = .km
    /// 0 は「距離に応じて自動」
    @AppStorage("splitInterval") private var splitInterval: Double = 0
    @AppStorage("favorites") private var favoritesData = Data()
    @FocusState private var focus: InputField?
    @State private var showingFavorites = false
    @State private var favoriteToast: FavoriteToast?
    @State private var favoriteChangeCount = 0
    @State private var renamingID: Favorite.ID?
    @State private var renameText = ""
    /// お気に入りパネルを指で引き出している量（右が正）
    @State private var drawerDragX: CGFloat = 0
    /// 今のドラッグが横方向か（縦スクロールと区別するため、動き始めで判定）
    @State private var dragIsHorizontal: Bool?

    var body: some View {
        GeometryReader { geo in
            let panelWidth = min(geo.size.width * 0.86, 420)
            let progress = DrawerSwipe.progress(isOpen: showingFavorites, dragX: drawerDragX, panelWidth: panelWidth)
            ZStack(alignment: .leading) {
                calculator
                    .simultaneousGesture(drawerDrag(panelWidth: panelWidth, opening: true),
                                         including: showingFavorites ? .subviews : .all)
                    .accessibilityHidden(showingFavorites)

                Color.black
                    .opacity(0.35 * progress)
                    .ignoresSafeArea()
                    .allowsHitTesting(showingFavorites)
                    .onTapGesture { setDrawer(open: false) }
                    .gesture(drawerDrag(panelWidth: panelWidth, opening: false))

                FavoritesView(
                    favorites: favorites,
                    onSelect: {
                        apply($0.input)
                        setDrawer(open: false)
                    },
                    onClose: { setDrawer(open: false) }
                )
                .frame(width: panelWidth)
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .shadow(color: .black.opacity(0.25 * progress), radius: 12)
                .offset(x: -panelWidth * (1 - progress))
                .allowsHitTesting(progress > 0)
                .accessibilityHidden(!showingFavorites)
            }
        }
    }

    private var calculator: some View {
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
                        splitInterval: $splitInterval,
                        isFavorite: currentFavoriteIndex != nil,
                        onToggleFavorite: toggleFavorite
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ペース計算")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { setDrawer(open: true) } label: { Label("お気に入り一覧", systemImage: "list.star") }
                }
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
            .onChange(of: minutes) { _, v in handleInput(v, field: .minutes, maxLength: 2) { minutes = $0 } }
            .onChange(of: seconds) { _, v in handleInput(v, field: .seconds, maxLength: 2) { seconds = $0 } }
            .onChange(of: tenths) { _, v in handleInput(v, field: .tenths, maxLength: 1) { tenths = $0 } }
            .onChange(of: paceMinutes) { _, v in handleInput(v, field: .paceMinutes, maxLength: 2) { paceMinutes = $0 } }
            .onChange(of: paceSeconds) { _, v in handleInput(v, field: .paceSeconds, maxLength: 2) { paceSeconds = $0 } }
            .onChange(of: paceTenths) { _, v in handleInput(v, field: .paceTenths, maxLength: 1) { paceTenths = $0 } }
            .onAppear(perform: migrateDecimalSeconds)
            .overlay(alignment: .bottom) {
                if let favoriteToast {
                    ToastView(toast: favoriteToast) { performToastAction(favoriteToast) }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: favoriteToast) {
                guard favoriteToast != nil else { return }
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                withAnimation { favoriteToast = nil }
            }
            .alert("名前を付ける", isPresented: isRenaming) {
                TextField("名前", text: $renameText)
                Button("保存", action: renameFavorite)
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("右にスワイプするか、左上のボタンでお気に入り一覧を開けます")
            }
            .sensoryFeedback(.success, trigger: favoriteChangeCount)
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
                HStack(spacing: 8) {
                    ForEach(DistanceStep.steps, id: \.self) { delta in
                        Button {
                            customValue = DistanceStep.apply(delta, to: customValue, unit: customUnit)
                        } label: {
                            Text(DistanceStep.label(delta))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .buttonRepeatBehavior(.enabled)
                    }
                }
            }
        }
    }

    private var timeCard: some View {
        Card("タイム") {
            HStack(alignment: .top, spacing: 6) {
                if showsHours {
                    NumberBox(text: $hours, unit: "時間", placeholder: "0", focus: $focus, field: .hours)
                    Separator(":")
                }
                NumberBox(text: $minutes, unit: "分", placeholder: "0", focus: $focus, field: .minutes)
                Separator(":")
                NumberBox(text: $seconds, unit: "秒", placeholder: "00", focus: $focus, field: .seconds)
                if showsTenths {
                    Separator(".")
                    NumberBox(text: $tenths, unit: "1/10秒", placeholder: "0", compact: true, focus: $focus, field: .tenths)
                }
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
                NumberBox(text: $paceMinutes, unit: "分", placeholder: "0", focus: $focus, field: .paceMinutes)
                Separator("'")
                NumberBox(text: $paceSeconds, unit: "秒", placeholder: "00", focus: $focus, field: .paceSeconds)
                if showsPaceTenths {
                    Separator(".")
                    NumberBox(text: $paceTenths, unit: "1/10秒", placeholder: "0", compact: true, focus: $focus, field: .paceTenths)
                }
            }
        }
    }

    // MARK: - 計算

    private var input: PaceInput {
        PaceInput(
            mode: mode, event: event, customValue: customValue, customUnit: customUnit,
            hours: hours, minutes: minutes, seconds: seconds, tenths: tenths,
            paceMinutes: paceMinutes, paceSeconds: paceSeconds, paceTenths: paceTenths, paceUnit: paceUnit
        )
    }

    private var meters: Double? { input.meters }
    private var showsHours: Bool { input.showsHours }
    private var showsTenths: Bool { input.showsTenths }
    private var showsPaceTenths: Bool { input.showsPaceTenths }
    private var result: PaceResult? { input.result }

    // MARK: - お気に入り

    private var favorites: Binding<[Favorite]> {
        Binding(
            get: { FavoriteStore.decode(favoritesData) },
            set: { favoritesData = FavoriteStore.encode($0) }
        )
    }

    /// 横スワイプでお気に入りパネルを開閉する。opening が true なら計算画面上の右スワイプ、false なら暗い部分の左スワイプ
    private func drawerDrag(panelWidth: CGFloat, opening: Bool) -> some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                if dragIsHorizontal == nil { dragIsHorizontal = DrawerSwipe.isHorizontal(value.translation) }
                guard dragIsHorizontal == true else { return }
                let x = value.translation.width
                drawerDragX = opening ? max(0, x) : min(0, x)
            }
            .onEnded { value in
                defer { dragIsHorizontal = nil }
                guard dragIsHorizontal == true else {
                    drawerDragX = 0
                    return
                }
                let x = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if opening {
                    setDrawer(open: DrawerSwipe.shouldOpen(translation: x, predicted: predicted, panelWidth: panelWidth))
                } else {
                    setDrawer(open: !DrawerSwipe.shouldClose(translation: x, predicted: predicted, panelWidth: panelWidth))
                }
            }
    }

    private func setDrawer(open: Bool) {
        if open { focus = nil }
        withAnimation(.snappy) {
            showingFavorites = open
            drawerDragX = 0
        }
    }

    /// 今の入力と同じ計算のお気に入りの位置（未登録なら nil）
    private var currentFavoriteIndex: Int? {
        FavoriteStore.decode(favoritesData).firstIndex { $0.input.isSameCalculation(as: input) }
    }

    /// ワンタップでお気に入りに追加／登録済みなら外す。名前は要約を自動で付ける
    private func toggleFavorite() {
        var list = FavoriteStore.decode(favoritesData)
        let toast: FavoriteToast
        if let index = list.firstIndex(where: { $0.input.isSameCalculation(as: input) }) {
            toast = .removed(list.remove(at: index), index: index)
        } else {
            let favorite = Favorite(name: input.summary, input: input)
            list.insert(favorite, at: 0)
            toast = .added(favorite)
        }
        favoritesData = FavoriteStore.encode(list)
        favoriteChangeCount += 1
        withAnimation(.snappy) { favoriteToast = toast }
    }

    private func performToastAction(_ toast: FavoriteToast) {
        switch toast {
        case .added(let favorite):
            renameText = favorite.name
            renamingID = favorite.id
        case .removed(let favorite, let index):
            var list = FavoriteStore.decode(favoritesData)
            list.insert(favorite, at: min(index, list.count))
            favoritesData = FavoriteStore.encode(list)
        }
        withAnimation(.snappy) { favoriteToast = nil }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })
    }

    private func renameFavorite() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        var list = FavoriteStore.decode(favoritesData)
        guard let id = renamingID, !name.isEmpty,
              let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].name = name
        favoritesData = FavoriteStore.encode(list)
    }

    /// 保存しておいた入力内容を画面に戻す。そのモードで使う欄だけを書き換え、もう一方のモードの入力は残す
    private func apply(_ saved: PaceInput) {
        focus = nil
        mode = saved.mode
        event = saved.event
        if saved.event == .custom {
            customValue = saved.customValue
            customUnit = saved.customUnit
        }
        switch saved.mode {
        case .time:
            hours = saved.hours
            minutes = saved.minutes
            seconds = saved.seconds
            tenths = saved.tenths
        case .pace:
            paceMinutes = saved.paceMinutes
            paceSeconds = saved.paceSeconds
            paceTenths = saved.paceTenths
            paceUnit = saved.paceUnit
        }
        splitInterval = 0
    }

    // MARK: - 入力操作

    private var visibleFields: [InputField] {
        var fields: [InputField] = event == .custom ? [.customDistance] : []
        switch mode {
        case .time:
            if showsHours { fields.append(.hours) }
            fields += [.minutes, .seconds]
            if showsTenths { fields.append(.tenths) }
        case .pace:
            fields += [.paceMinutes, .paceSeconds]
            if showsPaceTenths { fields.append(.paceTenths) }
        }
        return fields
    }

    private func moveFocus(by offset: Int) {
        let fields = visibleFields
        guard let current = focus, let index = fields.firstIndex(of: current) else { return }
        let next = index + offset
        if fields.indices.contains(next) { focus = fields[next] }
    }

    /// 数字以外を除去し、桁が埋まったら次の欄へ送る（テンキーには「次へ」が無いため）
    private func handleInput(_ value: String, field: InputField, maxLength: Int, assign: (String) -> Void) {
        let cleaned = InputFilter.digits(value, maxLength: maxLength)
        if cleaned != value {
            assign(cleaned)
            return
        }
        guard focus == field, cleaned.count >= maxLength else { return }
        moveFocus(by: 1)
    }

    /// 以前のバージョンで保存した "30.5" 形式の秒を、秒と 1/10 秒に分ける
    private func migrateDecimalSeconds() {
        for (sec, tenth) in [($seconds, $tenths), ($paceSeconds, $paceTenths)] {
            let parts = sec.wrappedValue.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            sec.wrappedValue = String(parts[0].prefix(2))
            tenth.wrappedValue = String(parts[1].prefix(1))
        }
    }

    private func clear() {
        hours = ""
        minutes = ""
        seconds = ""
        tenths = ""
        paceMinutes = ""
        paceSeconds = ""
        paceTenths = ""
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
    var compact = false
    var focus: FocusState<InputField?>.Binding
    let field: InputField

    var body: some View {
        VStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
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
                .lineLimit(1)
                .fixedSize()
        }
        .frame(maxWidth: compact ? CGFloat(60) : CGFloat.infinity)
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

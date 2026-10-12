import CoreGraphics
import Foundation
import Testing
@testable import PaceCalculator

struct PaceMathTests {
    @Test func parseHMS() {
        #expect(PaceMath.parseHMS("", "", "") == nil)
        #expect(PaceMath.parseHMS("", "0", "0") == nil)
        #expect(PaceMath.parseHMS("1", "30", "15") == 5415)
        #expect(PaceMath.parseHMS("", "14", "30.5") == 870.5)
        #expect(PaceMath.parseHMS("", "", "58.3") == 58.3)
        #expect(PaceMath.parseHMS("", "x", "1") == nil)
    }

    @Test func fiveThousandIn16_40() {
        let pace = PaceMath.pace(meters: 5000, seconds: 1000)
        #expect(pace == 200)
        #expect(TimeFormat.pace(pace) == "3'20\"")
        #expect(TimeFormat.pace(pace * 0.4, decimals: 1) == "1'20\"0")
        #expect(PaceMath.speedKmh(secPerKm: pace) == 18)
    }

    @Test func marathonIn3Hours() {
        let pace = PaceMath.pace(meters: 42195, seconds: 3 * 3600)
        #expect(TimeFormat.pace(pace) == "4'16\"")
        #expect(TimeFormat.pace(pace * 0.4, decimals: 1) == "1'42\"4")
        #expect(TimeFormat.clock(PaceMath.time(meters: 42195, secPerKm: pace)) == "3:00:00")
    }

    @Test func perKmPaceWithTenths() {
        // 5000m 17:03 → 204.6 秒/km
        let pace = PaceMath.pace(meters: 5000, seconds: 17 * 60 + 3)
        #expect(TimeFormat.pace(pace, decimals: 1) == "3'24\"6")
        // フル 3:00:00 → 255.95 秒/km
        #expect(TimeFormat.pace(PaceMath.pace(meters: 42195, seconds: 3 * 3600), decimals: 1) == "4'16\"0")
    }

    @Test func halfAt4MinPace() {
        #expect(TimeFormat.clock(PaceMath.time(meters: 21097.5, secPerKm: 240)) == "1:24:23")
    }

    @Test func roundingCarriesOver() {
        #expect(TimeFormat.pace(59.96, decimals: 1) == "1'00\"0")
        #expect(TimeFormat.pace(119.6) == "2'00\"")
        #expect(TimeFormat.clock(3599.6) == "1:00:00")
        #expect(TimeFormat.clock(870.56, decimals: 1) == "14:30.6")
        #expect(TimeFormat.pace(58.3, decimals: 1) == "58\"3")
    }

    @Test func distanceFormat() {
        #expect(TimeFormat.distance(400) == "400m")
        #expect(TimeFormat.distance(1000) == "1km")
        #expect(TimeFormat.distance(21097.5) == "21.0975km")
        #expect(TimeFormat.distance(42195) == "42.195km")
        #expect(TimeFormat.distance(12500) == "12.5km")
    }

    @Test func splitIntervals() {
        #expect(PaceMath.splitOptions(meters: 400) == [100, 200])
        #expect(PaceMath.defaultSplit(meters: 400) == 100)
        #expect(PaceMath.defaultSplit(meters: 1500) == 400)
        #expect(PaceMath.defaultSplit(meters: 5000) == 400)
        #expect(PaceMath.defaultSplit(meters: 10000) == 1000)
        #expect(PaceMath.defaultSplit(meters: 42195) == 5000)
        #expect(PaceMath.defaultSplit(meters: 150) == nil)
    }

    @Test func splitRows() {
        let rows = PaceMath.splits(meters: 1500, secPerKm: 160, interval: 400)
        #expect(rows.map(\.meters) == [400, 800, 1200, 1500])
        #expect(rows.last?.seconds == 240)

        let full = PaceMath.splits(meters: 42195, secPerKm: 240, interval: 5000)
        #expect(full.count == 9)
        #expect(full.last?.meters == 42195)

        // ちょうど割り切れる距離でゴールが重複しない
        #expect(PaceMath.splits(meters: 5000, secPerKm: 200, interval: 1000).map(\.meters) == [1000, 2000, 3000, 4000, 5000])
    }

    @Test func riegel() {
        #expect(PaceMath.riegel(meters: 5000, seconds: 1200, target: 5000) == 1200)
        let t10k = PaceMath.riegel(meters: 5000, seconds: 1200, target: 10000)
        #expect(t10k > 2400 && t10k < 2550)
    }

    @Test func joinTenths() {
        #expect(PaceMath.joinTenths("58", "3") == "58.3")
        #expect(PaceMath.joinTenths("", "5") == "0.5")
        #expect(PaceMath.joinTenths("20", "") == "20")
        #expect(PaceMath.parseHMS("", "1", PaceMath.joinTenths("04", "5")) == 64.5)
    }

    @Test func digitsInput() {
        #expect(InputFilter.digits("1a2", maxLength: 3) == "12")
        #expect(InputFilter.digits("12.5", maxLength: 3) == "125")
        #expect(InputFilter.digits("12345", maxLength: 2) == "12")
        #expect(InputFilter.digits("１2", maxLength: 2) == "2")
    }

    @Test func sanitizeInput() {
        #expect(InputFilter.sanitize("1a2", maxLength: 3) == "12")
        #expect(InputFilter.sanitize("12,5", maxLength: 5) == "12.5")
        #expect(InputFilter.sanitize("1.2.3", maxLength: 5) == "1.23")
        #expect(InputFilter.sanitize("12345", maxLength: 2) == "12")
    }
}

struct FavoriteTests {
    @Test func timeInputSummary() {
        let input = PaceInput(mode: .time, event: .m5000, minutes: "16", seconds: "40")
        #expect(input.summary == "5000m 16:40.0")
        #expect(input.resultText == "3'20\"0/km")
    }

    @Test func paceInputSummary() {
        let km = PaceInput(mode: .pace, event: .half, paceMinutes: "4", paceSeconds: "00", paceUnit: .km)
        #expect(km.summary == "ハーフ 4'00\"/km")
        #expect(km.resultText == "1:24:23")

        let lap = PaceInput(mode: .pace, event: .m1500, paceMinutes: "1", paceSeconds: "04", paceTenths: "0", paceUnit: .lap400)
        #expect(lap.summary == "1500m 1'04\"0/400m")
        #expect(lap.resultText == "4:00.0")
    }

    @Test func customDistanceSummary() {
        let input = PaceInput(mode: .time, event: .custom, customValue: "12.5", customUnit: .km, hours: "1", minutes: "00", seconds: "00")
        #expect(input.summary == "12.5km 1:00:00")
        #expect(input.resultText == "4'48\"0/km")
    }

    @Test func incompleteInputHasNoResult() {
        let input = PaceInput(mode: .time, event: .full)
        #expect(input.result == nil)
        #expect(input.resultText == nil)
        #expect(input.summary == "フル")
    }

    @Test func storeRoundTrip() {
        let favorites = [
            Favorite(name: "5000m 自己ベスト", input: PaceInput(mode: .time, event: .m5000, minutes: "16", seconds: "40", tenths: "5")),
            Favorite(name: "フル 目標", input: PaceInput(mode: .pace, event: .full, paceMinutes: "4", paceSeconds: "15")),
        ]
        #expect(FavoriteStore.decode(FavoriteStore.encode(favorites)) == favorites)
    }

    @Test func storeToleratesEmptyAndBrokenData() {
        #expect(FavoriteStore.decode(Data()).isEmpty)
        #expect(FavoriteStore.decode(Data("not json".utf8)).isEmpty)
    }

    @Test func decodesInputWithMissingKeys() throws {
        let json = #"[{"id":"7F1C2E4A-1B2C-4D5E-8F90-123456789ABC","name":"古い形式","input":{"mode":"time","event":"m400","seconds":"58"}}]"#
        let favorites = FavoriteStore.decode(Data(json.utf8))
        #expect(favorites.count == 1)
        let input = try #require(favorites.first?.input)
        #expect(input.event == .m400)
        #expect(input.tenths == "")
        #expect(input.paceUnit == .km)
        #expect(input.result?.seconds == 58)
    }
}

struct DrawerSwipeTests {
    @Test func horizontalDetection() {
        #expect(DrawerSwipe.isHorizontal(CGSize(width: 40, height: 5)))
        #expect(DrawerSwipe.isHorizontal(CGSize(width: -40, height: 10)))
        #expect(!DrawerSwipe.isHorizontal(CGSize(width: 10, height: 40)))
        #expect(!DrawerSwipe.isHorizontal(CGSize(width: 30, height: 25)))
    }

    @Test func openAndCloseThresholds() {
        #expect(DrawerSwipe.shouldOpen(translation: 120, predicted: 120, panelWidth: 300))
        #expect(!DrawerSwipe.shouldOpen(translation: 50, predicted: 60, panelWidth: 300))
        #expect(DrawerSwipe.shouldOpen(translation: 50, predicted: 200, panelWidth: 300))
        #expect(DrawerSwipe.shouldClose(translation: -120, predicted: -120, panelWidth: 300))
        #expect(!DrawerSwipe.shouldClose(translation: -50, predicted: -60, panelWidth: 300))
    }

    @Test func progressFollowsFinger() {
        #expect(DrawerSwipe.progress(isOpen: false, dragX: 0, panelWidth: 300) == 0)
        #expect(DrawerSwipe.progress(isOpen: false, dragX: 150, panelWidth: 300) == 0.5)
        #expect(DrawerSwipe.progress(isOpen: false, dragX: 600, panelWidth: 300) == 1)
        #expect(DrawerSwipe.progress(isOpen: true, dragX: 0, panelWidth: 300) == 1)
        #expect(DrawerSwipe.progress(isOpen: true, dragX: -75, panelWidth: 300) == 0.75)
        #expect(DrawerSwipe.progress(isOpen: true, dragX: -900, panelWidth: 300) == 0)
    }
}

struct DistanceStepTests {
    @Test func kilometers() {
        #expect(DistanceStep.apply(100, to: "12.5", unit: .km) == "12.6")
        #expect(DistanceStep.apply(-1000, to: "12.5", unit: .km) == "11.5")
        #expect(DistanceStep.apply(100, to: "42.195", unit: .km) == "42.295")
        #expect(DistanceStep.apply(1000, to: "", unit: .km) == "1")
    }

    @Test func meters() {
        #expect(DistanceStep.apply(100, to: "400", unit: .m) == "500")
        #expect(DistanceStep.apply(-1000, to: "1500", unit: .m) == "500")
        #expect(DistanceStep.apply(1000, to: "", unit: .m) == "1000")
    }

    @Test func neverBelowZero() {
        #expect(DistanceStep.apply(-100, to: "0.05", unit: .km) == "0")
        #expect(DistanceStep.apply(-1000, to: "300", unit: .m) == "0")
        #expect(DistanceStep.apply(-100, to: "", unit: .m) == "0")
    }

    @Test func labels() {
        #expect(DistanceStep.steps.map(DistanceStep.label) == ["−1km", "−100m", "+100m", "+1km"])
    }
}

struct SameCalculationTests {
    @Test func sameValuesWrittenDifferently() {
        let a = PaceInput(mode: .time, event: .m5000, minutes: "16", seconds: "05")
        let b = PaceInput(mode: .time, event: .m5000, minutes: "16", seconds: "5")
        #expect(a.isSameCalculation(as: b))
    }

    @Test func customDistanceMatchesEvent() {
        let event = PaceInput(mode: .time, event: .m5000, minutes: "20", seconds: "00")
        let custom = PaceInput(mode: .time, event: .custom, customValue: "5", customUnit: .km, minutes: "20", seconds: "00")
        #expect(event.isSameCalculation(as: custom))
    }

    @Test func differentCalculations() {
        let base = PaceInput(mode: .time, event: .m5000, minutes: "16", seconds: "40")
        #expect(!base.isSameCalculation(as: PaceInput(mode: .time, event: .m5000, minutes: "16", seconds: "41")))
        #expect(!base.isSameCalculation(as: PaceInput(mode: .time, event: .m3000, minutes: "16", seconds: "40")))
        #expect(!base.isSameCalculation(as: PaceInput(mode: .pace, event: .m5000, paceMinutes: "3", paceSeconds: "20")))
    }

    @Test func paceUnitMatters() {
        let km = PaceInput(mode: .pace, event: .half, paceMinutes: "4", paceSeconds: "00", paceUnit: .km)
        let lap = PaceInput(mode: .pace, event: .half, paceMinutes: "1", paceSeconds: "36", paceTenths: "0", paceUnit: .lap400)
        #expect(!km.isSameCalculation(as: lap))
        #expect(km.isSameCalculation(as: km))
    }

    @Test func incompleteInputNeverMatches() {
        let empty = PaceInput(mode: .time, event: .m5000)
        #expect(!empty.isSameCalculation(as: empty))
    }

    @Test func toastTexts() {
        let favorite = Favorite(name: "5000m 16:40.0", input: PaceInput())
        #expect(FavoriteToast.added(favorite).message == "「5000m 16:40.0」をお気に入りに追加しました")
        #expect(FavoriteToast.added(favorite).actionTitle == "名前を付ける")
        #expect(FavoriteToast.removed(favorite, index: 0).actionTitle == "元に戻す")
    }
}

struct TimeStepTests {
    private func step(_ delta: Int, _ m: String, _ s: String, _ t: String = "", hours h: String = "",
                      usesHours: Bool = false, usesTenths: Bool = false) -> TimeStep.Fields {
        TimeStep.apply(delta, to: .init(hours: h, minutes: m, seconds: s, tenths: t), usesHours: usesHours, usesTenths: usesTenths)
    }

    @Test func labels() {
        #expect(TimeStep.label(1, sign: .plus) == "+1秒")
        #expect(TimeStep.label(10, sign: .minus) == "−10秒")
        #expect(TimeStep.label(60, sign: .plus) == "+1分")
        #expect(TimeStep.label(300, sign: .minus) == "−5分")
        #expect(StepSign.minus.multiplier == -1 && StepSign.plus.multiplier == 1)
        // 足し算が左、数字は左ほど大きい
        #expect(StepSign.allCases == [.plus, .minus])
        #expect(TimeStep.timeSteps == [300, 60, 10, 1])
        #expect(TimeStep.paceSteps == [60, 10, 5, 1])
    }

    @Test func longPressAccelerates() {
        // 1秒 → 5回ごとに 5秒 → 10秒 で頭打ち
        #expect((0..<5).allSatisfy { TimeStep.accelerated(1, repeats: $0) == 1 })
        #expect(TimeStep.accelerated(1, repeats: 5) == 5)
        #expect(TimeStep.accelerated(1, repeats: 10) == 10)
        #expect(TimeStep.accelerated(1, repeats: 100) == 10)
        #expect(TimeStep.accelerated(10, repeats: 10) == 60)
        #expect(TimeStep.accelerated(60, repeats: 5) == 300)
        // 5分は 10分 が上限
        #expect(TimeStep.accelerated(300, repeats: 100) == 600)
        // すべてのボタンの幅が段に載っている
        #expect((TimeStep.timeSteps + TimeStep.paceSteps).allSatisfy { TimeStep.ladder.contains($0) })
        #expect(TimeStep.label(600, sign: .plus) == "+10分")
        #expect(TimeStep.label(30, sign: .minus) == "−30秒")
    }

    @Test func carriesSecondsIntoMinutes() {
        #expect(step(10, "16", "55") == .init(minutes: "17", seconds: "05"))
        #expect(step(-10, "17", "05") == .init(minutes: "16", seconds: "55"))
        #expect(step(300, "16", "40") == .init(minutes: "21", seconds: "40"))
    }

    @Test func emptyFieldsStartFromZero() {
        #expect(step(60, "", "") == .init(minutes: "1", seconds: "00"))
    }

    @Test func neverBelowZero() {
        #expect(step(-10, "0", "05") == .init(minutes: "0", seconds: "00"))
        #expect(step(-300, "", "") == .init(minutes: "0", seconds: "00"))
    }

    @Test func keepsTenths() {
        #expect(step(1, "1", "20", "5", usesTenths: true) == .init(minutes: "1", seconds: "21", tenths: "5"))
        // 1/10 秒欄が空なら空のまま
        #expect(step(1, "1", "20", "", usesTenths: true) == .init(minutes: "1", seconds: "21", tenths: ""))
        // 使っていない 1/10 秒欄には触らない
        #expect(step(1, "16", "40", "7") == .init(minutes: "16", seconds: "41", tenths: "7"))
    }

    @Test func hours() {
        #expect(step(60, "59", "30", usesHours: true) == .init(hours: "1", minutes: "00", seconds: "30"))
        #expect(step(-300, "02", "00", hours: "1", usesHours: true) == .init(hours: "", minutes: "57", seconds: "00"))
        // 時間欄を出していないときは時間欄を無視して残す
        #expect(step(60, "59", "30", hours: "3") == .init(hours: "3", minutes: "60", seconds: "30"))
    }

    @Test func clampsToFieldLimits() {
        #expect(step(300, "99", "00") == .init(minutes: "99", seconds: "59"))
        #expect(step(60, "99", "30", "", usesTenths: true) == .init(minutes: "99", seconds: "59", tenths: "9"))
        #expect(step(300, "59", "00", hours: "99", usesHours: true) == .init(hours: "99", minutes: "59", seconds: "59"))
    }
}

# ペース計算（time_caliculator）

陸上・マラソンのランナー向けペース計算 iPhone アプリ（SwiftUI）。

## できること

- **タイム → ペース**：種目（距離）とタイムから
  - 1kmあたりのペース（例 `3'20"0/km`、0.1秒まで表示）
  - 400mあたりのタイム（例 `1'20"0`）
  - 200m / 100m あたり、時速
  - スプリット表（100m / 200m / 400m / 1km / 5km から切替）
  - Riegel 式による他種目の予想タイム
- **ペース → タイム**：`/km` または `/400m` のペースから
  - ゴールタイム、もう一方の単位のペース
  - スプリット表、同ペースでの各種目タイム
- 種目は **400m / 800m / 1500m / 3000m / 5000m / 10000m / ハーフ / フル** をワンタップで選択。それ以外は「距離入力」（km / m）
- 入力した瞬間に結果を更新。前回の入力は端末に保存
- 時間・分・秒は数字だけのテンキー（numberPad）で入力。桁が埋まると次の欄へ自動移動、キーボード上の ∧∨ / 完了ボタン、ダークモード対応
- 0.1 秒単位は専用の「1/10秒」欄で入力（トラック種目のタイム、/400m ペースのとき表示）

## プライバシーポリシー

https://ryosukehys.github.io/pace-calculator/privacy-policy.html

## 必要環境

- Xcode 16 以降（macOS）
- iOS 17 以降の iPhone

## iPhone で動かす

1. `PaceCalculator.xcodeproj` を Xcode で開く
2. プロジェクト → ターゲット **PaceCalculator** → **Signing & Capabilities** → **Team** で自分の Apple Developer アカウントを選ぶ
   - Bundle Identifier（`com.ryosukehys.PaceCalculator`）が使えないと言われたら、任意の一意な ID に変更する
3. iPhone を Mac に接続し、上部の実行先で自分の iPhone を選んで ▶︎（⌘R）
   - 初回は iPhone の **設定 → プライバシーとセキュリティ → デベロッパモード** をオンにする

TestFlight で配る場合は **Product → Archive** → Organizer から App Store Connect にアップロードする。

## 開発

| パス | 役割 |
| --- | --- |
| `PaceCalculator/Pace.swift` | 計算ロジック・表示フォーマット（純粋関数） |
| `PaceCalculator/ContentView.swift` | 入力画面 |
| `PaceCalculator/ResultsView.swift` | 結果表示（ペース・スプリット・予想タイム） |
| `PaceCalculator/Assets.xcassets` | アプリアイコン・アクセントカラー |
| `PaceCalculatorTests/` | ユニットテスト（Swift Testing） |

テストは Xcode で ⌘U、または:

```sh
xcodebuild test -project PaceCalculator.xcodeproj -scheme PaceCalculator \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

プルリクエストと `main` への push では GitHub Actions（macOS）でビルドとテストが自動実行される。

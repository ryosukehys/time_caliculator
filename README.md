# ペース計算（time_caliculator）

陸上・マラソンのランナー向けペース計算アプリ。iPhone のホーム画面に追加して、ネイティブアプリのように使える PWA です。

## できること

- **タイム → ペース**：種目（距離）とタイムから
  - 1kmあたりのペース（例 `3'20"/km`）
  - 400mあたりのタイム（例 `1'20"0`）
  - 200m / 100m あたり、時速
  - スプリット表（100m / 200m / 400m / 1km / 5km から切替）
  - Riegel 式による他種目の予想タイム
- **ペース → タイム**：`/km` または `/400m` のペースから
  - ゴールタイム、もう一方の単位のペース
  - スプリット表、同ペースでの各種目タイム
- 種目は **400m / 800m / 1500m / 3000m / 5000m / 10000m / ハーフ / フル** をワンタップで選択。それ以外は「距離入力」（km / m）
- 入力した瞬間に結果を更新。前回の入力は端末に保存
- テンキー入力・2桁入力で次の欄へ自動移動・ダークモード対応・オフライン動作

## iPhone で使う

1. GitHub Pages で公開した URL を Safari で開く
2. 共有ボタン →「ホーム画面に追加」
3. ホーム画面のアイコンから全画面アプリとして起動

### GitHub Pages の有効化（初回のみ）

リポジトリの **Settings → Pages → Build and deployment → Source** を **GitHub Actions** にする。
以降 `main` に push するたびに `.github/workflows/pages.yml` がテスト後に自動デプロイする。

## 開発

ビルド不要の素の HTML / CSS / JavaScript です。

```sh
npm start   # http://localhost:8080 で起動
npm test    # 計算ロジックのユニットテスト（Node 22+）
```

| ファイル | 役割 |
| --- | --- |
| `index.html` / `styles.css` | 画面 |
| `js/pace.js` | 計算ロジック（純粋関数） |
| `js/app.js` | 入力・描画 |
| `sw.js` | オフライン用 Service Worker（更新時は `VERSION` を上げる） |
| `manifest.webmanifest` / `icons/` | ホーム画面追加用 |

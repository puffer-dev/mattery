# Mattery

macOS のメニューバーにバッテリー残量を色分けで常時表示する常駐アプリ。

[English](README.md) | [한국어](README.ko.md)

- 残量を色分けで表示
  - 80% 以上 → 緑
  - 51–79% → 黄
  - 15–50% → オレンジ
  - 14% 以下 → 赤
- 低残量アラート（メニューから 通知 / 音 / 両方 / オフ を選択）
  - 2–5%: バッテリー駆動中（非充電中）のみ発火
  - 1% 以下: 充電状態に関わらず発火
  - 低残量ゾーンに留まる間 60 秒おきに再発火
- 充電中はアイコンが稲妻に切り替わり、メニューに `Time to Full` / `Charging…` を表示
- Launch at Login（`SMAppService.mainApp`）
- 残量パーセンテージの非表示トグル
- アプリ別バッテリー使用率分析（過去 24h）
  - 10 分間隔で `top` の Energy Impact を蓄積
  - チャート（時間別 stacked bar） / リスト（ソート可能テーブル）の切替
  - データは `~/Library/Application Support/Mattery/samples.jsonl` に永続化

## 必要環境

- macOS 13 Ventura 以降
- Xcode 16 以降 / Swift 5.9
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

## ビルド

```sh
xcodegen generate
xcodebuild -project Mattery.xcodeproj -scheme Mattery -configuration Debug -destination 'platform=macOS' build
```

または `Mattery.xcodeproj` を Xcode で開いて Run。

## リリース

`/Applications/Mattery.app` に Release ビルドを配置して再起動するスクリプト:

```sh
./scripts/release.sh
```

走っている Mattery を終了 → Release ビルド → `/Applications` に置換 → 起動、を一発で行う。

## アーキテクチャ

| File | 役割 |
| --- | --- |
| `MatteryApp.swift` | `@main`。`NSApplicationDelegateAdaptor` で `AppDelegate` を接続、ウィンドウなしの `Settings` シーンのみ |
| `AppDelegate.swift` | 起動時に `BatteryMonitor` / `LowBatteryAlerter` / `EnergySampler` / `StatusBarController` / `AnalyticsWindowController` を組み立てて保持 |
| `BatteryStatus.swift` | バッテリー状態の値型 |
| `BatteryMonitor.swift` | IOPS でスナップショットを取得、`IOPSNotificationCreateRunLoopSource` + 30s ポーリングで購読 |
| `StatusBarController.swift` | `NSStatusItem` の構築・更新、メニュー組み立て |
| `LowBatteryAlerter.swift` | 5% / 1% ゾーンへの侵入をライジングエッジ検知、ゾーン内では 60 秒おきに再発火 |
| `LaunchAtLoginManager.swift` | `SMAppService.mainApp` ラッパ |
| `PreferencesStore.swift` | `UserDefaults` ラッパ（`hidePercentage`, `lowAlertMode`） |
| `EnergySampler.swift` | 10 分間隔で `top -l 2 -s 1 -o power -stats power,command` を実行・パース |
| `EnergyStore.swift` | サンプルの永続化と 24h ローリング窓集計（アプリ別シェア + 時間別 breakdown） |
| `AnalyticsView.swift` | SwiftUI でチャート / リスト切替 UI を構築 |
| `AnalyticsWindowController.swift` | `NSWindowController` で SwiftUI ビューをホスト |

`Info.plist` の `LSUIElement = YES` で Dock とアプリスイッチャから外し、メニューバー専用化している。

## ライセンス

Apache License 2.0 — [LICENSE](LICENSE) を参照。

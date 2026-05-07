# Mattery

macOS 메뉴바에 배터리 잔량을 색상으로 항상 표시하는 상주 앱.

[English](README.md) | [日本語](README.ja.md)

- 잔량을 색상으로 표시
  - 80% 이상 → 초록
  - 51–79% → 노랑
  - 15–50% → 주황
  - 14% 이하 → 빨강
- 저전력 알림 (메뉴에서 알림 / 소리 / 둘 다 / 끄기 선택)
  - 2–5%: 충전 중이 아닐 때만 발동
  - 1% 이하: 충전 상태와 관계없이 발동
  - 저전력 영역에 머무는 동안 60초마다 재발동
- 충전 중에는 아이콘이 번개로 바뀌고, 메뉴에 `Time to Full` / `Charging…` 표시
- 로그인 시 자동 시작 (`SMAppService.mainApp`)
- 잔량 퍼센트 표시 토글
- 앱별 배터리 사용률 분석 (지난 24시간)
  - 10분 간격으로 `top` 의 Energy Impact 누적
  - 차트 (시간별 stacked bar) / 리스트 (정렬 가능한 테이블) 전환
  - 데이터는 `~/Library/Application Support/Mattery/samples.jsonl` 에 영구 저장

## 요구 사항

- macOS 13 Ventura 이상
- Xcode 16 이상 / Swift 5.9
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

## 빌드

```sh
xcodegen generate
xcodebuild -project Mattery.xcodeproj -scheme Mattery -configuration Debug -destination 'platform=macOS' build
```

또는 `Mattery.xcodeproj` 를 Xcode 에서 열고 Run.

## 릴리스

`/Applications/Mattery.app` 에 Release 빌드를 배치하고 재시작하는 스크립트:

```sh
./scripts/release.sh
```

실행 중인 Mattery 종료 → Release 빌드 → `/Applications` 에 교체 → 실행을 한 번에 수행.

## 아키텍처

| File | 역할 |
| --- | --- |
| `MatteryApp.swift` | `@main`. `NSApplicationDelegateAdaptor` 로 `AppDelegate` 연결, 창 없는 `Settings` 씬만 |
| `AppDelegate.swift` | 시작 시 `BatteryMonitor` / `LowBatteryAlerter` / `EnergySampler` / `StatusBarController` / `AnalyticsWindowController` 를 구성·보유 |
| `BatteryStatus.swift` | 배터리 상태의 값 타입 |
| `BatteryMonitor.swift` | IOPS 스냅샷 획득, `IOPSNotificationCreateRunLoopSource` + 30초 폴링으로 구독 |
| `StatusBarController.swift` | `NSStatusItem` 구축·갱신, 메뉴 구성 |
| `LowBatteryAlerter.swift` | 5% / 1% 영역 진입을 라이징 엣지로 감지, 영역 안에서는 60초마다 재발동 |
| `LaunchAtLoginManager.swift` | `SMAppService.mainApp` 래퍼 |
| `PreferencesStore.swift` | `UserDefaults` 래퍼 (`hidePercentage`, `lowAlertMode`) |
| `EnergySampler.swift` | 10분 간격으로 `top -l 2 -s 1 -o power -stats power,command` 실행·파싱 |
| `EnergyStore.swift` | 샘플 영구 저장 및 24h 롤링 윈도우 집계 (앱별 점유율 + 시간별 분포) |
| `AnalyticsView.swift` | SwiftUI 로 차트 / 리스트 전환 UI 구성 |
| `AnalyticsWindowController.swift` | `NSWindowController` 로 SwiftUI 뷰 호스팅 |

`Info.plist` 의 `LSUIElement = YES` 로 Dock 과 앱 전환자에서 빠져, 메뉴바 전용으로 동작.

## 라이선스

Apache License 2.0 — [LICENSE](LICENSE) 참고.

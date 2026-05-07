import Foundation
import UserNotifications
import AppKit

final class LowBatteryAlerter {
    private let prefs: PreferencesStore
    private let center = UNUserNotificationCenter.current()

    private var wasInWarningZone = false
    private var wasInCriticalZone = false
    private var lastPercentage: Int = 100

    private var warningTimer: Timer?
    private var criticalTimer: Timer?
    private let repeatInterval: TimeInterval = 60

    init(prefs: PreferencesStore = .shared) {
        self.prefs = prefs
    }

    func ensureAuthorizationIfNeeded() {
        let mode = prefs.lowAlertMode
        guard mode == .notification || mode == .both else { return }
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func handle(status: BatteryStatus) {
        guard status.hasBattery else {
            stopWarningRepeat()
            stopCriticalRepeat()
            wasInWarningZone = false
            wasInCriticalZone = false
            return
        }

        let p = status.percentage
        lastPercentage = p
        let inCritical = p <= 1
        let inWarning = p >= 2 && p <= 5 && !status.isCharging

        if inCritical {
            if !wasInCriticalZone {
                fire(percent: p, critical: true)
                startCriticalRepeat()
            }
        } else {
            stopCriticalRepeat()
        }

        if inWarning {
            if !wasInWarningZone {
                fire(percent: p, critical: false)
                startWarningRepeat()
            }
        } else {
            stopWarningRepeat()
        }

        wasInCriticalZone = inCritical
        wasInWarningZone = inWarning
    }

    private func startWarningRepeat() {
        warningTimer?.invalidate()
        warningTimer = Timer.scheduledTimer(withTimeInterval: repeatInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.fire(percent: self.lastPercentage, critical: false)
        }
    }

    private func stopWarningRepeat() {
        warningTimer?.invalidate()
        warningTimer = nil
    }

    private func startCriticalRepeat() {
        criticalTimer?.invalidate()
        criticalTimer = Timer.scheduledTimer(withTimeInterval: repeatInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.fire(percent: self.lastPercentage, critical: true)
        }
    }

    private func stopCriticalRepeat() {
        criticalTimer?.invalidate()
        criticalTimer = nil
    }

    private func fire(percent: Int, critical: Bool) {
        switch prefs.lowAlertMode {
        case .off:
            break
        case .notification:
            postNotification(percent: percent, critical: critical)
        case .sound:
            playSound()
        case .both:
            postNotification(percent: percent, critical: critical)
            playSound()
        }
    }

    private func postNotification(percent: Int, critical: Bool) {
        let content = UNMutableNotificationContent()
        if critical {
            content.title = "Critical Battery"
            content.body = "Battery at \(percent)% — connect to power immediately."
        } else {
            content.title = "Low Battery"
            content.body = "Battery at \(percent)% — please connect to power."
        }
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    private func playSound() {
        NSSound(named: NSSound.Name("Funk"))?.play()
    }
}

import Foundation
import UserNotifications
import AppKit

final class LowBatteryAlerter {
    private let prefs: PreferencesStore
    private let center = UNUserNotificationCenter.current()

    private var wasInWarningZone = false
    private var wasInCriticalZone = false

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
            wasInWarningZone = false
            wasInCriticalZone = false
            return
        }

        let p = status.percentage
        let inCritical = p <= 1
        let inWarning = p >= 2 && p <= 5 && !status.isCharging

        if inCritical && !wasInCriticalZone {
            fire(percent: p, critical: true)
        } else if inWarning && !wasInWarningZone {
            fire(percent: p, critical: false)
        }

        wasInCriticalZone = inCritical
        wasInWarningZone = inWarning
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

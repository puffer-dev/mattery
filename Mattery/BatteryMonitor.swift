import Foundation
import IOKit.ps
import Combine

final class BatteryMonitor {
    private(set) var status: BatteryStatus = .unavailable
    let statusChanged = PassthroughSubject<BatteryStatus, Never>()

    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?

    func start() {
        refresh()
        installRunLoopSource()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refresh() {
        let new = Self.read()
        guard new != status else { return }
        status = new
        statusChanged.send(new)
    }

    private func installRunLoopSource() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { monitor.refresh() }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            return
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private static func read() -> BatteryStatus {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let descUnmanaged = IOPSGetPowerSourceDescription(snapshot, first),
              let desc = descUnmanaged.takeUnretainedValue() as? [String: Any] else {
            return .unavailable
        }

        let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let percentage = max > 0 ? Int((Double(current) / Double(max)) * 100.0) : 0

        let stateString = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        let isOnAC = (stateString == kIOPSACPowerValue)
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false

        let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int ?? -1
        let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int ?? -1

        return BatteryStatus(
            hasBattery: true,
            percentage: percentage,
            isCharging: isCharging,
            powerSource: isOnAC ? .ac : .battery,
            timeToEmptyMinutes: timeToEmpty > 0 ? timeToEmpty : nil,
            timeToFullMinutes: timeToFull > 0 ? timeToFull : nil
        )
    }
}

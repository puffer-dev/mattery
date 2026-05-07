import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = BatteryMonitor()
    private let alerter = LowBatteryAlerter()
    private let energyStore = EnergyStore()
    private lazy var energySampler = EnergySampler(store: energyStore)
    private lazy var analyticsWindow = AnalyticsWindowController(store: energyStore)
    private var statusBar: StatusBarController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusBar = StatusBarController(monitor: monitor) { [weak self] in
            self?.analyticsWindow.show()
        }

        monitor.statusChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.alerter.handle(status: status)
            }
            .store(in: &cancellables)

        alerter.ensureAuthorizationIfNeeded()
        monitor.start()
        monitor.refresh()
        energySampler.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        energySampler.stop()
    }
}

import AppKit
import Combine

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let monitor: BatteryMonitor
    private let prefs: PreferencesStore
    private let onShowAnalytics: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        monitor: BatteryMonitor,
        prefs: PreferencesStore = .shared,
        onShowAnalytics: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.prefs = prefs
        self.onShowAnalytics = onShowAnalytics
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem.autosaveName = "com.puffer.Mattery.statusItem"

        monitor.statusChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)

        prefs.didChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)

        update()
    }

    private func update() {
        let status = monitor.status
        applyButton(for: status)
        statusItem.menu = buildMenu(for: status)
    }

    private func applyButton(for status: BatteryStatus) {
        guard let button = statusItem.button else { return }

        button.image = icon(for: status)
        button.image?.isTemplate = true
        button.imagePosition = .imageLeft

        if !status.hasBattery {
            button.attributedTitle = NSAttributedString(
                string: "No Battery",
                attributes: [.foregroundColor: NSColor.labelColor]
            )
            return
        }

        if prefs.hidePercentage {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
            return
        }

        let color: NSColor
        switch status.percentage {
        case 80...:
            color = .systemGreen
        case 51..<80:
            color = .systemYellow
        case 15..<51:
            color = .systemOrange
        default:
            color = .systemRed
        }

        button.attributedTitle = NSAttributedString(
            string: " \(status.percentage)%",
            attributes: [.foregroundColor: color]
        )
    }

    private func icon(for status: BatteryStatus) -> NSImage? {
        let symbolName: String
        if !status.hasBattery {
            symbolName = "bolt.slash"
        } else if status.isCharging {
            symbolName = "bolt.fill"
        } else {
            switch status.percentage {
            case 88...: symbolName = "battery.100percent"
            case 63...: symbolName = "battery.75percent"
            case 38...: symbolName = "battery.50percent"
            case 13...: symbolName = "battery.25percent"
            default:    symbolName = "battery.0percent"
            }
        }
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: "Battery")
    }

    private func buildMenu(for status: BatteryStatus) -> NSMenu {
        let menu = NSMenu()

        let timeItem = NSMenuItem(title: timeLabel(for: status), action: nil, keyEquivalent: "")
        timeItem.isEnabled = false
        menu.addItem(timeItem)

        let sourceItem = NSMenuItem(title: powerSourceLabel(for: status), action: nil, keyEquivalent: "")
        sourceItem.isEnabled = false
        menu.addItem(sourceItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide Percentage",
            action: #selector(toggleHidePercentage),
            keyEquivalent: ""
        )
        hideItem.target = self
        hideItem.state = prefs.hidePercentage ? .on : .off
        menu.addItem(hideItem)

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchItem)

        let alertItem = NSMenuItem(title: "Low Battery Alert", action: nil, keyEquivalent: "")
        alertItem.submenu = buildAlertSubmenu()
        menu.addItem(alertItem)

        menu.addItem(.separator())

        let analyticsItem = NSMenuItem(
            title: "Show Analytics…",
            action: #selector(showAnalytics),
            keyEquivalent: ""
        )
        analyticsItem.target = self
        menu.addItem(analyticsItem)

        let settingsItem = NSMenuItem(
            title: "Battery Settings…",
            action: #selector(openBatterySettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit Mattery",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func buildAlertSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let entries: [(String, LowAlertMode)] = [
            ("Notification", .notification),
            ("Sound", .sound),
            ("Notification + Sound", .both),
            ("Off", .off)
        ]
        let current = prefs.lowAlertMode
        for (title, mode) in entries {
            let item = NSMenuItem(
                title: title,
                action: #selector(selectAlertMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = (mode == current) ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    private func timeLabel(for status: BatteryStatus) -> String {
        guard status.hasBattery else { return "No Battery" }
        if status.isCharging, let minutes = status.timeToFullMinutes {
            return "Time to Full: \(format(minutes: minutes))"
        }
        if status.isCharging {
            return "Charging…"
        }
        if status.isOnAC {
            return "Fully Charged"
        }
        if let minutes = status.timeToEmptyMinutes {
            return "Time to Empty: \(format(minutes: minutes))"
        }
        return "Calculating…"
    }

    private func powerSourceLabel(for status: BatteryStatus) -> String {
        guard status.hasBattery else { return "Power Source: —" }
        let source = status.isOnAC ? "Power Adapter" : "Battery"
        return "Power Source: \(source)"
    }

    private func format(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    @objc private func toggleHidePercentage() {
        prefs.hidePercentage.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLoginManager.setEnabled(!LaunchAtLoginManager.isEnabled)
        update()
    }

    @objc private func selectAlertMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = LowAlertMode(rawValue: raw) else { return }
        prefs.lowAlertMode = mode
    }

    @objc private func showAnalytics() {
        onShowAnalytics()
    }

    @objc private func openBatterySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Battery-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.battery"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

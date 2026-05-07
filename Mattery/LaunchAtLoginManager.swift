import Foundation
import ServiceManagement
import os.log

enum LaunchAtLoginManager {
    private static let log = OSLog(subsystem: "com.puffer.Mattery", category: "LaunchAtLogin")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            os_log(
                "Failed to %{public}@ login item: %{public}@",
                log: log,
                type: .error,
                on ? "register" : "unregister",
                error.localizedDescription
            )
        }
    }
}

import Foundation
import Combine

enum LowAlertMode: String, CaseIterable {
    case notification
    case sound
    case both
    case off
}

final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults: UserDefaults
    private enum Keys {
        static let hidePercentage = "hidePercentage"
        static let lowAlertMode = "lowAlertMode"
    }

    let didChange = PassthroughSubject<Void, Never>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hidePercentage: Bool {
        get { defaults.bool(forKey: Keys.hidePercentage) }
        set {
            defaults.set(newValue, forKey: Keys.hidePercentage)
            didChange.send()
        }
    }

    var lowAlertMode: LowAlertMode {
        get {
            let raw = defaults.string(forKey: Keys.lowAlertMode) ?? ""
            return LowAlertMode(rawValue: raw) ?? .both
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.lowAlertMode)
            didChange.send()
        }
    }
}

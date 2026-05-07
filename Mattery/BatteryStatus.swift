import Foundation

struct BatteryStatus: Equatable {
    enum PowerSource: Equatable {
        case battery
        case ac
        case unknown
    }

    var hasBattery: Bool
    var percentage: Int
    var isCharging: Bool
    var powerSource: PowerSource
    var timeToEmptyMinutes: Int?
    var timeToFullMinutes: Int?

    static let unavailable = BatteryStatus(
        hasBattery: false,
        percentage: 0,
        isCharging: false,
        powerSource: .unknown,
        timeToEmptyMinutes: nil,
        timeToFullMinutes: nil
    )

    var isOnAC: Bool { powerSource == .ac }
}

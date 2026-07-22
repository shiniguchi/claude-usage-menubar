import Foundation

struct AppSettings: Codable {
    var warningThreshold: Double = 80.0
    var criticalThreshold: Double = 90.0
    var notificationsEnabled: Bool = true
    var compactDisplay: Bool = true

    var isConfigured: Bool { true }
}

enum AlertLevel {
    case warning
    case critical
}

/// Decides whether a meter crossing a threshold warrants a notification.
/// `lastWarningNotified`/`lastCriticalNotified` are the threshold values
/// already notified for this meter (0 if never), so each threshold fires once.
func evaluateAlert(percent: Int, warning: Int, critical: Int,
                   lastWarningNotified: Int, lastCriticalNotified: Int) -> AlertLevel? {
    if percent >= critical {
        return lastCriticalNotified < critical ? .critical : nil
    }
    if percent >= warning {
        return lastWarningNotified < warning ? .warning : nil
    }
    return nil
}

/// A per-model weekly limit from the API's `limits` array (e.g. Fable).
struct ScopedLimit: Equatable {
    let name: String
    let percent: Int
    let resetsIn: String?
}

struct UsageSnapshot {
    let fiveHourUtilization: Int
    let sevenDayUtilization: Int
    let scopedLimits: [ScopedLimit]
    let fiveHourResetIn: String?
    let sevenDayResetIn: String?
    let lastUpdated: Date

    var displayText: String { "\(sevenDayUtilization)%" }
    var menuBarPrimaryText: String { "5hr: \(fiveHourUtilization)%" }
    var menuBarSecondaryText: String { "Week: \(sevenDayUtilization)%" }

    static var placeholder: UsageSnapshot {
        UsageSnapshot(
            fiveHourUtilization: 0,
            sevenDayUtilization: 0,
            scopedLimits: [],
            fiveHourResetIn: nil,
            sevenDayResetIn: nil,
            lastUpdated: Date()
        )
    }
}

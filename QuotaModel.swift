import Foundation

enum QuotaWindowKind: Equatable {
    case fiveHour
    case weekly
}

func quotaWindowKind(durationMinutes: Int?) -> QuotaWindowKind? {
    guard let durationMinutes else {
        return nil
    }

    switch durationMinutes {
    case 240...360:
        return .fiveHour
    case 6 * 24 * 60...8 * 24 * 60:
        return .weekly
    default:
        return nil
    }
}

struct UsageSnapshot {
    let sourceDate: Date
    let sourceName: String
    let planType: String?
    let fiveHourUsedPercent: Int?
    let weeklyUsedPercent: Int?
    let fiveHourWindowMinutes: Int?
    let weeklyWindowMinutes: Int?
    let fiveHourResetAt: Date?
    let weeklyResetAt: Date?
    let warningMessage: String?
    let errorMessage: String?

    var fiveHourRemainingPercent: Int? {
        fiveHourUsedPercent.map { max(0, min(100, 100 - $0)) }
    }

    var weeklyRemainingPercent: Int? {
        weeklyUsedPercent.map { max(0, min(100, 100 - $0)) }
    }
}

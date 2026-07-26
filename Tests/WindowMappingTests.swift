import Foundation

@main
enum WindowMappingTests {
    static func main() {
        precondition(quotaWindowKind(durationMinutes: 300) == .fiveHour)
        precondition(quotaWindowKind(durationMinutes: 10_080) == .weekly)
        precondition(quotaWindowKind(durationMinutes: 0) == nil)
        precondition(quotaWindowKind(durationMinutes: nil) == nil)

        let weeklyOnly = snapshot(fiveHourUsed: nil, weeklyUsed: 0)
        precondition(weeklyOnly.fiveHourRemainingPercent == nil)
        precondition(weeklyOnly.weeklyRemainingPercent == 100)

        let exhaustedFiveHour = snapshot(fiveHourUsed: 100, weeklyUsed: 25)
        precondition(exhaustedFiveHour.fiveHourRemainingPercent == 0)
        precondition(exhaustedFiveHour.weeklyRemainingPercent == 75)

        let malformedValues = snapshot(fiveHourUsed: -5, weeklyUsed: 105)
        precondition(malformedValues.fiveHourRemainingPercent == 100)
        precondition(malformedValues.weeklyRemainingPercent == 0)

        let utc = TimeZone(secondsFromGMT: 0)!
        let resetDate = Date(timeIntervalSince1970: 0)
        precondition(formatQuotaResetTime(resetDate, timeZone: utc) == "1970-01-01 周四 00:00:00")

        print("Window mapping tests passed")
    }

    private static func snapshot(fiveHourUsed: Int?, weeklyUsed: Int?) -> UsageSnapshot {
        UsageSnapshot(
            sourceDate: Date(),
            sourceName: "test",
            planType: "test",
            fiveHourUsedPercent: fiveHourUsed,
            weeklyUsedPercent: weeklyUsed,
            fiveHourWindowMinutes: fiveHourUsed == nil ? nil : 300,
            weeklyWindowMinutes: weeklyUsed == nil ? nil : 10_080,
            fiveHourResetAt: nil,
            weeklyResetAt: nil,
            warningMessage: nil,
            errorMessage: nil
        )
    }
}

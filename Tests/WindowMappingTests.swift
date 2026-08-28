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

        let bankedData = """
        {
          "available_count": 3,
          "credits": [
            {
              "id": "later",
              "title": "Full reset",
              "reset_type": "full",
              "status": "available",
              "expires_at": "2026-08-13T12:34:56Z"
            },
            {
              "id": "redeemed",
              "title": "Full reset",
              "status": "redeemed",
              "expires_at": "2026-07-20T00:00:00Z"
            },
            {
              "id": "earlier",
              "title": "Full reset",
              "status": "available",
              "expires_at": "2026-07-27T00:00:00.000Z"
            },
            {
              "id": "middle",
              "title": "Full reset",
              "status": "available",
              "expires_at": "2026-08-01T08:15:30Z"
            }
          ]
        }
        """.data(using: .utf8)!
        let banked = try! parseBankedResetResponse(bankedData)
        precondition(banked.availableCount == 3)
        precondition(banked.availableCredits.map(\.id) == ["earlier", "middle", "later"])

        let utc = TimeZone(secondsFromGMT: 0)!
        let earliestExpiry = banked.availableCredits[0].expiresAt!
        precondition(
            formatBankedResetExpiry(earliestExpiry, timeZone: utc) ==
            "2026-07-27 周一 00:00:00"
        )

        OpenCodeGoParserTests.run()

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

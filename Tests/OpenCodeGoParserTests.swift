import Foundation

enum OpenCodeGoParserTests {
    static func run() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        testAllWindowsPresent(now: now)
        testRemainingConversion(now: now)
        testOptionalWindows(now: now)
        testResetAtConversion(now: now)
        testMalformedResponse(now: now)
        testWorkspaceIDs()
        testWorkspaceOverride()
        testSignedOut()
        testCookieFiltering()
        testErrorDescriptionDoesNotLeakCookie()

        print("OpenCode Go parser tests passed")
    }

    private static func testAllWindowsPresent(now: Date) {
        let text =
            "$R[16]($R[30],$R[41]={rollingUsage:$R[42]={status:\"ok\",resetInSec:5944,usagePercent:17}," +
            "weeklyUsage:$R[43]={status:\"ok\",resetInSec:278201,usagePercent:75}," +
            "monthlyUsage:$R[44]={status:\"ok\",resetInSec:880201,usagePercent:91}});"
        let snapshot = try! OpenCodeGoParser.parseSubscription(text: text, now: now)

        precondition(snapshot.rolling5h != nil)
        precondition(snapshot.weekly != nil)
        precondition(snapshot.monthly != nil)
        precondition(snapshot.rolling5h?.usedPercent == 17)
        precondition(snapshot.weekly?.usedPercent == 75)
        precondition(snapshot.monthly?.usedPercent == 91)
        precondition(snapshot.rolling5h?.resetInSec == 5944)
        precondition(snapshot.weekly?.resetInSec == 278_201)
        precondition(snapshot.monthly?.resetInSec == 880_201)
    }

    private static func testRemainingConversion(now: Date) {
        for (used, expectedRemaining) in [(0.0, 100), (82.0, 18), (100.0, 0)] {
            let text = """
            {
              "usage": {
                "rollingUsage": { "usagePercent": \(used), "resetInSec": 600 },
                "weeklyUsage": { "usagePercent": \(used), "resetInSec": 3600 },
                "monthlyUsage": { "usagePercent": \(used), "resetInSec": 7200 }
              }
            }
            """
            let snapshot = try! OpenCodeGoParser.parseSubscription(text: text, now: now)
            precondition(snapshot.rolling5h?.remainingPercentInt == expectedRemaining)
            precondition(snapshot.weekly?.remainingPercentInt == expectedRemaining)
            precondition(snapshot.monthly?.remainingPercentInt == expectedRemaining)
        }
    }

    private static func testOptionalWindows(now: Date) {
        let rollingOnly = """
        {
          "usage": {
            "rollingUsage": { "usagePercent": 25, "resetInSec": 600 }
          }
        }
        """
        let weeklyMissing = try! OpenCodeGoParser.parseSubscription(text: rollingOnly, now: now)
        precondition(weeklyMissing.weekly == nil)
        precondition(weeklyMissing.monthly == nil)
        precondition(weeklyMissing.rolling5h != nil)

        let weeklyOnly = """
        {
          "usage": {
            "rollingUsage": { "usagePercent": 10, "resetInSec": 600 },
            "weeklyUsage": { "usagePercent": 50, "resetInSec": 3600 }
          }
        }
        """
        let monthlyMissing = try! OpenCodeGoParser.parseSubscription(text: weeklyOnly, now: now)
        precondition(monthlyMissing.weekly != nil)
        precondition(monthlyMissing.monthly == nil)
    }

    private static func testResetAtConversion(now: Date) {
        let resetAt = now.addingTimeInterval(1234)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let text = """
        {
          "usage": {
            "rollingUsage": { "usagePercent": 0.25, "resetAt": "\(formatter.string(from: resetAt))" }
          }
        }
        """
        let snapshot = try! OpenCodeGoParser.parseSubscription(text: text, now: now)
        precondition(snapshot.rolling5h?.resetInSec == 1234)
        precondition(abs((snapshot.rolling5h?.resetAt.timeIntervalSince(resetAt) ?? 0)) < 0.1)
        precondition(snapshot.rolling5h?.usedPercent == 25)
    }

    private static func testMalformedResponse(now: Date) {
        do {
            _ = try OpenCodeGoParser.parseSubscription(text: "<html>No usage yet</html>", now: now)
            preconditionFailure("Expected parse failure")
        } catch let error as OpenCodeGoUsageError {
            guard case .parseFailed = error else {
                preconditionFailure("Expected parseFailed, got \(error)")
            }
        } catch {
            preconditionFailure("Unexpected error \(error)")
        }
    }

    private static func testWorkspaceIDs() {
        let text = """
        ;0x00000089;((self.$R=self.$R||{})["codexbar"]=[],\
        ($R=>$R[0]=[$R[1]={id:"wrk_01K6AR1ZET89H8NB691FQ2C2VB",name:"Default"},\
        $R[2]={id:"wrk_01K6AR1ZET89H8NB691FQ2C2VC",name:"Second"}])\
        ($R["codexbar"]))
        """
        let ids = OpenCodeGoParser.parseWorkspaceIDs(text: text)
        precondition(ids.count == 2)
        precondition(ids[0].hasPrefix("wrk_"))
        precondition(ids[1].hasPrefix("wrk_"))
        precondition(ids[0] != ids[1])
    }

    private static func testWorkspaceOverride() {
        precondition(OpenCodeGoParser.normalizeWorkspaceID("wrk_abc123") == "wrk_abc123")
        precondition(
            OpenCodeGoParser.normalizeWorkspaceID("https://opencode.ai/workspace/wrk_abc123/go")
                == "wrk_abc123"
        )
        precondition(OpenCodeGoParser.normalizeWorkspaceID("workspace=wrk_def456") == "wrk_def456")
        precondition(OpenCodeGoParser.normalizeWorkspaceID(nil) == nil)
    }

    private static func testSignedOut() {
        precondition(OpenCodeGoParser.looksSignedOut(text: "Please log in to continue"))
        precondition(OpenCodeGoParser.looksSignedOut(
            text: #"actor of type "public" is not associated with an account"#
        ))
        precondition(!OpenCodeGoParser.looksSignedOut(text: "rollingUsage resetInSec 600"))
    }

    private static func testCookieFiltering() {
        let header = "auth=SECRET_AUTH; oc_locale=en; __Host-auth=SECRET_HOST; theme=dark"
        let filtered = OpenCodeGoParser.filteredCookieHeader(from: header)
        precondition(filtered?.contains("SECRET_AUTH") == true)
        precondition(filtered?.contains("SECRET_HOST") == true)
        precondition(filtered?.contains("oc_locale") == false)
        precondition(filtered?.contains("theme=dark") == false)
    }

    private static func testErrorDescriptionDoesNotLeakCookie() {
        let cookie = "auth=SUPER_SECRET_VALUE"
        let message = "OpenCode Go 接口错误：HTTP 500: \(cookie)"
        let error = OpenCodeGoUsageError.apiError(message)
        let description = error.errorDescription ?? ""
        precondition(!description.contains("SUPER_SECRET_VALUE"))
    }
}

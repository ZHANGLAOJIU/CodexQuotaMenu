import Foundation

enum OpenCodeGoUsageError: LocalizedError, Equatable {
    case invalidCredentials
    case cookieMissing
    case networkError(String)
    case apiError(String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "OpenCode Go 登录已过期，需要重新登录"
        case .cookieMissing:
            return "需要设置 OpenCode Cookie"
        case let .networkError(message):
            return "OpenCode Go 网络错误：\(Self.redactSecrets(message))"
        case let .apiError(message):
            return "OpenCode Go 接口错误：\(Self.redactSecrets(message))"
        case let .parseFailed(message):
            return "OpenCode Go 解析失败：\(Self.redactSecrets(message))"
        }
    }

    private static func redactSecrets(_ message: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:__Host-)?auth=[^;\s\"<]+"#,
            options: [.caseInsensitive]
        ) else {
            return message
        }
        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        return regex.stringByReplacingMatches(
            in: message,
            options: [],
            range: range,
            withTemplate: "auth=***"
        )
    }
}

struct OpenCodeGoWindow: Equatable {
    let usedPercent: Double
    let resetInSec: Int
    let resetAt: Date

    init(usedPercent: Double, resetInSec: Int, now: Date) {
        self.usedPercent = min(100, max(0, usedPercent))
        self.resetInSec = max(0, resetInSec)
        self.resetAt = now.addingTimeInterval(TimeInterval(self.resetInSec))
    }

    var remainingPercent: Double {
        max(0, min(100, 100 - usedPercent))
    }

    var remainingPercentInt: Int {
        Int(remainingPercent.rounded())
    }
}

struct OpenCodeGoSnapshot: Equatable {
    let rolling5h: OpenCodeGoWindow?
    let weekly: OpenCodeGoWindow?
    let monthly: OpenCodeGoWindow?
    let workspaceID: String?
    let lastUpdated: Date
    let source: String
    let isStale: Bool
    let errorMessage: String?
    let renewsAt: Date?
    let zenBalanceUSD: Double?

    init(
        rolling5h: OpenCodeGoWindow?,
        weekly: OpenCodeGoWindow?,
        monthly: OpenCodeGoWindow?,
        workspaceID: String?,
        lastUpdated: Date,
        source: String,
        isStale: Bool,
        errorMessage: String?,
        renewsAt: Date?,
        zenBalanceUSD: Double?
    ) {
        self.rolling5h = rolling5h
        self.weekly = weekly
        self.monthly = monthly
        self.workspaceID = workspaceID
        self.lastUpdated = lastUpdated
        self.source = source
        self.isStale = isStale
        self.errorMessage = errorMessage
        self.renewsAt = renewsAt
        self.zenBalanceUSD = zenBalanceUSD
    }

    var hasAnyData: Bool {
        rolling5h != nil || weekly != nil || monthly != nil
    }

    static func failure(
        _ error: Error,
        workspaceID: String?,
        previous: OpenCodeGoSnapshot?,
        now: Date = Date()
    ) -> OpenCodeGoSnapshot {
        if let previous, previous.hasAnyData {
            return OpenCodeGoSnapshot(
                rolling5h: previous.rolling5h,
                weekly: previous.weekly,
                monthly: previous.monthly,
                workspaceID: previous.workspaceID ?? workspaceID,
                lastUpdated: previous.lastUpdated,
                source: previous.source,
                isStale: true,
                errorMessage: error.localizedDescription,
                renewsAt: previous.renewsAt,
                zenBalanceUSD: previous.zenBalanceUSD
            )
        }
        return OpenCodeGoSnapshot(
            rolling5h: nil,
            weekly: nil,
            monthly: nil,
            workspaceID: workspaceID,
            lastUpdated: now,
            source: "web",
            isStale: false,
            errorMessage: error.localizedDescription,
            renewsAt: nil,
            zenBalanceUSD: nil
        )
    }
}

enum OpenCodeGoParser {
    static let workspacesServerID = "def39973159c7f0483d8793a822b8dbb10d067e12c65455fcb4608459ba0234f"
    static let billingServerID = "c83b78a614689c38ebee981f9b39a8b377716db85c1fd7dbab604adc02d3313d"

    static func normalizeWorkspaceID(_ raw: String?) -> String? {
        guard let raw else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("wrk_"), trimmed.count > 4 {
            return trimmed
        }
        if let url = URL(string: trimmed) {
            let parts = url.pathComponents
            if let index = parts.firstIndex(of: "workspace"),
               parts.count > index + 1
            {
                let candidate = parts[index + 1]
                if candidate.hasPrefix("wrk_"), candidate.count > 4 {
                    return candidate
                }
            }
        }
        if let match = trimmed.range(of: #"wrk_[A-Za-z0-9]+"#, options: .regularExpression) {
            return String(trimmed[match])
        }
        return nil
    }

    static func parseWorkspaceIDs(text: String) -> [String] {
        let pattern = #"id\s*:\s*\"(wrk_[^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }

    static func parseWorkspaceIDsFromJSON(text: String) -> [String] {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        var result: [String] = []
        collectWorkspaceIDs(object: object, out: &result)
        return result
    }

    static func looksSignedOut(text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("login")
            || lower.contains("log in")
            || lower.contains("sign in")
            || lower.contains("auth/authorize")
            || lower.contains("not associated with an account")
            || lower.contains("actor of type \"public\"")
    }

    static func extractServerErrorMessage(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else {
            return nil
        }
        for key in ["message", "error", "detail"] {
            if let message = dict[key] as? String, !message.isEmpty {
                return message
            }
        }
        return nil
    }

    static func parseSubscription(text: String, now: Date) throws -> OpenCodeGoSnapshot {
        if let snapshot = parseSubscriptionJSON(text: text, now: now) {
            return snapshot
        }

        guard let rollingPercent = extractDouble(
            pattern: #"rollingUsage[^}]*?usagePercent\s*:\s*([0-9]+(?:\.[0-9]+)?)"#,
            text: text
        ),
        let rollingReset = extractInt(
            pattern: #"rollingUsage[^}]*?resetInSec\s*:\s*([0-9]+)"#,
            text: text
        ) else {
            throw OpenCodeGoUsageError.parseFailed("缺少 rolling usage 字段")
        }

        let weeklyPercent = extractDouble(
            pattern: #"weeklyUsage[^}]*?usagePercent\s*:\s*([0-9]+(?:\.[0-9]+)?)"#,
            text: text
        )
        let weeklyReset = extractInt(
            pattern: #"weeklyUsage[^}]*?resetInSec\s*:\s*([0-9]+)"#,
            text: text
        )
        let monthlyPercent = extractDouble(
            pattern: #"monthlyUsage[^}]*?usagePercent\s*:\s*([0-9]+(?:\.[0-9]+)?)"#,
            text: text
        )
        let monthlyReset = extractInt(
            pattern: #"monthlyUsage[^}]*?resetInSec\s*:\s*([0-9]+)"#,
            text: text
        )

        return OpenCodeGoSnapshot(
            rolling5h: OpenCodeGoWindow(usedPercent: rollingPercent, resetInSec: rollingReset, now: now),
            weekly: pairedWindow(percent: weeklyPercent, resetInSec: weeklyReset, now: now),
            monthly: pairedWindow(percent: monthlyPercent, resetInSec: monthlyReset, now: now),
            workspaceID: nil,
            lastUpdated: now,
            source: "web",
            isStale: false,
            errorMessage: nil,
            renewsAt: nil,
            zenBalanceUSD: nil
        )
    }

    static func filteredCookieHeader(from rawHeader: String?) -> String? {
        let allowedNames: Set<String> = ["auth", "__Host-auth"]
        let components = (rawHeader ?? "")
            .split(separator: ";")
            .compactMap { component -> String? in
                let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard let name = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                      allowedNames.contains(name),
                      parts.count == 2 else {
                    return nil
                }
                return "\(name)=\(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))"
            }
        return components.isEmpty ? nil : components.joined(separator: "; ")
    }

    private static func pairedWindow(percent: Double?, resetInSec: Int?, now: Date) -> OpenCodeGoWindow? {
        guard let percent, let resetInSec else {
            return nil
        }
        return OpenCodeGoWindow(usedPercent: percent, resetInSec: resetInSec, now: now)
    }

    private static func parseSubscriptionJSON(text: String, now: Date) -> OpenCodeGoSnapshot? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return parseUsage(from: object, now: now)
    }

    private static func parseUsage(from object: Any, now: Date) -> OpenCodeGoSnapshot? {
        if let dict = object as? [String: Any] {
            if let snapshot = parseUsageDictionary(dict, now: now) {
                return snapshot
            }
            for value in dict.values {
                if let nested = parseUsage(from: value, now: now) {
                    return nested
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let nested = parseUsage(from: value, now: now) {
                    return nested
                }
            }
        }
        return nil
    }

    private static func parseUsageDictionary(_ dict: [String: Any], now: Date) -> OpenCodeGoSnapshot? {
        if let usage = dict["usage"] as? [String: Any],
           let nested = parseUsageDictionary(usage, now: now) {
            return nested
        }

        let rollingKeys = ["rollingUsage", "rolling", "rolling_usage", "rollingWindow", "rolling_window", "5h"]
        let weeklyKeys = ["weeklyUsage", "weekly", "weekly_usage", "weeklyWindow", "weekly_window"]
        let monthlyKeys = ["monthlyUsage", "monthly", "monthly_usage", "monthlyWindow", "monthly_window"]

        guard let rollingDict = firstDictionary(from: dict, keys: rollingKeys),
              let rolling = parseWindow(rollingDict, now: now) else {
            return nil
        }

        let weekly = firstDictionary(from: dict, keys: weeklyKeys).flatMap {
            parseWindow($0, now: now)
        }
        let monthly = firstDictionary(from: dict, keys: monthlyKeys).flatMap {
            parseWindow($0, now: now)
        }
        let renewsAt = dateValue(from: dict["renewAt"] ?? dict["renew_at"])

        return OpenCodeGoSnapshot(
            rolling5h: rolling,
            weekly: weekly,
            monthly: monthly,
            workspaceID: nil,
            lastUpdated: now,
            source: "web",
            isStale: false,
            errorMessage: nil,
            renewsAt: renewsAt,
            zenBalanceUSD: nil
        )
    }

    private static func parseWindow(_ raw: [String: Any], now: Date) -> OpenCodeGoWindow? {
        var dict = raw
        if let nested = raw["window"] as? [String: Any] {
            dict = nested
        }

        var percent: Double?
        let percentKeys = ["usagePercent", "usedPercent", "percentUsed", "percent", "usage_percent", "used_percent"]
        for key in percentKeys {
            if let value = doubleValue(from: dict[key]) {
                percent = value
                break
            }
        }

        let percentIsDirect = percent != nil
        if percent == nil {
            let usedKeys = ["used", "usage", "consumed", "count", "usedTokens"]
            let limitKeys = ["limit", "total", "quota", "max", "cap", "tokenLimit"]
            var used: Double?
            var limit: Double?
            for key in usedKeys {
                if let value = doubleValue(from: dict[key]) {
                    used = value
                    break
                }
            }
            for key in limitKeys {
                if let value = doubleValue(from: dict[key]) {
                    limit = value
                    break
                }
            }
            if let used, let limit, limit > 0 {
                percent = (used / limit) * 100
            }
        }

        guard var resolvedPercent = percent else {
            return nil
        }
        if percentIsDirect, resolvedPercent <= 1, resolvedPercent >= 0 {
            resolvedPercent *= 100
        }

        var resetInSec: Int?
        for key in ["resetInSec", "resetInSeconds", "resetSeconds", "reset_sec", "reset_in_sec", "resetsInSec"] {
            if let value = intValue(from: dict[key]) {
                resetInSec = value
                break
            }
        }
        if resetInSec == nil {
            for key in ["resetAt", "resetsAt", "reset_at", "nextReset", "next_reset"] {
                if let resetAt = dateValue(from: dict[key]) {
                    resetInSec = max(0, Int(resetAt.timeIntervalSince(now)))
                    break
                }
            }
        }
        guard let resetInSec else {
            return nil
        }
        return OpenCodeGoWindow(usedPercent: resolvedPercent, resetInSec: resetInSec, now: now)
    }

    private static func firstDictionary(from dict: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys {
            if let value = dict[key] as? [String: Any] {
                return value
            }
        }
        return nil
    }

    private static func collectWorkspaceIDs(object: Any, out: inout [String]) {
        if let dict = object as? [String: Any] {
            for value in dict.values {
                collectWorkspaceIDs(object: value, out: &out)
            }
            return
        }
        if let array = object as? [Any] {
            for value in array {
                collectWorkspaceIDs(object: value, out: &out)
            }
            return
        }
        if let string = object as? String,
           string.hasPrefix("wrk_"),
           !out.contains(string) {
            out.append(string)
        }
    }

    private static func extractDouble(pattern: String, text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
              ),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[range])
    }

    private static func extractInt(pattern: String, text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
              ),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[range])
    }

    private static func doubleValue(from value: Any?) -> Double? {
        switch value {
        case let number as Double:
            guard number.isFinite else { return nil }
            return number
        case let number as NSNumber:
            guard !number.isEqual(to: NSNumber(value: true)),
                  !number.isEqual(to: NSNumber(value: false)) else {
                return nil
            }
            return number.doubleValue
        case let string as String:
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private static func intValue(from value: Any?) -> Int? {
        switch value {
        case let number as Int:
            return number
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private static func dateValue(from value: Any?) -> Date? {
        guard let value else {
            return nil
        }
        if let number = doubleValue(from: value) {
            if number > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: number / 1000)
            }
            if number > 1_000_000_000 {
                return Date(timeIntervalSince1970: number)
            }
        }
        if let string = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = formatter.date(from: string) {
                return parsed
            }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: string)
        }
        return nil
    }
}

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

struct BankedResetCredit: Equatable {
    let id: String
    let title: String?
    let resetType: String?
    let status: String
    let expiresAt: Date?
}

struct BankedResetSummary: Equatable {
    let availableCount: Int
    let credits: [BankedResetCredit]

    var availableCredits: [BankedResetCredit] {
        credits
            .filter { $0.status == "available" }
            .sorted {
                let leftExpiry = $0.expiresAt ?? .distantFuture
                let rightExpiry = $1.expiresAt ?? .distantFuture
                if leftExpiry == rightExpiry {
                    return $0.id < $1.id
                }
                return leftExpiry < rightExpiry
            }
    }
}

enum BankedResetParseError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "Codex 返回了无法识别的 banked reset 数据"
    }
}

func parseBankedResetResponse(_ data: Data) throws -> BankedResetSummary {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let availableCount = (json["available_count"] as? NSNumber)?.intValue,
          let rawCredits = json["credits"] as? [[String: Any]] else {
        throw BankedResetParseError.invalidResponse
    }

    let credits = try rawCredits.map { rawCredit in
        guard let id = rawCredit["id"] as? String,
              !id.isEmpty,
              let status = rawCredit["status"] as? String else {
            throw BankedResetParseError.invalidResponse
        }

        return BankedResetCredit(
            id: id,
            title: rawCredit["title"] as? String,
            resetType: rawCredit["reset_type"] as? String,
            status: status,
            expiresAt: parseISO8601Date(rawCredit["expires_at"] as? String)
        )
    }

    return BankedResetSummary(
        availableCount: max(0, availableCount),
        credits: credits
    )
}

func formatBankedResetExpiry(_ date: Date, timeZone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd EEE HH:mm:ss"
    return formatter.string(from: date)
}

private func parseISO8601Date(_ value: String?) -> Date? {
    guard let value else {
        return nil
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
        return date
    }

    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
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
    var bankedResetSummary: BankedResetSummary? = nil
    var bankedResetErrorMessage: String? = nil

    var fiveHourRemainingPercent: Int? {
        fiveHourUsedPercent.map { max(0, min(100, 100 - $0)) }
    }

    var weeklyRemainingPercent: Int? {
        weeklyUsedPercent.map { max(0, min(100, 100 - $0)) }
    }
}

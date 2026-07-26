import Cocoa
import Foundation

func debugLog(_ message: String) {
    let formatter = ISO8601DateFormatter()
    let line = "\(formatter.string(from: Date())) \(message)\n"
    let logURL = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Logs/CodexQuotaMenu.debug.log")

    guard let data = line.data(using: .utf8) else {
        return
    }

    if FileManager.default.fileExists(atPath: logURL.path),
       let handle = try? FileHandle(forWritingTo: logURL) {
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
        try? handle.close()
    } else {
        try? data.write(to: logURL)
    }
}

final class QuotaPanelView: NSView {
    private static let panelWidth: CGFloat = 350
    private static let bankedRowsTop: CGFloat = 233
    private static let bankedRowHeight: CGFloat = 30
    private let snapshot: UsageSnapshot
    private let bankedCredits: [BankedResetCredit]
    private let panelSize: NSSize
    private let syncTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    init(snapshot: UsageSnapshot) {
        self.snapshot = snapshot
        bankedCredits = snapshot.bankedResetSummary?.availableCredits ?? []
        let rowCount = max(1, bankedCredits.count)
        let sourceTop = Self.bankedRowsTop + CGFloat(rowCount) * Self.bankedRowHeight + 8
        panelSize = NSSize(width: Self.panelWidth, height: sourceTop + 17)
        super.init(frame: NSRect(origin: .zero, size: panelSize))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Codex 剩余额度与可用限额重置")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        panelSize
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        drawText(
            "Codex",
            in: NSRect(x: 16, y: 12, width: 180, height: 24),
            font: .systemFont(ofSize: 15, weight: .semibold),
            color: .labelColor
        )

        if let planType = snapshot.planType {
            drawText(
                planType.capitalized,
                in: NSRect(x: 220, y: 14, width: 114, height: 20),
                font: .systemFont(ofSize: 11, weight: .medium),
                color: .secondaryLabelColor,
                alignment: .right
            )
        }

        NSColor.separatorColor.withAlphaComponent(0.55).setFill()
        NSRect(x: 16, y: 43, width: 318, height: 1).fill()

        drawMetric(
            title: "5 小时额度",
            remainingPercent: snapshot.fiveHourRemainingPercent,
            resetAt: snapshot.fiveHourResetAt,
            top: 57
        )
        drawMetric(
            title: "一周额度",
            remainingPercent: snapshot.weeklyRemainingPercent,
            resetAt: snapshot.weeklyResetAt,
            top: 126
        )

        drawBankedResets()

        let rowCount = max(1, bankedCredits.count)
        let sourceTop = Self.bankedRowsTop + CGFloat(rowCount) * Self.bankedRowHeight + 8
        let source = "\(syncTimeFormatter.string(from: snapshot.sourceDate)) 同步 · \(snapshot.sourceName)"
        drawText(
            source,
            in: NSRect(x: 16, y: sourceTop, width: 318, height: 15),
            font: .systemFont(ofSize: 10),
            color: .tertiaryLabelColor
        )
    }

    private func drawMetric(title: String, remainingPercent: Int?, resetAt: Date?, top: CGFloat) {
        drawText(
            title,
            in: NSRect(x: 16, y: top, width: 318, height: 20),
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor
        )

        let trackRect = NSRect(x: 16, y: top + 27, width: 318, height: 7)
        NSColor.quaternaryLabelColor.withAlphaComponent(0.28).setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: 3.5, yRadius: 3.5).fill()

        if let remainingPercent {
            let clamped = max(0, min(100, remainingPercent))
            if clamped > 0 {
                let fillWidth = max(7, trackRect.width * CGFloat(clamped) / 100)
                let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: fillWidth, height: trackRect.height)
                meterColor(for: clamped).setFill()
                NSBezierPath(roundedRect: fillRect, xRadius: 3.5, yRadius: 3.5).fill()
            }
        }

        let percentText = remainingPercent.map { "\($0)% 剩余" } ?? "--% 剩余"
        drawText(
            percentText,
            in: NSRect(x: 16, y: top + 40, width: 120, height: 18),
            font: .monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            color: .labelColor
        )
        drawText(
            formatCountdown(resetAt),
            in: NSRect(x: 136, y: top + 40, width: 198, height: 18),
            font: .monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            color: .secondaryLabelColor,
            alignment: .right
        )
    }

    private func drawBankedResets() {
        NSColor.separatorColor.withAlphaComponent(0.55).setFill()
        NSRect(x: 16, y: 195, width: 318, height: 1).fill()

        drawText(
            "使用限额重置",
            in: NSRect(x: 16, y: 205, width: 180, height: 22),
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor
        )

        if let summary = snapshot.bankedResetSummary {
            let badgeRect = NSRect(x: 250, y: 202, width: 84, height: 25)
            NSColor.systemGreen.withAlphaComponent(0.14).setFill()
            NSBezierPath(roundedRect: badgeRect, xRadius: 12.5, yRadius: 12.5).fill()
            drawText(
                "可用 \(summary.availableCount) 次",
                in: NSRect(x: 250, y: 206, width: 84, height: 18),
                font: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                color: .systemGreen,
                alignment: .center
            )
        } else {
            drawText(
                "暂不可用",
                in: NSRect(x: 250, y: 206, width: 84, height: 18),
                font: .systemFont(ofSize: 11, weight: .medium),
                color: .secondaryLabelColor,
                alignment: .right
            )
        }

        guard !bankedCredits.isEmpty else {
            let message = snapshot.bankedResetSummary == nil ? "暂时无法获取 banked reset" : "暂无可用的重置次数"
            drawText(
                message,
                in: NSRect(x: 16, y: Self.bankedRowsTop + 4, width: 318, height: 18),
                font: .systemFont(ofSize: 11),
                color: .secondaryLabelColor
            )
            return
        }

        for (index, credit) in bankedCredits.enumerated() {
            let top = Self.bankedRowsTop + CGFloat(index) * Self.bankedRowHeight
            drawText(
                bankedResetTitle(credit),
                in: NSRect(x: 16, y: top + 4, width: 96, height: 18),
                font: .systemFont(ofSize: 11, weight: .medium),
                color: .labelColor
            )
            drawText(
                bankedResetExpiry(credit),
                in: NSRect(x: 112, y: top + 4, width: 222, height: 18),
                font: .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular),
                color: .secondaryLabelColor,
                alignment: .right
            )

            if index < bankedCredits.count - 1 {
                NSColor.separatorColor.withAlphaComponent(0.3).setFill()
                NSRect(x: 16, y: top + Self.bankedRowHeight - 1, width: 318, height: 1).fill()
            }
        }
    }

    private func bankedResetTitle(_ credit: BankedResetCredit) -> String {
        if let title = credit.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        if let resetType = credit.resetType, !resetType.isEmpty {
            return resetType.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "Full reset"
    }

    private func bankedResetExpiry(_ credit: BankedResetCredit) -> String {
        guard let expiresAt = credit.expiresAt else {
            return "到期时间未知"
        }
        return "\(formatBankedResetExpiry(expiresAt)) 到期"
    }

    private func meterColor(for remainingPercent: Int) -> NSColor {
        switch remainingPercent {
        case ...30:
            return .systemRed
        case ...50:
            return .systemOrange
        default:
            return .systemBlue
        }
    }

    private func formatCountdown(_ date: Date?) -> String {
        guard let date else {
            return "重置时间未知"
        }

        let totalMinutes = max(0, Int(date.timeIntervalSinceNow) / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)天 \(hours)小时后重置"
        }
        if hours > 0 {
            return "\(hours)小时 \(minutes)分后重置"
        }
        if minutes > 0 {
            return "\(minutes)分后重置"
        }
        return "即将重置"
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        text.draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}

final class CodexQuotaReader {
    private struct ParsedWindow {
        let usedPercent: Int?
        let durationMinutes: Int
        let resetAt: Date?
    }

    private final class ReadState {
        var usageSnapshot: UsageSnapshot?
        var bankedResetResult: Result<BankedResetSummary, Error>?
    }

    private let authURL = URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/auth.json")
    private let databasePaths = [
        "\(NSHomeDirectory())/.codex/logs_2.sqlite",
        "\(NSHomeDirectory())/.codex/sqlite/logs_2.sqlite"
    ]
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let bankedResetsURL = URL(
        string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"
    )!
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    func read(completion: @escaping (UsageSnapshot) -> Void) {
        do {
            let credentials = try readCredentials()
            let state = ReadState()
            let stateQueue = DispatchQueue(label: "io.github.zhanglaojiu.codexquotamenu.read-state")
            let group = DispatchGroup()

            group.enter()
            readUsage(credentials: credentials) { snapshot in
                stateQueue.async {
                    state.usageSnapshot = snapshot
                    group.leave()
                }
            }

            group.enter()
            readBankedResets(credentials: credentials) { result in
                stateQueue.async {
                    state.bankedResetResult = result
                    group.leave()
                }
            }

            group.notify(queue: stateQueue) {
                var snapshot = state.usageSnapshot ?? .empty(error: "Codex 用量读取未完成")
                switch state.bankedResetResult {
                case .success(let summary):
                    snapshot.bankedResetSummary = summary
                case .failure(let error):
                    snapshot.bankedResetErrorMessage = "Banked reset 读取失败：\(error.localizedDescription)"
                case nil:
                    snapshot.bankedResetErrorMessage = "Banked reset 读取未完成"
                }
                completion(snapshot)
            }
        } catch {
            var snapshot = readLogFallback(apiError: error)
            snapshot.bankedResetErrorMessage = "Banked reset 读取失败：\(error.localizedDescription)"
            completion(snapshot)
        }
    }

    private func readUsage(
        credentials: (accessToken: String, accountID: String),
        completion: @escaping (UsageSnapshot) -> Void
    ) {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        addAuthorizationHeaders(to: &request, credentials: credentials)

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                return
            }

            do {
                let data = try self.validatedData(
                    data: data,
                    response: response,
                    error: error,
                    endpointName: "Codex 用量接口"
                )
                completion(try self.parseAPIResponse(data))
            } catch {
                completion(self.readLogFallback(apiError: error))
            }
        }.resume()
    }

    private func readBankedResets(
        credentials: (accessToken: String, accountID: String),
        completion: @escaping (Result<BankedResetSummary, Error>) -> Void
    ) {
        var request = URLRequest(url: bankedResetsURL)
        request.httpMethod = "GET"
        addAuthorizationHeaders(to: &request, credentials: credentials)
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                return
            }

            do {
                let data = try self.validatedData(
                    data: data,
                    response: response,
                    error: error,
                    endpointName: "Banked reset 接口"
                )
                completion(.success(try parseBankedResetResponse(data)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func addAuthorizationHeaders(
        to request: inout URLRequest,
        credentials: (accessToken: String, accountID: String)
    ) {
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("CodexQuotaMenu/2.4", forHTTPHeaderField: "User-Agent")
    }

    private func validatedData(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        endpointName: String
    ) throws -> Data {
        if let error {
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(
                domain: "CodexQuotaMenu.API",
                code: status,
                userInfo: [NSLocalizedDescriptionKey: "\(endpointName)返回 HTTP \(status)"]
            )
        }

        guard let data else {
            throw NSError(
                domain: "CodexQuotaMenu.API",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "\(endpointName)没有返回数据"]
            )
        }
        return data
    }

    private func readCredentials() throws -> (accessToken: String, accountID: String) {
        let data = try Data(contentsOf: authURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty,
              let accountID = tokens["account_id"] as? String,
              !accountID.isEmpty else {
            throw NSError(
                domain: "CodexQuotaMenu.Auth",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "找不到 Codex 登录信息"]
            )
        }
        return (accessToken, accountID)
    }

    private func parseAPIResponse(_ data: Data) throws -> UsageSnapshot {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = json["rate_limit"] as? [String: Any] else {
            throw NSError(
                domain: "CodexQuotaMenu.API",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Codex 用量格式无法解析"]
            )
        }

        let windows = [
            parseAPIWindow(rateLimit["primary_window"]),
            parseAPIWindow(rateLimit["secondary_window"])
        ].compactMap { $0 }
        let fiveHour = windows.first { quotaWindowKind(durationMinutes: $0.durationMinutes) == .fiveHour }
        let weekly = windows.first { quotaWindowKind(durationMinutes: $0.durationMinutes) == .weekly }

        guard fiveHour != nil || weekly != nil else {
            throw NSError(
                domain: "CodexQuotaMenu.API",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Codex 用量接口没有可识别的窗口数据"]
            )
        }

        return UsageSnapshot(
            sourceDate: Date(),
            sourceName: "Codex 官方用量接口",
            planType: json["plan_type"] as? String,
            fiveHourUsedPercent: fiveHour?.usedPercent,
            weeklyUsedPercent: weekly?.usedPercent,
            fiveHourWindowMinutes: fiveHour?.durationMinutes,
            weeklyWindowMinutes: weekly?.durationMinutes,
            fiveHourResetAt: fiveHour?.resetAt,
            weeklyResetAt: weekly?.resetAt,
            warningMessage: nil,
            errorMessage: nil
        )
    }

    private func parseAPIWindow(_ value: Any?) -> ParsedWindow? {
        guard let window = value as? [String: Any],
              let durationMinutes = secondsToMinutes(window["limit_window_seconds"]),
              quotaWindowKind(durationMinutes: durationMinutes) != nil else {
            return nil
        }

        return ParsedWindow(
            usedPercent: intValue(window["used_percent"]),
            durationMinutes: durationMinutes,
            resetAt: epochDate(window["reset_at"])
        )
    }

    private func readLogFallback(apiError: Error) -> UsageSnapshot {
        let existingPaths = databasePaths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existingPaths.isEmpty else {
            return .empty(error: "官方接口不可用，且找不到 Codex 本地日志。")
        }

        let query = """
        select ts || char(9) || feedback_log_body
        from logs
        where feedback_log_body like '%x-codex-primary-used-percent%'
        order by ts desc, ts_nanos desc
        limit 1;
        """

        var newestSnapshot: UsageSnapshot?
        var lastError: Error?

        for path in existingPaths {
            do {
                let output = try runSQLite(databasePath: path, query: query)
                guard let snapshot = parseSQLiteOutput(output, apiError: apiError) else {
                    continue
                }
                if newestSnapshot == nil || snapshot.sourceDate > newestSnapshot!.sourceDate {
                    newestSnapshot = snapshot
                }
            } catch {
                lastError = error
            }
        }

        if let newestSnapshot {
            return newestSnapshot
        }

        let detail = lastError?.localizedDescription ?? apiError.localizedDescription
        return .empty(error: "读取 Codex 用量失败：\(detail)")
    }

    private func runSQLite(databasePath: String, query: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [databasePath, query]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "CodexQuotaMenu.SQLite",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        }
        return output
    }

    private func parseSQLiteOutput(_ output: String, apiError: Error) -> UsageSnapshot? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let parts = trimmed.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let timestamp = TimeInterval(parts[0]) else {
            return nil
        }

        let body = String(parts[1])
        let windows = [
            ParsedWindow(
                usedPercent: intHeaderValue("x-codex-primary-used-percent", in: body),
                durationMinutes: intHeaderValue("x-codex-primary-window-minutes", in: body) ?? 0,
                resetAt: dateHeaderValue("x-codex-primary-reset-at", in: body)
            ),
            ParsedWindow(
                usedPercent: intHeaderValue("x-codex-secondary-used-percent", in: body),
                durationMinutes: intHeaderValue("x-codex-secondary-window-minutes", in: body) ?? 0,
                resetAt: dateHeaderValue("x-codex-secondary-reset-at", in: body)
            )
        ]
        let fiveHour = windows.first { quotaWindowKind(durationMinutes: $0.durationMinutes) == .fiveHour }
        let weekly = windows.first { quotaWindowKind(durationMinutes: $0.durationMinutes) == .weekly }

        guard fiveHour != nil || weekly != nil else {
            return nil
        }

        return UsageSnapshot(
            sourceDate: Date(timeIntervalSince1970: timestamp),
            sourceName: "本地日志（备用）",
            planType: headerValue("x-codex-plan-type", in: body),
            fiveHourUsedPercent: fiveHour?.usedPercent,
            weeklyUsedPercent: weekly?.usedPercent,
            fiveHourWindowMinutes: fiveHour?.durationMinutes,
            weeklyWindowMinutes: weekly?.durationMinutes,
            fiveHourResetAt: fiveHour?.resetAt,
            weeklyResetAt: weekly?.resetAt,
            warningMessage: "官方接口暂不可用：\(apiError.localizedDescription)",
            errorMessage: nil
        )
    }

    private func headerValue(_ name: String, in body: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = "\"\(escapedName)\"\\s*:\\s*\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, range: range),
              let valueRange = Range(match.range(at: 1), in: body) else {
            return nil
        }
        return String(body[valueRange])
    }

    private func intHeaderValue(_ name: String, in body: String) -> Int? {
        headerValue(name, in: body).flatMap(Int.init)
    }

    private func dateHeaderValue(_ name: String, in body: String) -> Date? {
        guard let seconds = intHeaderValue(name, in: body) else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    private func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return Int(number.doubleValue.rounded())
        }
        if let string = value as? String, let number = Double(string) {
            return Int(number.rounded())
        }
        return nil
    }

    private func secondsToMinutes(_ value: Any?) -> Int? {
        intValue(value).map { $0 / 60 }
    }

    private func epochDate(_ value: Any?) -> Date? {
        guard let seconds = intValue(value) else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}

private extension UsageSnapshot {
    static func empty(error: String) -> UsageSnapshot {
        UsageSnapshot(
            sourceDate: Date(),
            sourceName: "不可用",
            planType: nil,
            fiveHourUsedPercent: nil,
            weeklyUsedPercent: nil,
            fiveHourWindowMinutes: nil,
            weeklyWindowMinutes: nil,
            fiveHourResetAt: nil,
            weeklyResetAt: nil,
            warningMessage: nil,
            errorMessage: error
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let reader = CodexQuotaReader()
    private var statusItem: NSStatusItem?

    private var snapshot: UsageSnapshot?
    private var refreshTimer: Timer?
    private var isRefreshing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: 126)
        statusItem?.isVisible = true

        if let button = statusItem?.button {
            button.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            button.image = NSImage(systemSymbolName: "bolt.circle.fill", accessibilityDescription: "Codex")
            button.imagePosition = .imageLeading
            button.title = " 同步中"
            button.toolTip = "Codex 5小时 / 一周剩余额度与 banked resets"
            debugLog("status button created")
        } else {
            debugLog("status button missing")
        }

        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    @objc private func refreshNow() {
        refresh()
    }

    @objc private func openCodex() {
        let candidates = [
            "/Applications/ChatGPT.app",
            "/Applications/Codex.app",
            "\(NSHomeDirectory())/Applications/Codex.app"
        ]

        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        rebuildMenu()
        reader.read { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.isRefreshing = false
                self.snapshot = snapshot
                self.updateStatusTitle()
                self.rebuildMenu()
                let bankedCount = snapshot.bankedResetSummary?.availableCount
                debugLog(
                    "refreshed source=\(snapshot.sourceName) " +
                    "fiveHour=\(snapshot.fiveHourUsedPercent.map(String.init) ?? "--") " +
                    "weekly=\(snapshot.weeklyUsedPercent.map(String.init) ?? "--") " +
                    "banked=\(bankedCount.map(String.init) ?? "--")"
                )
            }
        }
    }

    private func updateStatusTitle() {
        guard let snapshot, snapshot.errorMessage == nil else {
            statusItem?.button?.title = " --"
            debugLog("status title set: --")
            return
        }

        let fiveHour = formatPercent(snapshot.fiveHourRemainingPercent)
        let weekly = formatPercent(snapshot.weeklyRemainingPercent)
        let title = " 5h \(fiveHour) W \(weekly)"
        statusItem?.button?.title = title
        statusItem?.length = 126
        debugLog("status title set:\(title)")
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if let snapshot {
            if let error = snapshot.errorMessage {
                addDisabledItem("Codex 用量暂不可读", to: menu)
                addDisabledItem(error, to: menu)
            } else {
                let panelItem = NSMenuItem()
                panelItem.view = QuotaPanelView(snapshot: snapshot)
                menu.addItem(panelItem)
                let warnings = [snapshot.warningMessage, snapshot.bankedResetErrorMessage].compactMap { $0 }
                if !warnings.isEmpty {
                    menu.addItem(NSMenuItem.separator())
                    for warning in warnings {
                        addDisabledItem(warning, to: menu)
                    }
                }
            }
        } else {
            addDisabledItem("Codex 用量加载中", to: menu)
        }

        menu.addItem(NSMenuItem.separator())

        let refreshTitle = isRefreshing ? "正在同步…" : "立即同步"
        let refreshItem = NSMenuItem(title: refreshTitle, action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !isRefreshing
        menu.addItem(refreshItem)

        let openItem = NSMenuItem(title: "打开 Codex", action: #selector(openCodex), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func addDisabledItem(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func formatPercent(_ value: Int?) -> String {
        guard let value else {
            return "--%"
        }
        return "\(value)%"
    }

}

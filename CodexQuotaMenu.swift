import Cocoa
import Foundation

private func debugLog(_ message: String) {
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

struct UsageSnapshot {
    let sourceDate: Date
    let sourceName: String
    let planType: String?
    let primaryUsedPercent: Int?
    let secondaryUsedPercent: Int?
    let primaryWindowMinutes: Int?
    let secondaryWindowMinutes: Int?
    let primaryResetAt: Date?
    let secondaryResetAt: Date?
    let warningMessage: String?
    let errorMessage: String?

    var primaryRemainingPercent: Int? {
        primaryUsedPercent.map { max(0, 100 - $0) }
    }

    var secondaryRemainingPercent: Int? {
        secondaryUsedPercent.map { max(0, 100 - $0) }
    }
}

final class QuotaPanelView: NSView {
    private static let panelSize = NSSize(width: 350, height: 216)
    private let snapshot: UsageSnapshot
    private let syncTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    init(snapshot: UsageSnapshot) {
        self.snapshot = snapshot
        super.init(frame: NSRect(origin: .zero, size: Self.panelSize))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Codex 5小时与一周剩余额度")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        Self.panelSize
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
            remainingPercent: snapshot.primaryRemainingPercent,
            resetAt: snapshot.primaryResetAt,
            top: 57
        )
        drawMetric(
            title: "一周额度",
            remainingPercent: snapshot.secondaryRemainingPercent,
            resetAt: snapshot.secondaryResetAt,
            top: 126
        )

        let source = "\(syncTimeFormatter.string(from: snapshot.sourceDate)) 同步 · \(snapshot.sourceName)"
        drawText(
            source,
            in: NSRect(x: 16, y: 198, width: 318, height: 15),
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
            return "刷新时间未知"
        }

        let totalMinutes = max(0, Int(date.timeIntervalSinceNow) / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return "\(days)天 \(hours)小时后刷新"
        }
        if hours > 0 {
            return "\(hours)小时 \(minutes)分后刷新"
        }
        if minutes > 0 {
            return "\(minutes)分后刷新"
        }
        return "即将刷新"
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
    private let authURL = URL(fileURLWithPath: "\(NSHomeDirectory())/.codex/auth.json")
    private let databasePaths = [
        "\(NSHomeDirectory())/.codex/logs_2.sqlite",
        "\(NSHomeDirectory())/.codex/sqlite/logs_2.sqlite"
    ]
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
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
            var request = URLRequest(url: usageURL)
            request.httpMethod = "GET"
            request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(credentials.accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
            request.setValue("CodexQuotaMenu/2.1", forHTTPHeaderField: "User-Agent")

            session.dataTask(with: request) { [weak self] data, response, error in
                guard let self else {
                    return
                }

                do {
                    if let error {
                        throw error
                    }

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        throw NSError(
                            domain: "CodexQuotaMenu.API",
                            code: status,
                            userInfo: [NSLocalizedDescriptionKey: "Codex 用量接口返回 HTTP \(status)"]
                        )
                    }

                    guard let data else {
                        throw NSError(
                            domain: "CodexQuotaMenu.API",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Codex 用量接口没有返回数据"]
                        )
                    }

                    completion(try self.parseAPIResponse(data))
                } catch {
                    completion(self.readLogFallback(apiError: error))
                }
            }.resume()
        } catch {
            completion(readLogFallback(apiError: error))
        }
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

        let primary = rateLimit["primary_window"] as? [String: Any]
        let secondary = rateLimit["secondary_window"] as? [String: Any]
        guard primary != nil || secondary != nil else {
            throw NSError(
                domain: "CodexQuotaMenu.API",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Codex 用量接口没有窗口数据"]
            )
        }

        return UsageSnapshot(
            sourceDate: Date(),
            sourceName: "Codex 官方用量接口",
            planType: json["plan_type"] as? String,
            primaryUsedPercent: intValue(primary?["used_percent"]),
            secondaryUsedPercent: intValue(secondary?["used_percent"]),
            primaryWindowMinutes: secondsToMinutes(primary?["limit_window_seconds"]),
            secondaryWindowMinutes: secondsToMinutes(secondary?["limit_window_seconds"]),
            primaryResetAt: epochDate(primary?["reset_at"]),
            secondaryResetAt: epochDate(secondary?["reset_at"]),
            warningMessage: nil,
            errorMessage: nil
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
        return UsageSnapshot(
            sourceDate: Date(timeIntervalSince1970: timestamp),
            sourceName: "本地日志（备用）",
            planType: headerValue("x-codex-plan-type", in: body),
            primaryUsedPercent: intHeaderValue("x-codex-primary-used-percent", in: body),
            secondaryUsedPercent: intHeaderValue("x-codex-secondary-used-percent", in: body),
            primaryWindowMinutes: intHeaderValue("x-codex-primary-window-minutes", in: body),
            secondaryWindowMinutes: intHeaderValue("x-codex-secondary-window-minutes", in: body),
            primaryResetAt: dateHeaderValue("x-codex-primary-reset-at", in: body),
            secondaryResetAt: dateHeaderValue("x-codex-secondary-reset-at", in: body),
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
            primaryUsedPercent: nil,
            secondaryUsedPercent: nil,
            primaryWindowMinutes: nil,
            secondaryWindowMinutes: nil,
            primaryResetAt: nil,
            secondaryResetAt: nil,
            warningMessage: nil,
            errorMessage: error
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let reader = CodexQuotaReader()
    private var statusItem: NSStatusItem?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

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
            button.toolTip = "Codex 5小时 / 一周用量剩余"
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
                debugLog("refreshed source=\(snapshot.sourceName) primary=\(snapshot.primaryUsedPercent.map(String.init) ?? "--") secondary=\(snapshot.secondaryUsedPercent.map(String.init) ?? "--")")
            }
        }
    }

    private func updateStatusTitle() {
        guard let snapshot, snapshot.errorMessage == nil else {
            statusItem?.button?.title = " --"
            debugLog("status title set: --")
            return
        }

        let primary = formatPercent(snapshot.primaryRemainingPercent)
        let secondary = formatPercent(snapshot.secondaryRemainingPercent)
        let title = " 5h\(primary) W\(secondary)"
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
                menu.addItem(NSMenuItem.separator())
                addDisabledItem("5小时刷新：\(formatDate(snapshot.primaryResetAt))", to: menu)
                addDisabledItem("一周刷新：\(formatDate(snapshot.secondaryResetAt))", to: menu)
                if let warning = snapshot.warningMessage {
                    menu.addItem(NSMenuItem.separator())
                    addDisabledItem(warning, to: menu)
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

    private func formatDate(_ date: Date?) -> String {
        guard let date else {
            return "--"
        }
        return dateFormatter.string(from: date)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
debugLog("app.run starting")
app.run()

import Foundation

private final class OpenCodeGoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let sourceHost = task.originalRequest?.url?.host?.lowercased()
        let destinationHost = request.url?.host?.lowercased()
        if sourceHost == destinationHost,
           request.url?.scheme?.lowercased() == "https" {
            completionHandler(request)
        } else {
            completionHandler(nil)
        }
    }
}

final class OpenCodeGoReader {
    private let redirectDelegate = OpenCodeGoRedirectDelegate()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        configuration.httpCookieStorage = nil
        return URLSession(
            configuration: configuration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
    }()

    private let baseURL = URL(string: "https://opencode.ai")!
    private let serverURL = URL(string: "https://opencode.ai/_server")!
    private let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"

    func read(
        cookie: String,
        workspaceOverride: String?,
        previous: OpenCodeGoSnapshot?,
        completion: @escaping (OpenCodeGoSnapshot) -> Void
    ) {
        let now = Date()
        guard let filtered = OpenCodeGoParser.filteredCookieHeader(from: cookie) else {
            completion(OpenCodeGoSnapshot.failure(
                OpenCodeGoUsageError.cookieMissing,
                workspaceID: nil,
                previous: previous,
                now: now
            ))
            return
        }
        fetchWorkspaceAndPage(
            cookie: filtered,
            workspaceOverride: workspaceOverride,
            completion: { result in
                switch result {
                case .success(let snapshot):
                    completion(snapshot)
                case .failure(let error):
                    completion(OpenCodeGoSnapshot.failure(
                        error,
                        workspaceID: nil,
                        previous: previous,
                        now: now
                    ))
                }
            }
        )
    }

    private func fetchWorkspaceAndPage(
        cookie: String,
        workspaceOverride: String?,
        completion: @escaping (Result<OpenCodeGoSnapshot, Error>) -> Void
    ) {
        let override = OpenCodeGoParser.normalizeWorkspaceID(workspaceOverride)
        fetchWorkspaceID(cookie: cookie) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let workspaceID):
                self.fetchUsagePage(workspaceID: workspaceID, cookie: cookie, completion: completion)
            case .failure(let error):
                if let override,
                   error as? OpenCodeGoUsageError != .invalidCredentials {
                    self.fetchUsagePage(workspaceID: override, cookie: cookie, completion: completion)
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    private func fetchWorkspaceID(
        cookie: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let request = serverRequest(
            serverID: OpenCodeGoParser.workspacesServerID,
            args: nil,
            method: "GET",
            referer: baseURL,
            cookie: cookie
        )
        perform(request) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let text):
                if OpenCodeGoParser.looksSignedOut(text: text) {
                    completion(.failure(OpenCodeGoUsageError.invalidCredentials))
                    return
                }
                var ids = OpenCodeGoParser.parseWorkspaceIDs(text: text)
                if ids.isEmpty {
                    ids = OpenCodeGoParser.parseWorkspaceIDsFromJSON(text: text)
                }
                if let first = ids.first {
                    completion(.success(first))
                    return
                }

                let postRequest = self.serverRequest(
                    serverID: OpenCodeGoParser.workspacesServerID,
                    args: "[]",
                    method: "POST",
                    referer: self.baseURL,
                    cookie: cookie
                )
                self.perform(postRequest) { postResult in
                    switch postResult {
                    case .success(let fallbackText):
                        if OpenCodeGoParser.looksSignedOut(text: fallbackText) {
                            completion(.failure(OpenCodeGoUsageError.invalidCredentials))
                            return
                        }
                        var fallbackIDs = OpenCodeGoParser.parseWorkspaceIDs(text: fallbackText)
                        if fallbackIDs.isEmpty {
                            fallbackIDs = OpenCodeGoParser.parseWorkspaceIDsFromJSON(text: fallbackText)
                        }
                        if let first = fallbackIDs.first {
                            completion(.success(first))
                        } else {
                            completion(.failure(OpenCodeGoUsageError.parseFailed("找不到 workspace")))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func fetchUsagePage(
        workspaceID: String,
        cookie: String,
        completion: @escaping (Result<OpenCodeGoSnapshot, Error>) -> Void
    ) {
        guard let url = URL(string: "https://opencode.ai/workspace/\(workspaceID)/go") else {
            completion(.failure(OpenCodeGoUsageError.parseFailed("workspace URL 无效")))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )

        perform(request) { result in
            switch result {
            case .success(let text):
                if OpenCodeGoParser.looksSignedOut(text: text) {
                    completion(.failure(OpenCodeGoUsageError.invalidCredentials))
                    return
                }
                do {
                    let snapshot = try OpenCodeGoParser.parseSubscription(text: text, now: Date())
                    completion(.success(self.snapshot(snapshot, withWorkspaceID: workspaceID)))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func perform(
        _ request: URLRequest,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(OpenCodeGoUsageError.networkError(error.localizedDescription)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(OpenCodeGoUsageError.networkError("无 HTTP 响应")))
                return
            }
            let bodyText = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            guard (200...299).contains(httpResponse.statusCode) else {
                if OpenCodeGoParser.looksSignedOut(text: bodyText)
                    || httpResponse.statusCode == 401
                    || httpResponse.statusCode == 403 {
                    completion(.failure(OpenCodeGoUsageError.invalidCredentials))
                } else if let message = OpenCodeGoParser.extractServerErrorMessage(from: bodyText) {
                    completion(.failure(
                        OpenCodeGoUsageError.apiError("HTTP \(httpResponse.statusCode): \(message)")
                    ))
                } else {
                    completion(.failure(OpenCodeGoUsageError.apiError("HTTP \(httpResponse.statusCode)")))
                }
                return
            }
            completion(.success(bodyText))
        }.resume()
    }

    private func serverRequest(
        serverID: String,
        args: String?,
        method: String,
        referer: URL,
        cookie: String
    ) -> URLRequest {
        let url: URL
        if method.uppercased() == "GET" {
            var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
            var queryItems = [URLQueryItem(name: "id", value: serverID)]
            if let args, !args.isEmpty {
                queryItems.append(URLQueryItem(name: "args", value: args))
            }
            components?.queryItems = queryItems
            url = components?.url ?? serverURL
        } else {
            url = serverURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue(serverID, forHTTPHeaderField: "X-Server-Id")
        request.setValue("server-fn:\(UUID().uuidString)", forHTTPHeaderField: "X-Server-Instance")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue(
            "text/javascript, application/json;q=0.9, */*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        if method.uppercased() != "GET", let args {
            request.httpBody = args.data(using: .utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func snapshot(
        _ snapshot: OpenCodeGoSnapshot,
        withWorkspaceID workspaceID: String
    ) -> OpenCodeGoSnapshot {
        OpenCodeGoSnapshot(
            rolling5h: snapshot.rolling5h,
            weekly: snapshot.weekly,
            monthly: snapshot.monthly,
            workspaceID: workspaceID,
            lastUpdated: snapshot.lastUpdated,
            source: snapshot.source,
            isStale: snapshot.isStale,
            errorMessage: snapshot.errorMessage,
            renewsAt: snapshot.renewsAt,
            zenBalanceUSD: snapshot.zenBalanceUSD
        )
    }
}

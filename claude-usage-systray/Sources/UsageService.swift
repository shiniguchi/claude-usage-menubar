import Foundation

// MARK: - OAuth Keychain

struct KeychainCredentials: Decodable {
    let claudeAiOauth: OAuthData

    struct OAuthData: Decodable {
        let accessToken: String
        let expiresAt: Double
    }
}

func readOAuthCredentials() throws -> KeychainCredentials.OAuthData {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "Keychain", code: Int(process.terminationStatus),
                      userInfo: [NSLocalizedDescriptionKey: "Claude Code credentials not found in Keychain. Make sure Claude Code is installed and logged in."])
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let creds = try JSONDecoder().decode(KeychainCredentials.self, from: data)
    return creds.claudeAiOauth
}

// MARK: - API Response Model

/// Parses the API's ISO8601 timestamps, with or without fractional seconds.
func parseResetsAtDate(_ string: String?) -> Date? {
    guard let string else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: string) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: string)
}

struct OAuthUsageResponse: Decodable {
    // Legacy fields — kept as fallback for older API responses
    let fiveHour: UsagePeriod?
    let sevenDay: UsagePeriod?
    let sevenDaySonnet: UsagePeriod?
    // Current source of truth: one entry per limit, scoped limits carry a model name
    let limits: [LimitEntry]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case limits
    }

    struct UsagePeriod: Decodable {
        let utilization: Double
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }

        var resetsAtDate: Date? { parseResetsAtDate(resetsAt) }
    }

    struct LimitEntry: Decodable {
        let kind: String            // "session" | "weekly_all" | "weekly_scoped" | future kinds
        let percent: Int
        let resetsAt: String?
        let scope: Scope?

        enum CodingKeys: String, CodingKey {
            case kind, percent, scope
            case resetsAt = "resets_at"
        }

        struct Scope: Decodable {
            let model: Model?
            struct Model: Decodable {
                let displayName: String?
                enum CodingKeys: String, CodingKey { case displayName = "display_name" }
            }
        }

        var resetsAtDate: Date? { parseResetsAtDate(resetsAt) }
    }
}

/// Builds the UI snapshot from an API response. Prefers the `limits` array
/// (current API shape); falls back to the legacy top-level fields.
func makeSnapshot(from response: OAuthUsageResponse, now: Date = Date()) -> UsageSnapshot {
    func countdown(_ date: Date?) -> String? {
        date.map { formatTimeRemaining(until: $0, from: now) }
    }

    let session = response.limits?.first { $0.kind == "session" }
    let weekly = response.limits?.first { $0.kind == "weekly_all" }
    let scoped = (response.limits ?? [])
        .filter { $0.kind == "weekly_scoped" }
        .map { ScopedLimit(name: $0.scope?.model?.displayName ?? "Scoped",
                           percent: $0.percent,
                           resetsIn: countdown($0.resetsAtDate)) }

    return UsageSnapshot(
        fiveHourUtilization: session?.percent ?? Int(response.fiveHour?.utilization ?? 0),
        sevenDayUtilization: weekly?.percent ?? Int(response.sevenDay?.utilization ?? 0),
        scopedLimits: scoped,
        fiveHourResetIn: countdown(session?.resetsAtDate ?? response.fiveHour?.resetsAtDate),
        sevenDayResetIn: countdown(weekly?.resetsAtDate ?? response.sevenDay?.resetsAtDate),
        lastUpdated: now
    )
}

// MARK: - Utilization helpers (pure, testable)

/// Whether a cached OAuth token is still usable. `expiresAtMs` is epoch
/// milliseconds (as stored by Claude Code in the Keychain). A 60-second
/// buffer avoids using a token that expires mid-request.
func isTokenValid(expiresAtMs: Double, now: Date = Date()) -> Bool {
    return expiresAtMs / 1000 - now.timeIntervalSince1970 > 60
}

/// Returns utilization percentage (0–100) given token count and limit.
func calculateUtilization(tokens: Int, limit: Int) -> Int {
    guard limit > 0 else { return 0 }
    return min(100, tokens * 100 / limit)
}

/// Formats a future date as a human-readable countdown string.
func formatTimeRemaining(until date: Date, from now: Date = Date()) -> String {
    let interval = date.timeIntervalSince(now)
    if interval <= 0 { return "now" }
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60
    return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
}

// MARK: - UsageService

final class UsageService: ObservableObject {
    static let shared = UsageService()

    @Published private(set) var currentUsage: UsageSnapshot = .placeholder
    @Published private(set) var error: String?
    @Published private(set) var isLoading: Bool = false

    private var refreshTimer: Timer?
    private let normalInterval: TimeInterval = 5 * 60   // 5 minutes
    private let backoffInterval: TimeInterval = 15 * 60 // 15 minutes after 429

    // Injectable for testing
    var urlSession: URLSession = .shared

    // Cached Keychain credentials. Reading the Keychain spawns `security`,
    // which triggers a user password prompt whenever Claude Code has
    // recreated the item (it does so on every token refresh, wiping the
    // ACL — see anthropics/claude-code#22144). Cache until expiry so we
    // read at most a few times a day instead of every poll.
    private var cachedCredentials: KeychainCredentials.OAuthData?

    private init() {}

    func startPolling() {
        fetchUsage()
        scheduleTimer(interval: normalInterval)
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func scheduleTimer(interval: TimeInterval) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.fetchUsage()
        }
    }

    func fetchUsage() {
        DispatchQueue.main.async { self.isLoading = true }

        Task {
            do {
                let response = try await fetchUsageRefreshingTokenOn401()
                let snapshot = makeSnapshot(from: response)

                await MainActor.run {
                    self.currentUsage = snapshot
                    self.error = nil
                    self.isLoading = false
                    self.scheduleTimer(interval: self.normalInterval)
                }
            } catch let error as NSError {
                let isRateLimit = error.code == 429
                await MainActor.run {
                    if isRateLimit {
                        self.error = "Rate limited — retrying in 15 min"
                        self.scheduleTimer(interval: self.backoffInterval)
                    } else {
                        self.error = error.localizedDescription
                        self.scheduleTimer(interval: self.normalInterval)
                    }
                    self.isLoading = false
                }
            }
        }
    }

    private func currentAccessToken() throws -> String {
        if let cached = cachedCredentials, isTokenValid(expiresAtMs: cached.expiresAt) {
            return cached.accessToken
        }
        let creds = try readOAuthCredentials()
        cachedCredentials = creds
        return creds.accessToken
    }

    private func fetchUsageRefreshingTokenOn401() async throws -> OAuthUsageResponse {
        do {
            return try await fetchOAuthUsage(accessToken: currentAccessToken())
        } catch let error as NSError where error.domain == "OAuthUsage" && error.code == 401 {
            // Claude Code rotated the token under us — drop the cache and retry once
            cachedCredentials = nil
            return try await fetchOAuthUsage(accessToken: currentAccessToken())
        }
    }

    func fetchOAuthUsage(accessToken: String) async throws -> OAuthUsageResponse {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        print("[UsageService] GET /api/oauth/usage")

        let (data, response) = try await urlSession.data(for: request)
        let body = String(data: data, encoding: .utf8) ?? "<binary>"

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        print("[UsageService] HTTP \(http.statusCode) — \(body.prefix(300))")

        guard http.statusCode == 200 else {
            throw NSError(domain: "OAuthUsage", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
        }

        return try JSONDecoder().decode(OAuthUsageResponse.self, from: data)
    }
}

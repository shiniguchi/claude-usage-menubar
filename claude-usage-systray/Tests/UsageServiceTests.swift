import XCTest
@testable import ClaudeUsageSystray

// MARK: - OAuthUsageResponse decoding

final class OAuthUsageResponseTests: XCTestCase {

    func testDecodesFullResponse() throws {
        let json = """
        {
          "five_hour":   { "utilization": 35.0, "resets_at": "2026-03-19T19:00:00.367134+00:00" },
          "seven_day":   { "utilization": 71.0, "resets_at": "2026-03-20T11:00:00.367161+00:00" },
          "seven_day_sonnet": { "utilization": 27.0, "resets_at": "2026-03-20T12:00:00.367175+00:00" },
          "seven_day_oauth_apps": null,
          "seven_day_opus": null,
          "seven_day_cowork": null,
          "iguana_necktie": null,
          "extra_usage": { "is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: json)

        XCTAssertEqual(response.fiveHour?.utilization, 35.0)
        XCTAssertEqual(response.sevenDay?.utilization, 71.0)
        XCTAssertEqual(response.sevenDaySonnet?.utilization, 27.0)
    }

    func testDecodesNullSonnet() throws {
        let json = """
        {
          "five_hour":   { "utilization": 10.0, "resets_at": "2026-03-19T19:00:00+00:00" },
          "seven_day":   { "utilization": 20.0, "resets_at": "2026-03-20T11:00:00+00:00" },
          "seven_day_sonnet": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: json)

        XCTAssertNil(response.sevenDaySonnet)
        XCTAssertEqual(response.fiveHour?.utilization, 10.0)
    }

    func testDecodesAllNulls() throws {
        let json = """
        {
          "five_hour": null,
          "seven_day": null,
          "seven_day_sonnet": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: json)

        XCTAssertNil(response.fiveHour)
        XCTAssertNil(response.sevenDay)
        XCTAssertNil(response.sevenDaySonnet)
    }

    func testResetsAtDateParsesWithFractionalSeconds() throws {
        let json = """
        {
          "five_hour": { "utilization": 35.0, "resets_at": "2026-03-19T19:00:00.367134+00:00" },
          "seven_day": null, "seven_day_sonnet": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: json)
        XCTAssertNotNil(response.fiveHour?.resetsAtDate, "resetsAt date should parse successfully")
    }

    func testDecodesNullResetsAt() throws {
        let json = """
        {
          "five_hour":   { "utilization": 8.0, "resets_at": "2026-04-09T19:00:00.436790+00:00" },
          "seven_day":   { "utilization": 15.0, "resets_at": "2026-04-13T13:00:00.436851+00:00" },
          "seven_day_sonnet": { "utilization": 0.0, "resets_at": null }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: json)

        XCTAssertEqual(response.sevenDaySonnet?.utilization, 0.0)
        XCTAssertNil(response.sevenDaySonnet?.resetsAtDate)
    }

    func testUtilizationConvertsToInt() throws {
        let json = """
        {
          "five_hour":   { "utilization": 34.7, "resets_at": "2026-03-19T19:00:00+00:00" },
          "seven_day":   { "utilization": 71.2, "resets_at": "2026-03-20T11:00:00+00:00" },
          "seven_day_sonnet": { "utilization": 26.9, "resets_at": "2026-03-20T12:00:00+00:00" }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: json)

        // Int() truncates (floors), matching how snapshot builds utilization
        XCTAssertEqual(Int(response.fiveHour!.utilization), 34)
        XCTAssertEqual(Int(response.sevenDay!.utilization), 71)
        XCTAssertEqual(Int(response.sevenDaySonnet!.utilization), 26)
    }
}

// MARK: - limits array (new API shape, captured live 2026-07-22)

final class LimitsArrayTests: XCTestCase {

    // Trimmed verbatim from GET /api/oauth/usage — includes unknown keys the
    // decoder must tolerate and null legacy fields.
    private let livePayload = """
    {
      "five_hour": { "utilization": 57.0, "resets_at": "2026-07-22T15:10:00.002458+00:00", "limit_dollars": null },
      "seven_day": { "utilization": 30.0, "resets_at": "2026-07-26T20:00:00.002477+00:00", "limit_dollars": null },
      "seven_day_sonnet": null,
      "seven_day_opus": null,
      "iguana_necktie": null,
      "nimbus_quill": null,
      "limits": [
        { "kind": "session", "group": "session", "percent": 57, "severity": "normal",
          "resets_at": "2026-07-22T15:10:00.002458+00:00", "scope": null, "is_active": true },
        { "kind": "weekly_all", "group": "weekly", "percent": 30, "severity": "normal",
          "resets_at": "2026-07-26T20:00:00.002477+00:00", "scope": null, "is_active": false },
        { "kind": "weekly_scoped", "group": "weekly", "percent": 48, "severity": "normal",
          "resets_at": "2026-07-26T20:00:00.002663+00:00",
          "scope": { "model": { "id": null, "display_name": "Fable" }, "surface": null }, "is_active": false }
      ]
    }
    """.data(using: .utf8)!

    func testDecodesLimitsArray() throws {
        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: livePayload)

        XCTAssertEqual(response.limits?.count, 3)
        XCTAssertEqual(response.limits?[0].kind, "session")
        XCTAssertEqual(response.limits?[0].percent, 57)
        XCTAssertEqual(response.limits?[2].kind, "weekly_scoped")
        XCTAssertEqual(response.limits?[2].scope?.model?.displayName, "Fable")
    }

    func testMakeSnapshotPrefersLimitsArray() throws {
        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: livePayload)
        let snapshot = makeSnapshot(from: response)

        XCTAssertEqual(snapshot.fiveHourUtilization, 57)
        XCTAssertEqual(snapshot.sevenDayUtilization, 30)
        XCTAssertEqual(snapshot.scopedLimits, [ScopedLimit(name: "Fable", percent: 48, resetsIn: snapshot.scopedLimits.first?.resetsIn)])
        XCTAssertEqual(snapshot.scopedLimits.first?.name, "Fable")
        XCTAssertEqual(snapshot.scopedLimits.first?.percent, 48)
    }

    func testMakeSnapshotFallsBackToLegacyFields() throws {
        let legacy = """
        {
          "five_hour": { "utilization": 35.0, "resets_at": "2026-03-19T19:00:00.367134+00:00" },
          "seven_day": { "utilization": 71.0, "resets_at": "2026-03-20T11:00:00.367161+00:00" },
          "seven_day_sonnet": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: legacy)
        let snapshot = makeSnapshot(from: response)

        XCTAssertEqual(snapshot.fiveHourUtilization, 35)
        XCTAssertEqual(snapshot.sevenDayUtilization, 71)
        XCTAssertTrue(snapshot.scopedLimits.isEmpty)
    }

    func testScopedLimitWithNullDisplayNameFallsBackToScoped() throws {
        let json = """
        {
          "five_hour": null, "seven_day": null,
          "limits": [
            { "kind": "weekly_scoped", "percent": 12, "resets_at": null,
              "scope": { "model": { "id": null, "display_name": null } } }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OAuthUsageResponse.self, from: json)
        let snapshot = makeSnapshot(from: response)

        XCTAssertEqual(snapshot.scopedLimits.first?.name, "Scoped")
        XCTAssertEqual(snapshot.scopedLimits.first?.percent, 12)
    }
}

// MARK: - calculateUtilization

final class CalculateUtilizationTests: XCTestCase {

    func testZeroTokensIsZeroPercent() {
        XCTAssertEqual(calculateUtilization(tokens: 0, limit: 100_000), 0)
    }

    func testHalfLimitIsFiftyPercent() {
        XCTAssertEqual(calculateUtilization(tokens: 50_000, limit: 100_000), 50)
    }

    func testExceedingLimitCapsAtHundred() {
        XCTAssertEqual(calculateUtilization(tokens: 200_000, limit: 100_000), 100)
    }

    func testExactLimitIsHundredPercent() {
        XCTAssertEqual(calculateUtilization(tokens: 100_000, limit: 100_000), 100)
    }

    func testZeroLimitReturnsZero() {
        XCTAssertEqual(calculateUtilization(tokens: 50_000, limit: 0), 0)
    }

    func testRoundsDown() {
        XCTAssertEqual(calculateUtilization(tokens: 1, limit: 3), 33)
    }
}

// MARK: - isTokenValid

final class IsTokenValidTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_784_700_000) // fixed clock

    func testTokenExpiringInOneHourIsValid() {
        let expiresAtMs = (now.timeIntervalSince1970 + 3600) * 1000
        XCTAssertTrue(isTokenValid(expiresAtMs: expiresAtMs, now: now))
    }

    func testExpiredTokenIsInvalid() {
        let expiresAtMs = (now.timeIntervalSince1970 - 1) * 1000
        XCTAssertFalse(isTokenValid(expiresAtMs: expiresAtMs, now: now))
    }

    func testTokenInsideSixtySecondBufferIsInvalid() {
        // Expiring in 30s — inside the 60s safety buffer, treat as invalid
        let expiresAtMs = (now.timeIntervalSince1970 + 30) * 1000
        XCTAssertFalse(isTokenValid(expiresAtMs: expiresAtMs, now: now))
    }

    func testTokenJustOutsideBufferIsValid() {
        let expiresAtMs = (now.timeIntervalSince1970 + 61) * 1000
        XCTAssertTrue(isTokenValid(expiresAtMs: expiresAtMs, now: now))
    }
}

// MARK: - evaluateAlert

final class EvaluateAlertTests: XCTestCase {

    func testCrossingWarningThresholdFiresWarning() {
        XCTAssertEqual(evaluateAlert(percent: 82, warning: 80, critical: 90,
                                     lastWarningNotified: 0, lastCriticalNotified: 0), .warning)
    }

    func testCrossingCriticalThresholdFiresCritical() {
        XCTAssertEqual(evaluateAlert(percent: 95, warning: 80, critical: 90,
                                     lastWarningNotified: 0, lastCriticalNotified: 0), .critical)
    }

    func testCriticalWinsOverWarning() {
        // At/above critical, never downgrade to a warning notification
        XCTAssertEqual(evaluateAlert(percent: 90, warning: 80, critical: 90,
                                     lastWarningNotified: 0, lastCriticalNotified: 0), .critical)
    }

    func testAlreadyNotifiedWarningStaysSilent() {
        XCTAssertNil(evaluateAlert(percent: 85, warning: 80, critical: 90,
                                   lastWarningNotified: 80, lastCriticalNotified: 0))
    }

    func testAlreadyNotifiedCriticalStaysSilent() {
        XCTAssertNil(evaluateAlert(percent: 95, warning: 80, critical: 90,
                                   lastWarningNotified: 80, lastCriticalNotified: 90))
    }

    func testBelowWarningStaysSilent() {
        XCTAssertNil(evaluateAlert(percent: 51, warning: 80, critical: 90,
                                   lastWarningNotified: 0, lastCriticalNotified: 0))
    }
}

// MARK: - formatTimeRemaining

final class FormatTimeRemainingTests: XCTestCase {

    func testPastDateReturnsNow() {
        let past = Date().addingTimeInterval(-60)
        XCTAssertEqual(formatTimeRemaining(until: past), "now")
    }

    func testFortyFiveMinutesRemaining() {
        let now = Date()
        XCTAssertEqual(formatTimeRemaining(until: now.addingTimeInterval(45 * 60), from: now), "45m")
    }

    func testTwoHoursThirtyMinutes() {
        let now = Date()
        XCTAssertEqual(formatTimeRemaining(until: now.addingTimeInterval(2 * 3600 + 30 * 60), from: now), "2h 30m")
    }

    func testExactlyOneHour() {
        let now = Date()
        XCTAssertEqual(formatTimeRemaining(until: now.addingTimeInterval(3600), from: now), "1h 0m")
    }
}

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A macOS menu bar (systray) app showing Claude.ai plan usage (5h session / 7d weekly limits). Swift + AppKit/SwiftUI, macOS 13+. All project code lives under `claude-usage-systray/`; run build/test commands from that directory.

## Commands

```bash
cd claude-usage-systray

# Build
xcodebuild -scheme ClaudeUsageSystray -configuration Release build

# Run all tests (this is what CI runs; disable signing locally too)
xcodebuild test -project ClaudeUsageSystray.xcodeproj \
  -scheme ClaudeUsageSystrayTests \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run a single test class or method
xcodebuild test -project ClaudeUsageSystray.xcodeproj \
  -scheme ClaudeUsageSystrayTests \
  -destination 'platform=macOS' \
  -only-testing:ClaudeUsageSystrayTests/OAuthUsageResponseTests/testDecodesFullResponse \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

The Xcode project is generated from `project.yml` (XcodeGen) but `ClaudeUsageSystray.xcodeproj` is committed. If you change targets/settings in `project.yml`, regenerate with `xcodegen generate` and commit both.

Releases are triggered by pushing a `v*` tag (`.github/workflows/release.yml` signs, notarizes, and uploads a zip). CI (`.github/workflows/ci.yml`) runs the test suite on push/PR to main.

## Architecture

No app sandbox is used (`com.apple.security.app-sandbox: false`) because the app shells out to `/usr/bin/security` to read the Claude Code OAuth token from the Keychain item `Claude Code-credentials` (JSON with `claudeAiOauth.accessToken`). It then calls the undocumented endpoint `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <token>` and header `anthropic-beta: oauth-2025-04-20`. This endpoint may change without notice; tests pin the current response shape (including unknown/null fields). The current shape's source of truth is the `limits` array (one entry per limit; `weekly_scoped` entries carry a model display name like "Fable") — the top-level `five_hour`/`seven_day` fields are legacy fallback, and `seven_day_sonnet` is dead. Snapshot building is the pure function `makeSnapshot(from:now:)`. Keychain credentials are cached in memory until token expiry (`isTokenValid`) and re-read on 401, because Claude Code recreates the Keychain item on every token refresh, wiping the ACL and triggering user password prompts (anthropics/claude-code#22144 — closed as not planned).

Data flow (`Sources/`):

- `main.swift` boots `AppDelegate` manually — this is an `LSUIElement` (no Dock icon) app; there is no `@main` App struct.
- `UsageService` (singleton, `ObservableObject`) polls the API every 5 minutes via a non-repeating timer that reschedules itself after each fetch; a 429 response backs off to 15 minutes. Keychain read + JSON decode also live here. `urlSession` is injectable for tests, and pure helpers (`calculateUtilization`, `formatTimeRemaining`) are top-level functions to keep them testable.
- `AppDelegate` owns the `NSStatusItem` and popover, subscribes to `UsageService.$currentUsage` via Combine, renders the menu bar text (compact `35% · 71%` vs icon + weekly %), applies threshold colors, and fires UNUserNotifications when warning/critical thresholds are crossed (once per threshold, tracked in `lastWarningNotified`/`lastCriticalNotified`).
- `SettingsManager` (singleton) persists `AppSettings` as JSON in UserDefaults; `AppDelegate` reacts to `UserDefaults.didChangeNotification` to re-render.
- `UsageData.swift` holds the value types: `AppSettings` (thresholds, compact display, notifications) and `UsageSnapshot` (the immutable state published by `UsageService`).
- `MenuBarView` / `SettingsView` are the SwiftUI popover contents, hosted in an `NSHostingController`.

Tests (`Tests/UsageServiceTests.swift`) cover API response decoding (including null `resets_at` and unknown fields) and the pure utilization/countdown helpers — not the networking or UI layers.

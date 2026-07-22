# Claude Usage Systray

A lightweight macOS menu bar app that shows your [Claude.ai](https://claude.ai) plan usage in real time — current session and weekly limits — without opening a browser.

![Claude Usage Systray](claude-usage-systray/Resources/Assets.xcassets/Image.imageset/Image.png)

## What it shows

Mirrors the data on `claude.ai/settings/usage`:

| Metric | Description |
|--------|-------------|
| **5h** | Current session usage (resets every ~5 hours) |
| **7d** | Weekly all-models usage |
| **Per-model** | Weekly per-model limits (e.g. Fable), taken dynamically from the API's `limits` array |

Colors update based on your configured warning/critical thresholds.

## Requirements

- macOS 13+
- [Claude Code](https://claude.ai/code) installed and logged in (the app reads its OAuth token from your Keychain — no separate credentials needed)

## Install

**Homebrew (recommended):**

```bash
brew tap adntgv/tap
brew install --cask claude-usage-systray
```

**Manual:**

Download the latest `ClaudeUsageSystray.zip` from the [Releases page](https://github.com/adntgv/claude-usage-systray/releases), unzip, and move `ClaudeUsageSystray.app` to `/Applications`. The app is notarized — macOS will open it normally on first launch.

## Build from source

```bash
git clone https://github.com/adntgv/claude-usage-systray
cd claude-usage-systray/claude-usage-systray
xcodebuild -scheme ClaudeUsageSystray -configuration Release build
open ~/Library/Developer/Xcode/DerivedData/ClaudeUsageSystray-*/Build/Products/Release/ClaudeUsageSystray.app
```

Or open `ClaudeUsageSystray.xcodeproj` in Xcode and run with ⌘R.

## Display modes

Toggle **Compact display** in Settings to switch between:

- **Compact (default):** `57% · 48% · 30%` — 5h, then up to two per-model limits (e.g. Fable), then 7d, each colored by threshold
- **Normal:** icon + `71%` — weekly usage only

## How it works

The app reads your Claude Code OAuth token from the macOS Keychain (`Claude Code-credentials`) and calls the same internal endpoint that powers `claude.ai/settings/usage`:

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <oauth_token>
anthropic-beta: oauth-2025-04-20
```

The token is cached in memory until it expires and re-read from the Keychain only then (or after a 401). This keeps Keychain reads — and the macOS password prompts caused by Claude Code recreating the item on every token refresh ([anthropics/claude-code#22144](https://github.com/anthropics/claude-code/issues/22144)) — to a few per day instead of every poll.

> **Note:** This endpoint is undocumented and may change. It requires Claude Code to be installed and logged in.

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Compact display | On | Show both 5h and 7d in menu bar |
| Warning threshold | 80% | Orange color above this |
| Critical threshold | 90% | Red color above this |
| Usage alerts | On | macOS notification when thresholds are crossed |

## Running tests

```bash
xcodebuild test -project ClaudeUsageSystray.xcodeproj \
  -scheme ClaudeUsageSystrayTests \
  -destination 'platform=macOS'
```

## License

MIT

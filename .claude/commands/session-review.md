---
description: Review current session's changes - validate, optimize, document
---

# Session Review & Code Optimization

**AI Agent Instructions**: Review changes made ONLY in this session, validate functionality, and optimize code.

---

## 1. Change Analysis

1. **Identify session changes**
   - `git status --porcelain` and `git diff --stat`

2. **Impact analysis**
   - Did the change touch the API response model, Keychain read, or polling logic in `UsageService.swift`? → decoding tests must cover it
   - Did the change touch `AppSettings`? → check `SettingsManager`, `SettingsView`, and the README settings table stay in sync
   - Did the change touch `project.yml`? → regenerate the `.xcodeproj` with `xcodegen generate`

---

## 2. Code Optimization & Quality

1. **Code simplification analysis**
   - `git diff --numstat` to calculate lines added/removed
   - Grep for leftover debug `print` statements, duplications
   - Recommend consolidation if net code increase without new behavior

---

## 3. Verification

1. Run the full test suite:
   ```bash
   cd claude-usage-systray && xcodebuild test -project ClaudeUsageSystray.xcodeproj \
     -scheme ClaudeUsageSystrayTests -destination 'platform=macOS' \
     CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
   ```
2. If the change is user-visible (menu bar text, popover, notifications), build and run the app to confirm:
   ```bash
   cd claude-usage-systray && xcodebuild -scheme ClaudeUsageSystray -configuration Debug build
   ```

---

## 4. Update Documentation

1. Compare actual final code logic with `README.md` and `CLAUDE.md`
   - Delete irrelevant context
   - Add the minimum relevant context

---

## 5. Session Report Output

Provide specific recommendations based on:
- Code complexity changes (optimization opportunities)
- Test results (paste the pass/fail summary — evidence before claims)
- Doc drift found and fixed

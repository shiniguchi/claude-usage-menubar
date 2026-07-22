---
description: Generate PR description from branch commits and diffs
---

# Branch Summary Generator

**AI Instructions**: Auto-generate an executive branch summary for the entire branch. Analyze ALL commits from `main..HEAD`, **output raw markdown text in a code block** (plain text markdown, not rendered HTML).

---

## Auto-Context Gathering

Before generating the summary, execute via `Bash`:

1. **Analyze ALL branch changes**
   - `git log main..HEAD --oneline` — all commits in branch
   - `git diff main..HEAD --stat` — all files changed

Then use the gathered context to auto-populate the summary template below.

---

## Summary Format

**Risk Level**: 🔴 High | 🟡 Medium | 🟢 Low

### ## TL;DR

**Max 2 sentences — simple, direct summary using plain language**

### ## Problem & Root Cause

**What broke and why** (number each item, show actual observations)

Format each as:
1. [Problem description]
   > [Root cause with actual logs/observations]

### ## Solution

**What we changed to fix it** (number to match problems above, show before/after for each)

1. [Solution for problem #1] ([UsageService.swift:42](claude-usage-systray/Sources/UsageService.swift#L42))
   - Before: [What the code did before]
   - After: [What the code does now]
   - Why: [Brief explanation]

### ## Impact

**What this means for users**

1. [User-visible change — menu bar display, polling, notifications, settings]

**Watch After Release**
1. [Behavior to watch — e.g. API response decoding against the undocumented usage endpoint]

### ## Verification

- Test suite result (paste the `xcodebuild test` summary line)
- Manual check performed, if any (built and ran the app, observed menu bar)

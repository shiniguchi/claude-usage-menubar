---
description: Holistic PR alignment - fix cross-file inconsistencies, delete abandoned code, refactor docs to KISS
---

# PR Holistic Alignment

**Objective**: Analyze the branch diff, fix all misalignments, delete dead code, refactor docs to KISS. Make production-ready.

---

## Core Operations

### 1. Detect Branch Changes

```bash
git diff $(git merge-base origin/main HEAD)...HEAD
```

### 2. Align Cross-File References

For each changed pattern → grep the entire repo → fix mismatches.

Examples:
- Function/type renamed: find old name usages → update all
- Target or build setting changed in `claude-usage-systray/project.yml` → regenerate with `xcodegen generate` and commit both `project.yml` and the `.xcodeproj`
- API response field added/removed in `UsageService.swift` → update decoding tests in `Tests/UsageServiceTests.swift`
- Setting added to `AppSettings` → check `SettingsManager`, `SettingsView`, and README settings table

### 3. Find and Delete Unused Code

**Step 3A: Find potentially unused files**

```bash
find claude-usage-systray/Sources claude-usage-systray/Tests -name "*.swift"
# For each, check references → flag if 0 references
```

**Step 3B: Verify & delete**

- Entry point (`main.swift`) → KEEP
- Test files testing active code → KEEP
- Truly orphaned → DELETE

**Step 3C: Delete dead code within files**

- Unreferenced functions/properties → delete
- Commented blocks (>5 lines) → delete
- Legacy code paths replaced by this branch → delete old

### 4. Verify and Update All Documentation

**Step 4A: Verify accuracy**

For each doc file, read its claims, cross-reference with actual code, flag outdated sections:
- `README.md` (especially the settings table, install steps, and "How it works")
- `CLAUDE.md`

**Step 4B: Update outdated content**

- Fix wrong function/file references
- Remove documented features that no longer exist
- Add missing critical steps

**Step 4C: Refactor to KISS**

- Paragraphs (>4 sentences) → bullet lists
- Remove redundant explanations
- Delete obvious inline comments, update outdated ones

### 5. Verify

Run the full test suite before declaring done:

```bash
cd claude-usage-systray && xcodebuild test -project ClaudeUsageSystray.xcodeproj \
  -scheme ClaudeUsageSystrayTests -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

# Claude Code hooks

Scripts that run on Claude Code lifecycle events. Wired up in `.claude/settings.json`.

## test-nudge.js

**Event:** `PostToolUse` (matchers: `Edit`, `Write`)

**Purpose:** When Claude edits a Swift file under `Sources/` or `Tests/`, inject a
reminder to run the test suite (and build/run the app for user-visible changes)
before declaring the task complete. When `project.yml` is edited, remind that the
committed `.xcodeproj` must be regenerated with `xcodegen generate`.

### Test the hook locally

```bash
echo '{"tool_input":{"file_path":"/abs/path/claude-usage-systray/Sources/UsageService.swift"}}' \
  | node .claude/hooks/test-nudge.js
```

Expected: JSON with `hookSpecificOutput.additionalContext` containing the reminder.
Non-Swift paths (outside `Sources/`/`Tests/`) produce no output.

### Failure mode

Any error → exit 0 (the hook never breaks Claude) plus a one-line stderr log.
Run `claude --debug` and look for `[test-nudge]` lines if you suspect a problem.

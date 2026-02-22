# OAuth Import — Design

## Problem

TokenEater requires manual cookie import from Chromium browsers. Cookies expire monthly, causing friction. Most users are Claude Code users who already have an OAuth token in macOS Keychain.

## Solution

Add OAuth as the primary auth method. One "Connect" button that auto-detects the best method:

1. **Keychain** — read `Claude Code-credentials` → `claudeAiOauth.accessToken`
2. **Browser cookies** — existing Chromium auto-import (fallback)
3. **Manual** — paste sessionKey + orgId (last resort)

## Auth Methods

| Method | Endpoint | Auth | Org ID | Expiration |
|--------|----------|------|--------|------------|
| OAuth | `api.anthropic.com/api/oauth/usage` | `Bearer {token}` + `anthropic-beta: oauth-2025-04-20` | Not needed | Auto-refreshed by Claude Code |
| Cookies | `claude.ai/api/organizations/{orgId}/usage` | `Cookie: sessionKey=...` | Required | ~1 month |

Both endpoints return the same JSON structure (`five_hour`, `seven_day`, `seven_day_sonnet`, etc.).

## Architecture

### AuthMethod enum

```swift
enum AuthMethod {
    case oauth(token: String)       // from Keychain
    case cookies(sessionKey: String, orgId: String)  // from browser/manual
}
```

### ClaudeAPIClient changes

- `fetchUsage()` picks the best available method:
  - Try OAuth token from Keychain first
  - Fall back to stored cookies config
- On 401/403 with cookies → retry with OAuth automatically
- OAuth token is read from Keychain at each call (always fresh, never stored)

### Settings UX

- On launch: auto-detect runs silently
- If Claude Code found: show "Connected via Claude Code" badge, no config needed
- If not: show "Import from browser" button (existing flow)
- Manual fields remain accessible but collapsed/secondary
- Single "Connect" button triggers the detection cascade

### Storage

- `UserDefaults`: `authMethod` flag ("oauth" | "cookies")
- `SharedConfig` unchanged for cookie fallback
- OAuth token NOT stored — read from Keychain each time

### Cookie expiry handling

When cookies return 401/403:
1. Try OAuth silently
2. If OAuth works → switch to OAuth, update UI
3. If not → show "Session expired" error as before

## Testing

- With Claude Code installed: Keychain auto-detected
- Without: falls back to browser cookies
- Log which method is active for debugging

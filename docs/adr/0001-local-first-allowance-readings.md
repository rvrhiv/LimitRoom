# Keep allowance collection local and read-only

LimitRoom prefers documented local interfaces, has no LimitRoom backend or telemetry, and does not collect conversations or import browser cookies. Codex owns its credentials; Claude supplies a quota-only projection through a user-enabled statusLine bridge. Team Admin API access is not a fallback for a personal subscription.

As of 0.4.1, Cursor has two explicit, mutually exclusive experimental connection modes. The primary option requires confirmation before reading only `cursorAuth/accessToken` from Cursor.app's local global-state database in read-only mode. A short-lived first-party session is derived in memory and sent only to fixed `https://cursor.com` usage and identity endpoints. No token persistence/refresh, browser import or Keychain access. Redirects are rejected. The returned identity must match, and the local session is reread before publishing. Disconnect stops collection without signing out Cursor.app. History remains account-scoped.

The alternative personal web session belongs to LimitRoom's isolated WebKit profile; selecting it never silently falls back to another app/browser account. Existing WebKit consent does not enable Cursor.app access. These private storage/API contracts are not official public guarantees: live account compatibility must be verified before claiming reliable support.

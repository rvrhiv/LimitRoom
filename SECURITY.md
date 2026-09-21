# Security

## Report privately

Use [GitHub's private vulnerability reporting](https://github.com/rvrhiv/LimitRoom/security/advisories/new) for suspected credential exposure, unsafe configuration changes, account-data mix-ups, or update/signing vulnerabilities. Do not open a public issue with exploit details or secrets.

Include the affected version, macOS version, impact, and minimal reproduction using synthetic data where possible. Remove tokens, cookies, email addresses, account identifiers, and local paths. Never upload agent configuration, raw usage responses, Cursor databases, WebKit profiles, Claude setup backups, or signing material.

If a credential was exposed, revoke or rotate it through its issuer; deleting a report does not revoke access. Coordinate public disclosure after a fix is available.

## Scope and support

LimitRoom is an early-stage project. Security fixes target the latest release; older releases do not have a separate maintenance branch. There is no guaranteed response time or bounty program.

The main trust boundaries are explicit agent access, account-isolated local history, reversible Claude configuration, and signed app updates. A private dashboard endpoint is not a provider-supported contract. Sparkle signatures do not imply Apple notarization.

See [data and privacy](docs/usage.md#data-and-privacy) for storage and connection behavior, and [releasing](docs/releasing.md) for signing authority. Ordinary UI and setup problems belong in [Issues](https://github.com/rvrhiv/LimitRoom/issues/new/choose).

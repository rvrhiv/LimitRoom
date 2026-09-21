# Deliver updates through signed GitHub Releases

Decision updated for 0.5.0: the user authorized publishing sanitized source and releases in the public `rvrhiv/LimitRoom` repository. No separate release-only repository is needed. No owner PAT is embedded in the app.

Sparkle 2.10.0 owns download, verification, installation and relaunch. `UpdateController` and `UpdateUserDriver` enforce a verified feed, archive verification before extraction, and explicit approval for the offered build/URL. Scheduled discovery only updates the UI. Missing configuration fails closed; demo never starts the updater. Automatic checks are separately configurable. A failed feed-signature fallback is rejected even if Sparkle's grace period expires.

The feed is the latest public release's `appcast.xml` asset. A long-lived Ed25519 public key is embedded in the app; the private key is stored in GitHub's `release` environment secret, with a dedicated local Keychain backup. The user approved this trust boundary so trusted collaborators can publish without the owner's Mac. Only main-branch manual release jobs can access that environment. PR builds never receive the signing key. Workflow changes and repository write access are security-sensitive.

Developer ID and notarization remain separate, unavailable prerequisites. Ad-hoc signing plus Sparkle signatures does not remove first-install Gatekeeper restrictions. Existing versions without Sparkle need one manual upgrade. See [releasing](../releasing.md).

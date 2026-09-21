# Publication privacy review

Before the initial publication, a read-only audit covered tracked source, all reachable local development commits, commit metadata and the application icon. It found a machine-specific README path and private author metadata in local history; these must not be published. The intended public owner/repository/bundle identifiers are retained.

The public repository starts with a **new root snapshot** using GitHub noreply identity. The original development branch stays local. Never push all branches, mirror the repository or upload historical tags. `.gitignore` does not remove previously tracked content or commit metadata by itself.

Targeted ignores exclude agent configuration/auth files, local Claude setup backups, quota caches, databases (including Cursor state), logs, private signing material, local tool installations and build output. Public package lock files and the public Sparkle verification key are intentionally tracked. Third-party license author notices are not private user metadata.

The signing seed is a dedicated project key held in Keychain and GitHub Actions Secrets, not in Git files or artifacts. No live provider credentials were read for this publication audit. CLI authentication remains outside tracked source. Do not attach Application Support, WebKit profiles or whole home directories to bug reports.

The audit uses filename, known-secret-pattern and metadata inspection. It is **not** proof that arbitrary encoded secrets cannot exist. Recheck the exact staged snapshot, new root author metadata, release archive contents and any screenshots before publication. Only synthetic demo screenshots are suitable for public documentation.

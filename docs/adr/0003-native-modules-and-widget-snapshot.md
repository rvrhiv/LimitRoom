# Use native modules and a data-only widget snapshot

An Xcode application and WidgetKit extension share a local Swift package instead of sharing connector code or running a separate daemon. The app owns collection, SQLite history and authentication; the widget reads a small versioned snapshot from an App Group. This costs a separate snapshot format but isolates the widget from secrets, network polling and storage migrations, and lets each new connector evolve independently of either presentation.

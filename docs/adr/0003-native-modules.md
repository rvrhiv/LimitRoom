# Use native modules with app-owned collection

The Xcode application and Claude helper consume a local Swift package. The app owns collection, SQLite history and authentication; presentation reads normalized snapshots from AppModel. Core models stay independent of SwiftUI and provider transports. This keeps source formats, polling and storage migrations out of the views and lets new connectors evolve independently of the menu-bar and notch presentations. A separate always-running daemon is not needed.

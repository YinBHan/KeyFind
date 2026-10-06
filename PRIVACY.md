# Privacy

KeyFind is designed to work locally on macOS.

- Search queries are processed in memory by the bundled search service.
- Favorites and recent searches are stored in the app's local `UserDefaults`.
- The app does not require an account or send search queries to a server.
- The core lookup flow does not require Accessibility permission.
- Official source links open in the browser only when the user selects them.
- KeyFind never executes a shortcut in the active application.

Debug builds may emit launch, hotkey registration, and window lifecycle diagnostics through macOS's unified logging system for troubleshooting. These messages do not include search queries or shortcut contents, but may include the configured invocation shortcut, window state, error text, and the bundle identifier of an application that becomes active while the panel is open. Release builds do not emit these diagnostics. They are not written to a project-specific file by the app; debug-build messages can be inspected or filtered in Console using the `com.keyfind.app` subsystem.

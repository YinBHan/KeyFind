# KeyFind

KeyFind is a small macOS menu bar utility with a SwiftUI search panel for looking up keyboard shortcuts by meaning. Press `Command-Shift-Space`, type what you want to do, and copy the matching shortcut without leaving the current app.

## Features

- Native SwiftUI menu bar utility for macOS 13 or later
- Fast, offline search with Chinese synonyms and common spoken phrases
- macOS system shortcuts, Google Chrome, Finder, Safari, Visual Studio Code, and ChatGPT shortcuts
- App-prefixed search such as `谷歌 打开新标签页`, `访达 移动文件`, `Safari 新开标签`, or `ChatGPT 打开`
- Source filters for macOS, Google Chrome, Finder, Safari, Visual Studio Code, and ChatGPT
- Copy a readable shortcut with Return, a result-row click, or the copy button
- Local favorites and recent searches
- Compact category browsing and official source links
- Menu bar controls for the current shortcut and optional launch at login
- Does not execute shortcuts in the active app

## Install and run

Build a local release package:

```bash
./scripts/build-app.sh
open KeyFind.app
```

Builds require macOS 13 or later and the Xcode 15+ command-line toolchain. If
Xcode is installed outside the selected developer directory, set
`DEVELOPER_DIR` before running the script.

The build creates `dist/KeyFind-0.1.0-macOS.zip` and
`dist/KeyFind-0.1.0-macOS.dmg`. These local packages are ad hoc signed for
development and testing; public distribution should use a Developer ID
signature and notarization.

The package and app bundle are built for the architecture of the current Mac.
The script does not create a universal binary.

For a locally installed Developer ID certificate, pass its identity explicitly:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh
```

The repository does not automate Apple notarization. Do not publish the local
ad hoc archives as a public release.

To install the DMG, open it, drag `KeyFind.app` to Applications, then launch
it from Applications. Because the app is a menu bar utility, it does not add a
Dock icon. On first launch macOS may ask you to confirm opening an app signed
locally for development.

The app also works directly from Xcode: open the repository as a Swift package, select the `KeyFindApp` executable target, and run it on **My Mac**. It runs as a menu bar utility and does not add a Dock icon.

Default invocation shortcut: `Command-Shift-Space` (`⌘⇧ Space`). Older development builds used Option-Space; the app migrates that stored preference automatically.

Use the menu bar item to open KeyFind, enable launch at login, or quit the app. If the global shortcut cannot be registered because another app is using it, KeyFind shows a warning after launch.

## Development

Run the full test suite:

```bash
swift test
```

Build without creating an Xcode project:

```bash
swift build -c release
```

Shortcut data lives in `Sources/KeyFindCore/Resources/`:

- `shortcuts.json`: macOS system shortcuts
- `chrome-shortcuts.json`: Google Chrome shortcuts
- `finder-shortcuts.json`: Finder shortcuts
- `safari-shortcuts.json`: Safari shortcuts
- `vscode-shortcuts.json`: Visual Studio Code shortcuts
- `chatgpt-shortcuts.json`: ChatGPT macOS app shortcut

Each record has a title, description, key representation, search terms, scope, and source URL. Add or update data first, then add a focused search or catalog test.

## Privacy and permissions

KeyFind is local and offline-first:

- Search text, favorites, and recent searches stay on the Mac.
- No account, analytics, backend, or network search is required.
- The lookup flow does not require Accessibility permission.
- KeyFind only displays or copies shortcut information; it does not send shortcuts to the active app.

See [PRIVACY.md](PRIVACY.md) for details.

## Sources and content

System shortcut data is curated from [Apple's Mac keyboard shortcuts reference](https://support.apple.com/zh-cn/102650). Chrome data is based on [Google Chrome's keyboard shortcuts reference](https://support.google.com/chrome/answer/157179). Safari data is based on Apple's [Safari keyboard shortcuts guide](https://support.apple.com/zh-cn/guide/safari/cpvchf8557f4/mac). Visual Studio Code data is based on Microsoft's [macOS keyboard shortcuts reference](https://code.visualstudio.com/shortcuts/keyboard-shortcuts-macos). The ChatGPT entry is based on OpenAI's [ChatGPT macOS app help article](https://help.openai.com/en/articles/9982051-using-the-chatgpt-mac-app). The project stores concise descriptions and search terms rather than copying source page markup.

KeyFind is an independent project and is not affiliated with or endorsed by Apple, Google, Microsoft, or OpenAI. Product names and logos remain the property of their respective owners. See [NOTICE.md](NOTICE.md) for the code, data, and attribution boundary.

## Contributing

Bug reports, shortcut corrections, search aliases, and new app data are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

KeyFind is released under the [MIT License](LICENSE).

# Shortcut source status

KeyFind keeps shortcut data locally so lookup remains fast and private. Each source is reviewed against its official documentation before it is added or changed. The date below is the last manual verification for the current catalog.

| Source | Official reference | Last verified | Notes |
| --- | --- | --- | --- |
| macOS | [Apple](https://support.apple.com/zh-cn/102650) | 2026-10-09 | System shortcuts |
| Google Chrome | [Google](https://support.google.com/chrome/answer/157179) | 2026-10-09 | Browser shortcuts |
| Finder | [Apple](https://support.apple.com/zh-cn/102650) | 2026-10-09 | Finder-specific workflows are kept separate from system entries |
| Safari | [Apple](https://support.apple.com/zh-cn/guide/safari/keyboard-shortcuts-and-gestures-cpsh003/mac) | 2026-10-09 | Safari shortcuts |
| Visual Studio Code | [Microsoft](https://code.visualstudio.com/docs/configure/keybindings) | 2026-10-09 | Default macOS bindings |
| ChatGPT | [OpenAI](https://help.openai.com/en/articles/9982051-using-the-chatgpt-mac-app) | 2026-10-09 | App launch shortcut |
| Terminal | [Apple](https://support.apple.com/guide/terminal/keyboard-shortcuts-trmlshtcts/mac) | 2026-10-09 | Terminal actions |
| Xcode | [Apple Developer](https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/xcode_help-command_shortcuts/MenuCommands/MenuCommands014.html) | 2026-10-09 | Xcode menu and navigation actions |
| Figma | [Figma](https://help.figma.com/hc/en-us/articles/360040328653-Use-Figma-products-with-a-keyboard) | 2026-10-09 | Common desktop shortcuts |
| Notion | [Notion](https://www.notion.com/help/keyboard-shortcuts) | 2026-10-09 | Desktop and editor shortcuts |
| Raycast | [Raycast](https://manual.raycast.com/keyboard-shortcuts) | 2026-10-09 | Default Mac bindings; configurable shortcuts are marked in-app |

## Update policy

When an official page changes, update the matching JSON file, refresh this table, and add a focused regression test for the affected search phrase or key combination. `swift test` loads every bundled source and rejects missing fields, duplicate IDs, invalid source URLs, cross-source bundle IDs, and duplicate aliases.

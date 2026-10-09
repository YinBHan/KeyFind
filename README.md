# KeyFind

> Offline keyboard shortcut finder for macOS. Search by intent in Chinese or English, use pinyin initials, see app-specific shortcuts, and copy the result without leaving your current app.

KeyFind 是一个常驻 macOS 菜单栏的快捷键速查工具。按下 `Command-Shift-Space`，输入你想做的事情，例如“Mac 截图”“移动文件”“谷歌打开新标签页”，就能立即找到对应快捷键和使用说明。

KeyFind is a small macOS menu bar utility with a SwiftUI search panel for looking up keyboard shortcuts by meaning. Press `Command-Shift-Space`, type what you want to do, and copy the matching shortcut without leaving the current app.

如果你正在寻找 Mac 快捷键查询、macOS 快捷键搜索、苹果电脑快捷键、访达快捷键、Chrome 快捷键、Terminal 快捷键、Xcode 快捷键、Figma 快捷键、Notion 快捷键或 Raycast 快捷键，KeyFind 提供一个离线的中文搜索入口；支持中文同义词、拼音全拼、拼音首字母、英文关键词和应用名前缀搜索。

KeyFind is a native macOS menu bar app for finding keyboard shortcuts by meaning. It is an offline shortcut reference and learning tool, not a keyboard remapper, clipboard manager, file search tool, or window manager. Search stays on your Mac, the app does not require Accessibility permission for lookup, and it never sends shortcuts to the active app.

## What makes KeyFind useful

- **Search by what you want to do**: type `截图`, `jtb`, `移动文件`, `Chrome 恢复标签`, or `Xcode 编译` instead of memorizing exact menu names.
- **Chinese-first and bilingual**: Chinese synonyms, pinyin initials/full spelling, English terms, and common spoken phrases work together.
- **App-aware results**: when Chrome, Safari, Finder, VS Code, ChatGPT, Terminal, Xcode, or Figma is in front, matching shortcuts from that app are ranked first.
- **Offline and low-permission**: the catalog and search index are bundled locally; the lookup flow does not need Accessibility, Input Monitoring, an account, or a backend.
- **Actionable answers**: results show readable keys, symbol keys, source links, and multi-step workflows such as moving a Finder file.

### Search examples

| You type | KeyFind helps you find |
| --- | --- |
| `jtb` or `剪贴板` | clipboard-related shortcuts and copy workflows |
| `截图` or `pingmujietu` | macOS screenshot shortcuts |
| `访达 移动文件` | Finder's cut-and-move sequence |
| `Chrome 恢复关闭的标签` | Chrome's reopen-tab shortcut |
| `终端 清屏` | Terminal's clear-screen shortcut |
| `Xcode 编译` | Xcode's Build shortcut |
| `Figma 复制样式` | Figma's copy-properties shortcut |
| `Notion 搜索页面` | Notion's workspace search shortcut |
| `Raycast 打开设置` | Raycast's settings shortcut |

## 快速搜索示例

- `Mac 截图`、`复制`、`撤销`：查询 macOS 系统快捷键
- `访达 移动文件`、`Finder 新建文件夹`：查询 Finder 操作和组合键
- `谷歌 打开新标签页`、`Chrome 恢复关闭的标签`：查询 Google Chrome 快捷键
- `Safari 新开标签`、`VS Code 格式化代码`、`ChatGPT 打开`：查询其他已收录应用

## Features

- Native SwiftUI menu bar utility for macOS 13 or later
- Fast, offline search with Chinese synonyms and common spoken phrases
- macOS system shortcuts, Google Chrome, Finder, Safari, Visual Studio Code, and ChatGPT shortcuts
- Terminal, Xcode, Figma, Notion, and Raycast sources with official reference links
- App-prefixed search such as `谷歌 打开新标签页`, `访达 移动文件`, `Safari 新开标签`, or `ChatGPT 打开`
- Source filters for every bundled catalog, including macOS, browsers, developer tools, design tools, Notion, and Raycast
- Copy a readable shortcut with Return, a result-row click, or the copy button
- Local favorites and recent searches
- Compact category browsing and official source links
- Menu bar controls for the current shortcut and optional launch at login
- Does not execute shortcuts in the active app

## Install and run

Build a local release package:

```bash
./scripts/build-app.sh
open .build/distribution/KeyFind.app
```

Builds require macOS 13 or later and the Xcode 15+ command-line toolchain. If
Xcode is installed outside the selected developer directory, set
`DEVELOPER_DIR` before running the script.

The build creates `.build/distribution/dist/KeyFind-0.2.0-macOS.zip` and
`.build/distribution/dist/KeyFind-0.2.0-macOS.dmg`. These local packages are ad hoc signed for
development and testing; public distribution should use a Developer ID
signature and notarization.

The build refuses to overwrite an existing app or archive. To rebuild, choose a
new output directory with `KEYFIND_BUILD_OUTPUT_DIR=/path/to/output`.

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
- `terminal-shortcuts.json`: Apple Terminal shortcuts
- `xcode-shortcuts.json`: Xcode menu and development shortcuts
- `figma-shortcuts.json`: Figma design shortcuts
- `notion-shortcuts.json`: Notion workspace and editor shortcuts
- `raycast-shortcuts.json`: Raycast launcher shortcuts

Each record has a title, description, key representation, search terms, scope, and source URL. Add or update data first, then add a focused search or catalog test.

## Privacy and permissions

KeyFind is local and offline-first:

- Search text, favorites, and recent searches stay on the Mac.
- No account, analytics, backend, or network search is required.
- The lookup flow does not require Accessibility permission.
- KeyFind only displays or copies shortcut information; it does not send shortcuts to the active app.

See [PRIVACY.md](PRIVACY.md) for details.

## Sources and content

System shortcut data is curated from [Apple's Mac keyboard shortcuts reference](https://support.apple.com/zh-cn/102650). Chrome data is based on [Google Chrome's keyboard shortcuts reference](https://support.google.com/chrome/answer/157179). Safari data is based on Apple's [Safari keyboard shortcuts guide](https://support.apple.com/zh-cn/guide/safari/keyboard-shortcuts-and-gestures-cpsh003/mac). Visual Studio Code data is based on Microsoft's [keyboard shortcuts documentation](https://code.visualstudio.com/docs/configure/keybindings). The ChatGPT entry is based on OpenAI's [ChatGPT macOS app help article](https://help.openai.com/en/articles/9982051-using-the-chatgpt-mac-app). Notion data is based on [Notion's keyboard shortcuts guide](https://www.notion.com/help/keyboard-shortcuts), and Raycast data is based on [Raycast's keyboard shortcuts manual](https://manual.raycast.com/keyboard-shortcuts). The project stores concise descriptions and search terms rather than copying source page markup.

KeyFind is an independent project and is not affiliated with or endorsed by Apple, Google, Microsoft, OpenAI, Notion, Raycast, or any other product listed here. Product names and logos remain the property of their respective owners. See [NOTICE.md](NOTICE.md) for the code, data, and attribution boundary. See [docs/source-status.md](docs/source-status.md) for source verification dates and update policy.

## Contributing

Bug reports, shortcut corrections, search aliases, and new app data are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

KeyFind is released under the [MIT License](LICENSE).

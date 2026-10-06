# 新增快捷键来源模板

新增一个软件时，保持搜索核心不变，只需要完成以下三步：

## 1. 增加数据资源

在 `Sources/KeyFindCore/Resources/` 新增 `<source>-shortcuts.json`。

每条记录使用现有 `Shortcut` JSON 结构，并满足：

- `scope` 必须是 `app`。
- `appIdentifier` 必须和来源 descriptor 的 Bundle ID 完全一致。
- `id` 在该文件内唯一，并且不能和其他资源重复。
- `title`、`description`、`searchTerms` 必须是面向用户的中文内容。
- 复杂操作使用 `steps` 写清楚操作顺序。
- `sourceURL` 指向官方快捷键文档。

示例：

```json
{
  "id": "example-new-window",
  "title": "新建窗口",
  "description": "打开一个新的应用窗口。",
  "category": "常用操作",
  "keys": {
    "modifiers": ["⌘"],
    "key": "N",
    "symbolText": "⌘ N",
    "readableText": "⌘ Command + N"
  },
  "searchTerms": ["新窗口", "创建窗口"],
  "scope": "app",
  "appIdentifier": "com.example.App",
  "sourceURL": "https://example.com/shortcuts",
  "caution": null,
  "steps": null
}
```

## 2. 添加来源 descriptor

在 `ShortcutSourceRegistry` 的 `defaultDescriptors` 中添加一条配置（新增来源应通过同一处默认注册表维护）：

```swift
ShortcutSourceDescriptor(
    app: .example,
    displayName: "示例应用",
    bundleIdentifier: "com.example.App",
    searchAliases: ["示例", "Example"],
    sourceURL: URL(string: "https://example.com/shortcuts")!,
    resourceName: "example-shortcuts"
)
```

别名会自动支持：

- 直接搜索应用名，立即展示该应用的快捷键。
- 使用“应用名 + 操作”进行限定搜索。
- 来源筛选中的应用 chip。

别名必须唯一，不能是空字符串；显示名称、Bundle ID 和资源名也不能为空。注册表校验失败时，目录加载会返回明确错误。

## 3. 扩展应用身份枚举

在 `ShortcutApp` 中增加新的 case，并提供其 `bundleIdentifier`。兼容性的 `load(_:)` API、来源筛选和收藏功能会继续复用同一身份。

当前已接入的来源包括 macOS、Google Chrome、访达、Safari、Visual Studio Code 和 ChatGPT。

## 验证命令

```bash
swift test
./scripts/build-app.sh
```

提交前还要确认新应用的：

- 官方来源链接可访问。
- 应用名、常用中文叫法和英文名都能搜到。
- 只输入应用名时能立即展示建议。
- 输入“应用名 + 操作”时不会混入其他应用结果。
- 复杂快捷键的步骤说明完整。

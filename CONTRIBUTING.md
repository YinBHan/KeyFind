# Contributing

## Before you start

KeyFind is intentionally small and offline-first. Keep changes focused on fast lookup, accurate shortcut data, and a compact native interface.

## Adding or correcting shortcut data

1. Edit the appropriate JSON file in `Sources/KeyFindCore/Resources/`.
2. Keep IDs stable and unique.
3. Include a concise description, useful Chinese and English search terms where appropriate, pinyin-friendly Chinese titles or aliases, readable key symbols, and an official source URL.
4. Add a focused test for a new alias or important workflow.

The current source list and last verification dates are tracked in
[docs/source-status.md](docs/source-status.md). Do not add an app shortcut from
memory alone: link the official documentation and mark configurable defaults in
the record's `caution` field.

### Field guidelines

- **`id`**: Use a unique, stable identifier such as `copy` or `chrome-new-tab`. Do not change it after release.
- **`title`**: Keep the action name short and readable, for example `复制` or `打开新标签页`.
- **`description`**: Explain the result of the shortcut in one concise sentence.
- **`searchTerms`**: Include useful Chinese and English names, synonyms, and phrases people may search for.
- **`steps`** (optional): Use an ordered list when a shortcut needs a multi-stage workflow, a prerequisite, or extra context. Keep each item short.

  ```json
  "steps": [
    "选中要移动的文件",
    "按 ⌘X 剪切",
    "进入目标文件夹",
    "按 ⌥⌘V 移动到这里"
  ]
  ```

- **`caution`** (optional): Explain a configurable default, a condition the user must meet, or a meaningful side effect. The app highlights this text in the shortcut row, so keep it specific and concise.

  ```json
  "caution": "此快捷键可在应用设置中自定义。"
  ```

Use `caution` for destructive actions, system-level actions, configurable shortcuts,
or behavior that depends on the current app or selection. Use `steps` when the
user benefits from seeing a sequence. A record may include both fields when it
needs a warning as well as instructions.

## Local verification

```bash
swift test
./scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 KeyFind.app
```

`./scripts/build-app.sh` also creates local release archives in the configured
build output directory (by default `.build/distribution/dist/`).
Those archives are ignored by Git and are not notarized.
The script refuses to overwrite an existing app or archive; use a new
`KEYFIND_BUILD_OUTPUT_DIR` when rebuilding.

Please do not commit `.build/`, `KeyFind.app/`, `dist/`, `.swiftpm/`, `.DS_Store`, local archives, or local logs.

## Pull requests

Describe the user problem, the data or UI change, and the verification you ran. For shortcut corrections, include the official source URL and explain the affected search phrase. GitHub issue templates are available for bug reports, shortcut corrections, and feature requests.

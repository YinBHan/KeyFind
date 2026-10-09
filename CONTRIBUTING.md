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

# Contributing

## Before you start

KeyFind is intentionally small and offline-first. Keep changes focused on fast lookup, accurate shortcut data, and a compact native interface.

## Adding or correcting shortcut data

1. Edit the appropriate JSON file in `Sources/KeyFindCore/Resources/`.
2. Keep IDs stable and unique.
3. Include a concise description, useful Chinese and English search terms where appropriate, readable key symbols, and an official source URL.
4. Add a focused test for a new alias or important workflow.

## Local verification

```bash
swift test
./scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 KeyFind.app
```

`./scripts/build-app.sh` also creates local release archives in `dist/`.
Those archives are ignored by Git and are not notarized.

Please do not commit `.build/`, `KeyFind.app/`, `dist/`, `.swiftpm/`, `.DS_Store`, local archives, or local logs.

## Pull requests

Describe the user problem, the data or UI change, and the verification you ran. For shortcut corrections, include the official source URL and explain the affected search phrase.

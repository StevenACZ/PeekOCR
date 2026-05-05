# PeekOCR

PeekOCR is a native macOS menu bar app for fast OCR, QR detection,
screenshots, live annotation capture, GIF clip recording, and MP4/GIF export.

## Requirements

- macOS 13.0 or later
- Apple Silicon Mac (`arm64`, M1 and newer)
- Xcode with command line tools
- Screen Recording permission for capture
- Accessibility permission for global hotkeys

## Features

- OCR region capture with clipboard output.
- QR content detection and copy.
- Screenshot capture with configurable format, quality, scale, and save
  location.
- Live annotated screenshot flow with region adjustment, arrows, text,
  highlights, move/resize, and undo before export.
- GIF clip recording up to 10 seconds, with trim preview and GIF/MP4 export.
- Guided permission setup through the menu bar reminder, settings rows, and
  missing-permissions window.
- Optional capture sound for successful screenshot/frame saves.
- Recent capture history from the menu bar.

## Quick Start

```bash
git clone <repo-url>
cd PeekOCR
make tools
make ci-check
```

Open `PeekOCR.xcodeproj` in Xcode and run the `PeekOCR` scheme.

## Daily Workflow

```bash
make format
make lint
make build
```

- `make format` formats changed Swift files with Xcode's bundled
  `swift-format`.
- `make lint` checks changed Swift files without editing them.
- `make ci-check` runs `lint + Debug build`.
- `make release-check` runs `lint + Release build + size check`.
- `make format-all` and `make lint-all` are explicit full-repo passes; use them
  only for a planned formatting migration.

Optional hooks:

```bash
make hooks-install
```

## Default Shortcuts

| Action | Shortcut |
|---|---|
| OCR capture | `⇧ Space` |
| Screenshot | `⌘⇧4` |
| Annotated screenshot | `⌘⇧5` |
| GIF clip | `⌘⇧6` |

All shortcuts can be changed in Settings.

## Permissions

PeekOCR does not trigger permission prompts automatically at launch. If Screen
Recording or Accessibility is missing, the app surfaces explicit activation UI
from settings, the menu bar reminder, or a blocked capture attempt.

Screen Recording may lag after being enabled in System Settings depending on
macOS behavior. Reopen the app or retry the capture flow if macOS has not
refreshed the permission yet.

## Release Size

Release builds target Apple Silicon only. Measure a built app with:

```bash
make release
make size-check
```

The current Release bundle is expected to contain only:

- `Contents/MacOS/PeekOCR`
- `Contents/Resources/Assets.car`
- `Contents/Resources/capture-shutter.m4a`
- `Contents/Resources/ATTRIBUTIONS.md`
- standard bundle metadata and code signature files

## Public Repo Safety

Tracked and expected to be public:

- Source code, app assets required at runtime, resources, entitlements, Xcode
  project metadata, Makefile, formatting config, hook config, README,
  changelog, contributing notes, security notes, and license.

Ignored and intentionally private/local:

- `AGENTS.md`, `CLAUDE.md`, `docs/`, `.codex/`, Xcode user data, build
  products, logs, crash reports, credentials, `.env*`, screenshots, recordings,
  DMGs, archives, and local signing files.

Before opening a PR, run:

```bash
make ci-check
git diff --check
```

## Tests

The `PeekOCR` scheme currently has no configured test action. Use
`make ci-check` as the current local gate.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

MIT

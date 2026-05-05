# Contributing

Thanks for helping improve PeekOCR.

## Setup

```bash
make tools
make ci-check
```

Open `PeekOCR.xcodeproj` in Xcode and run the `PeekOCR` scheme.

## Workflow

```bash
make format
make lint
make build
```

- Keep changes focused and small.
- Do not commit credentials, screenshots, logs, crash reports, DMGs, archives,
  local docs, local agent notes, or signing files.
- Keep Release output Apple Silicon only unless Intel support is explicitly
  re-approved.
- Use `make release-check` before release-size or packaging changes.
- The project does not have a test target yet; `make ci-check` is the current
  PR gate.

## Pull Requests

Before opening a PR:

```bash
make ci-check
git diff --check
```

Include:

- What changed.
- How it was verified.
- Any permission, signing, release-size, or privacy impact.

## Signing

The tracked project is configured for local contributor builds. Maintainers
configure Apple Development, Developer ID, notarization, and release packaging
outside the public repo when preparing release artifacts.

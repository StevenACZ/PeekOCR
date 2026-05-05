# Security

## Secret Handling

Do not commit:

- API keys, tokens, or `.env*` files
- Local screenshots, recordings, logs, crash reports, archives, or DMGs
- Signing certificates, provisioning profiles, notarization files, or private
  Xcode configuration
- Personal Apple Developer Team IDs, local Xcode user data, or machine-specific
  paths
- Private agent notes such as `AGENTS.md`, `CLAUDE.md`, `.codex/`, or local
  `docs/`

PeekOCR performs screen capture locally on the user's Mac. Captured content,
history, and permission state should not be added to source control.

## Reporting

For security-sensitive issues, do not include private screenshots, recordings,
or local identifiers in public issues. Open a minimal report describing the
affected area and share sensitive details only through a private
maintainer-approved channel.

## Public Repo Boundary

The public repo should contain source code, app assets needed at runtime, shared
Xcode metadata, build scripts, formatting config, README, changelog,
contributing notes, security notes, and license. Local maintainer notes and
release artifacts stay ignored unless they are scrubbed and intentionally
published.

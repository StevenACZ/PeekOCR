# Changelog

All notable changes are grouped from the real project history. Public notes stay
compact and avoid local machine, signing, or private environment details.

## Unreleased

## 1.8.2 - Apple Silicon Release Trim - 2026-05-05

Focused on Apple Silicon release size, code organization, and export diagnostics.

- Made macOS builds Apple Silicon only (`arm64`, M1 or newer) and updated public
  requirements accordingly.
- Measured the Release app at 10.0M -> 6.2M (38.0% smaller), the main binary
  at 7.3M -> 3.6M (50.4% smaller), and bundled resources at 2.7M -> 2.6M
  (4.9% smaller).
- Removed the duplicate standalone `AppIcon.icns` from the final app bundle by
  relying on the asset catalog icon in `Assets.car`.
- Split the live annotation overlay into focused mouse, drawing, text,
  hit-testing, geometry, and cursor files.
- Split GIF clip sidebar estimate formatting helpers out of the sidebar view.
- Added lightweight GIF/MP4 export completion logs with frame counts, skipped
  frames, FPS, output bytes, render size, and elapsed time.
- Cleaned repo hygiene around private/local agent files and Xcode user data.
- Added a Makefile-first developer workflow with Xcode `swift-format`,
  `make format`, `make lint`, `make ci-check`, `make release-check`, and
  optional Lefthook hooks.
- Added compact public `CONTRIBUTING.md` and `SECURITY.md` files and refreshed
  the README around public build, verification, and repo safety boundaries.

## 1.8.1 - Light Mode Permission Polish - 2026-04-24

- Fixed Light Mode contrast for permission guidance surfaces, including the
  floating System Settings assistant, requirements window, menu reminder,
  draggable app card, and settings permission rows.
- Added shared permission appearance helpers for dynamic AppKit color resolution.

## 1.8.0 - Guided Permission Onboarding - 2026-04-19

- Added explicit, user-driven Screen Recording and Accessibility onboarding from
  settings, the menu bar reminder, and blocked capture attempts.
- Added the missing-permissions window with stable layout, live status cards,
  green granted states, and guided System Settings activation.
- Removed startup permission interruption and routed blocked captures through
  the onboarding flow.
- Split permission requirements UI into smaller views and refreshed docs around
  the new flow.

## 1.7.0 - Multi-Display Capture And Clip Editor Polish - 2026-04-18

- Added multi-display overlays for annotated screenshot and GIF clip selection.
- Added optional capture shutter sound with persistent toggle and volume.
- Refined the GIF/Video clip editor sidebar, timeline trim styling, preview
  surface, playback symbols, export controls, and saved-frame feedback.
- Fixed secondary-display overlay placement by using global screen coordinates
  and one window per active non-mirrored display.
- Added `DisplayEnumerator`, `CaptureSoundService`, and `SoundSettings`.

## 1.6.0 - Live Annotation And Runtime Performance - 2026-04-11

- Replaced post-capture annotation with a live pre-capture overlay for region
  selection, move/resize, arrows, text, highlights, and undo.
- Added direct region capture for annotated screenshots and synced overlay
  defaults with annotation settings.
- Moved OCR, screenshot processing, image encoding, history persistence, and
  GIF playback work away from the UI-critical path where possible.
- Switched image save/decode work toward ImageIO and memory-mapped reads to
  reduce transient memory pressure.
- Fixed shortcut monitor cleanup, duplicate hotkey handler installation,
  settings permission polling, partial export cleanup, and overlay edge cases.

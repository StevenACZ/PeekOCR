# Changelog

All notable changes to this project will be documented in this file.

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- New About window with app icon, copyable version and build, feature chips,
  and GitHub links, opened from the menu bar panel.
- `make install-dev` / `scripts/install_dev.sh` for fast local reinstalls of the signed Release app without resetting macOS permission grants.

### Changed

- Redesigned the menu bar panel: status header with live subtitle and OCR
  shortcut badge, restyled capture history (latest 4 entries, color-coded by
  type, copy feedback), and clearer Settings, About, and Quit rows. Capture
  actions now run through hotkeys only.
- Rebuilt Settings as its own window with a segmented toolbar and four tabs:
  General now hosts permissions and full history management side by side,
  Shortcuts is a visual 2x2 grid of capture modes with inline key recording,
  and Captures and Clips were rebalanced into two-column card layouts.
- The permissions card collapses into a compact "all permissions active"
  summary once everything is granted, expandable back to the detailed rows.
- Save-location picker entries now have proper spacing between icon and
  title.
- Standardized the changelog and public agent handoff docs around the shared
  Swift project workflow.

### Removed

- The duplicated capture-shortcuts card in the Captures tab and the capture
  action buttons in the menu bar panel; shortcuts live in the Shortcuts tab.

## [1.9.2] - 2026-06-26

### Fixed

- Fixed the clip editor so unlimited recordings show and export their full
  recorded length instead of clamping to the configured duration limit.

## [1.9.1] - 2026-06-23

### Fixed

- Fixed capture overlays so OCR, screenshots, annotations, and clip region
  selection preserve transient UI such as menus, popovers, and hover states
  without activating PeekOCR.
- Video editor frame snapshots now reuse screenshot settings, including
  clipboard copy, file saving, format, quality, scale, and save location.

## [1.9.0] - 2026-06-12

### Added

- Screen recording rebuilt on ScreenCaptureKit: recordings start the instant
  the region is picked, stop cleanly, capture at full Retina resolution, and
  no longer rely on the screencapture helper process.
- Clip region selection uses the same dimmed quick-select overlay as
  screenshots; pressing Space records the full screen under the cursor.
- Pause and resume while recording: segments are joined seamlessly on stop
  without re-encoding. The HUD gains pause/stop controls, a quality readout
  (resolution, FPS, format, audio), and sits bottom-center when recording the
  full screen.
- The duration limit is now optional: cap clips between 3-60 seconds or
  record without a limit until stopped, with a count-up timer.
- New recording options: capture FPS (15/30/60), cursor visibility, and
  optional system audio that is kept in the exported MP4.
- Video export FPS is selectable (24/30/60) and GIF export now reaches 30 FPS.
- The app's own windows (recording frame, HUD) never appear in recordings.
- OCR and screenshot hotkeys now use the app's own dimmed overlay instead of
  the native picker: the screen dims the instant the hotkey fires, a live
  W x H badge tracks the drag, and releasing the mouse captures immediately
  with the same flash and sound feedback as annotated captures.
- Thumbnail-style annotation text: white system-rounded heavy lettering with
  a thick black outline, readable on any background and identical in the
  editor, the live overlay, and the final image.
- Multi-line text editing: Enter inserts a new line, Cmd+Enter commits, Esc
  cancels; standard editing keys (undo, copy, paste, select all) work inside
  the editor without touching annotation history.
- Every selected annotation is now resizable by its handles: text corners
  scale the font tracking the cursor, arrows expose endpoint grips, pen
  strokes and highlights scale their whole shape.
- New freehand pen tool with its own configurable default stroke width.
- Tool shortcuts moved to the home row in toolbar order: A select, S arrow,
  D text, F highlight, G pen.
- Esc now cancels the capture directly (or just the text editor when one is
  open).
- Annotated capture overlay now appears instantly when the hotkey fires (no
  first-click needed), with a quick fade-in, a clearer initial dim, and an
  immediate crosshair cursor.
- Reliable annotation editing: transactional undo (no-op clicks no longer eat
  ⌘Z), new redo (⇧⌘Z), and Delete/forward-delete removes the selected
  annotation; Esc deselects before cancelling.
- Region capture moved to ScreenCaptureKit: no helper process or temp file,
  the app's own windows are excluded from the capture, and the old 120ms
  settle delay is gone. A brief flash confirms the capture.
- OCR migrated to the modern Swift Vision API with QR and text detection
  running in parallel and automatic language detection.
- Selectable capture sounds (bundled shutter or system sounds), optional OCR
  copy confirmation sound, and zero-latency audio preloading.
- Modern menu bar popover: rounded hover states, icon bounce effects, spring
  history transitions, and a translucent material background.
- Annotation toolbar buttons now draw SF Symbol icons with their shortcut.
- Layered xcconfig signing: public builds sign ad-hoc out of the box; a
  git-ignored local override keeps a stable identity. The team ID no longer
  lives in the project file.
- Raised the minimum system requirement to macOS 15.

## [1.8.3] - 2026-05-29

### Added

- Distribution-only patch: the macOS DMG is built with Developer ID signing,
  secure timestamping, notarization, and stapling. No app behavior changed.

## [1.8.2] - 2026-05-05
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

## [1.8.1] - 2026-04-24

### Fixed

- Fixed Light Mode contrast for permission guidance surfaces, including the
  floating System Settings assistant, requirements window, menu reminder,
  draggable app card, and settings permission rows.
- Added shared permission appearance helpers for dynamic AppKit color resolution.

## [1.8.0] - 2026-04-19

### Added

- Added explicit, user-driven Screen Recording and Accessibility onboarding from
  settings, the menu bar reminder, and blocked capture attempts.
- Added the missing-permissions window with stable layout, live status cards,
  green granted states, and guided System Settings activation.
- Removed startup permission interruption and routed blocked captures through
  the onboarding flow.
- Split permission requirements UI into smaller views and refreshed docs around
  the new flow.

## [1.7.0] - 2026-04-18

### Added

- Added multi-display overlays for annotated screenshot and GIF clip selection.
- Added optional capture shutter sound with persistent toggle and volume.
- Refined the GIF/Video clip editor sidebar, timeline trim styling, preview
  surface, playback symbols, export controls, and saved-frame feedback.
- Fixed secondary-display overlay placement by using global screen coordinates
  and one window per active non-mirrored display.
- Added `DisplayEnumerator`, `CaptureSoundService`, and `SoundSettings`.

## [1.6.0] - 2026-04-11

### Added

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

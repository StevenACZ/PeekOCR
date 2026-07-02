# PeekOCR Agent Guide

This file is public project guidance for contributors and coding agents. Keep
machine-specific notes, personal workflows, signing material, and release-only
local details in ignored local files such as `AGENTS.local.md`.

## Project Basics

- PeekOCR is a macOS menu bar app for OCR, screenshots, annotations, and short
  screen recordings.
- Deployment target: macOS 15, Apple Silicon only. Swift 5 mode.
- The Xcode project uses file-system synchronized groups. Creating, moving, or
  deleting source files on disk is enough; do not edit `project.pbxproj` just
  for file membership.
- Keep code, commits, changelogs, and durable technical docs in English.

## Build And Verification

- Use the Makefile for the standard local gate:

```bash
make ci-check
```

- `make ci-check` runs lint plus a Debug build.
- The project does not have a unit test target yet; there is no `make test` gate.
- When diagnosing runtime behavior, prefer Console/log evidence from the app
  subsystem:

```bash
/usr/bin/log stream --style compact --level debug --predicate 'subsystem == "com.peekocr"'
```

- Crash reports are written by macOS under
  `~/Library/Logs/DiagnosticReports/PeekOCR-*.ips`.

## Local Iteration

- Use `make install-dev` for routine local app testing on Steven's Mac.
- It builds a Release app, verifies Apple Development signing, reinstalls to
  `/Applications/PeekOCR.app`, and relaunches the app.
- Keep the app name and bundle id unchanged so macOS can preserve Screen
  Recording and Accessibility grants across rebuilds.
- Use `make notarized-dmg` only for final distribution packaging.

## Signing And Local Configuration

- The tracked signing defaults are intentionally safe for public development.
- Keep private signing overrides in ignored local xcconfig files.
- Never commit certificates, provisioning profiles, team identifiers,
  environment files, or release authentication material.
- Release packaging scripts may pass explicit signing overrides; keep local
  development defaults separate from release authentication.

## Architecture Snapshot

### Menu Bar UI

`MenuBarStatusController` owns the status item, the transient auto-sized
`NSPopover` panel (`MenuBarPanelHost` → `MenuBarPopoverView`), and the
hand-built Settings and About windows (SwiftUI content is rebuilt on show and
dropped on `windowWillClose`). The panel exposes no capture actions on
purpose — captures run through hotkeys; the panel offers history, Settings,
About, and Quit. Settings is a custom window (unified toolbar with segmented
tabs + `SettingsCard` two-column layout), not a SwiftUI `Settings` scene.
Shared design tokens live in `Theme.swift`.

### Region Picking

All captures share one overlay:
`LiveAnnotationOverlayView` plus its focused extensions, presented by
`LiveAnnotationOverlayWindowController`.

- `.annotate`: adjustable selection with annotation tools and Enter to
  capture.
- `.quickSelect`: drag to capture immediately on mouse-up. Space selects the
  full screen under the cursor.

Still pixels come from `NativeScreenCaptureService.captureRegion` through
`SCScreenshotManager`, excluding PeekOCR windows where possible. The
`screencapture` command remains only as a screenshot fallback.
`CaptureFlashEffect` plays after pixels are captured.

### Annotations

`LiveAnnotationRenderer.drawThumbnailText` renders text in two passes: a thick
rounded contour and then fill. The floating editor uses AppKit text editing and
only approximates that final rendered look with fill plus a strong shadow.

Multi-line text behavior:

- Enter inserts a newline.
- Command-Enter commits.
- Escape cancels.
- Text anchors at its top-left `startPoint` and is measured with
  `LiveAnnotation.textSize`.

Undo is transactional for drags through `beginAnnotationTransaction` and
`commitAnnotationTransaction`; no-op drags should not create undo steps. Atomic
operations use `pushUndoSnapshot`, which clears redo.

Resize handles are tool-specific through `AnnotationHandle`: arrows expose
endpoint grips, text corners scale the font by cursor-to-anchor diagonal
distance, and pen/highlight annotations scale their rect.

### Video Clips

Clip recording lives under `Services/Recording/`.
`ClipRecordingController` orchestrates quick-select picking, the recording
frame, HUD, and `ScreenRecordingEngine`. The engine records to temporary
`.mov` files with ScreenCaptureKit and `SCRecordingOutput`.

Important capture exclusion ordering:

- Fetch `SCShareableContent` inside `ScreenRecordingEngine.start()`, after the
  recording frame and HUD are visible.
- Exclude by application first, with an excluding-windows fallback.
- Keep the recording outline outside the captured rect as a second layer of
  protection.

Pause/resume swaps `SCRecordingOutput` instances on the live stream. Each
resume creates a new segment; stop either moves the single segment or
concatenates multiple segments with `AVMutableComposition` and passthrough
export.

`record(maxDurationSeconds:)` accepts `nil` for unlimited recording. The HUD
counts up for unlimited recordings and shows pause/stop state plus a quality
readout based on the selected rect and backing scale.

System audio uses `capturesAudio` and `excludesCurrentProcessAudio`. If audio
permission or platform behavior prevents stream startup, retry once without
audio.

`GifClipSettings` stores recording and export defaults in `UserDefaults`,
including duration-limit state, recording FPS, cursor visibility, audio
capture, MP4 FPS, GIF FPS, format, profile, resolution, and codec defaults.
Shared option lists live in `Constants.Gif`.

### Clip Editor And Exports

The editor flow receives the temporary `.mov` and supports trim, GIF/MP4
export, frame capture, and re-record. `VideoExportService` carries recorded
audio into MP4 exports with a composition audio track and AAC re-encode.

ScreenCaptureKit recordings can be variable frame rate and may report
misleading nominal or estimated FPS for static content. When source FPS
estimation fails, trust the requested export FPS and let the constant-frame-rate
composition fill gaps.

### OCR And Sounds

`OCRService` uses Swift Vision text and barcode requests in parallel. Capture
sounds are managed by `CaptureSoundService` and prewarmed at launch. System
sounds should play on copied `NSSound` instances so rapid retriggering does not
clip.

## Known Legacy Code

The older post-capture editor and some legacy capture helpers still exist for
compatibility. Do not remove them unless the task explicitly asks for that
cleanup.

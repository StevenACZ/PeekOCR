# CLAUDE.md

## Project

PeekOCR is a native macOS menu bar app for OCR text capture, screenshots, annotations, GIF clips, and short video exports.

Repository:
- public PeekOCR macOS app repo

Main app target:
- `PeekOCR.xcodeproj`
- scheme: `PeekOCR`

## Build

```bash
xcodebuild -project PeekOCR.xcodeproj -scheme PeekOCR -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## Current engineering priorities

1. Keep capture interactions responsive.
2. Avoid unnecessary main-thread image processing.
3. Optimize for long-lived resident execution on macOS.
4. Minimize transient image/video memory spikes.
5. Preserve current UX while improving structure and internals, except when a capture mode intentionally upgrades to a lower-friction overlay flow.

## Runtime conventions

- This is a public repo: never commit local absolute paths, machine-specific secrets, or private environment details.
- Heavy OCR, scaling, encoding, and file I/O should stay off the UI-critical path whenever possible.
- Prefer ImageIO/CoreGraphics over AppKit wrappers for background-safe image encoding/decoding.
- Treat menu bar and settings views as long-lived surfaces: avoid polling timers and leaked monitors.
- If a view consumes a singleton created elsewhere, prefer `@ObservedObject` instead of `@StateObject`.
- If adding long-running observers/monitors/timers, always define teardown on cancel/disappear/deinit.

## Files worth checking first

- `PeekOCR/Services/CaptureCoordinator.swift`
- `PeekOCR/Services/LiveAnnotationOverlayWindowController.swift`
- `PeekOCR/Services/LiveAnnotationRenderer.swift`
- `PeekOCR/Services/GifRecordingOverlayWindowController.swift`
- `PeekOCR/Views/Annotation/Overlay/LiveAnnotationOverlayView.swift`
- `PeekOCR/Services/OCRService.swift`
- `PeekOCR/Services/ScreenshotService.swift`
- `PeekOCR/Services/GifExportService.swift`
- `PeekOCR/Services/VideoExportService.swift`
- `PeekOCR/Services/DisplayEnumerator.swift`
- `PeekOCR/Services/CaptureSoundService.swift`
- `PeekOCR/Models/SoundSettings.swift`
- `PeekOCR/Models/State/GifClipEditorState.swift`
- `PeekOCR/Views/Components/ShortcutRecorderRow.swift`
- `PeekOCR/Views/Components/PermissionStatusRow.swift`
- `PeekOCR/Managers/HistoryManager.swift`

## Multi-display and windowing notes

- Capture overlays (`LiveAnnotationOverlayWindowController`, `GifRecordingOverlayWindowController`) spawn one borderless window per active non-mirrored display via `DisplayEnumerator.activeScreens()`. The first mousedown claims the session and dismisses sibling overlays.
- Do NOT pass a non-nil `screen:` argument to `NSWindow(contentRect:styleMask:backing:defer:screen:)` when `contentRect` already holds a global-coordinate frame — AppKit treats the contentRect origin as screen-relative and doubles it on non-primary displays. Use the 4-parameter init and call `setFrame(screen.frame, display: false)` right after construction.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+). Files added anywhere under `PeekOCR/` are auto-discovered; editing `project.pbxproj` to register new sources or resources is neither necessary nor possible with legacy tooling.

## Clip editor UI (`GifClipEditorView`)

- Sidebar is a flat header + a stack of card sections. The `GIF ↔ Video` segmented picker lives inline in the header, not as its own section. Cards (`CALIDAD`, `SALIDA`, `ESTIMACIÓN`) share a single surface style built with `cardSection(title:content:)` inside `GifClipSidebarView` — reuse that helper when adding a new section instead of rolling a new background.
- `FPS` for video exports is a read-only row inside the Calidad card (not a picker). The contextual low-source-FPS notice (`InlineNoticeView`) appears below it when the source clip is under ~29 FPS.
- Timeline uses `Color.accentColor` for the trim selection and a discrete tick-mark row per second; do not re-introduce the yellow highlight. The playhead is a white capsule with a round dot above the track.
- The video preview container is a solid black rounded rectangle with a subtle radial vignette. Avoid hardcoded gradients — they fight real captured content.
- Playback controls live on an `.ultraThinMaterial` pill over the video. Use SF Symbols `backward.frame.fill` / `forward.frame.fill` for frame stepping; do not fall back to generic chevrons.
- The bottom-bar export button has `.keyboardShortcut(.defaultAction)` so Enter exports. Keep Cancelar bound to `.cancelAction`.
- `GifClipActionFeedbackView` has two layouts: a compact chip (used inline in the bottom bar for frame-capture feedback — slides in from `.bottom`) and a prominent card (used by the full-screen export overlay). Keep both.

## Capture sound

- A bundled shutter (`PeekOCR/Resources/capture-shutter.m4a`) plays asynchronously via `CaptureSoundService.shared.play()` at the end of `processScreenshot` and after successful clip export in `captureGifClipWithNativeRecorder`. OCR captures do not fire the sound.
- User preferences live in `SoundSettings.shared` (enable toggle + volume, both persisted in `UserDefaults`).
- New audio assets must include a license line in `PeekOCR/Resources/ATTRIBUTIONS.md`.

## Docs to keep updated when behavior changes

- `README.md`
- `AGENTS.md`
- `CHANGELOG.md`
- this file (`CLAUDE.md`)

## Validation checklist before finishing work

- Build the app successfully with `xcodebuild`.
- Check `git diff --stat` for unexpected churn.
- Update docs for any user-visible or architecture-visible changes.
- If export/capture behavior changes, verify no partial temp/output files are left behind on failure paths.

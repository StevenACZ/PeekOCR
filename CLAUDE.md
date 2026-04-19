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

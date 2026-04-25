# Changelog

All notable changes to PeekOCR will be documented in this file.

The format is based on Keep a Changelog,
and this project loosely follows Semantic Versioning.

## [Unreleased]

## [1.8.1] - 2026-04-24

### Fixed
- Permission guidance surfaces now render cleanly in Light Mode and Dark Mode, including the floating System Settings assistant, draggable app card, requirements window, menu bar reminder, and Settings permission rows.
- Improved the requirements window activation button contrast across permission accent colors.

### Internal
- Added shared permission appearance helpers so AppKit permission overlays resolve dynamic system colors against the active macOS appearance.

## [1.8.0] - 2026-04-19

### Added
- Guided permission onboarding with an in-app reminder banner, settings activation rows, and a dedicated "Missing Permissions" window that explains what is required before capture can continue.
- A floating System Settings assistant that opens the correct privacy pane and overlays lightweight guidance while the user enables Screen Recording or Accessibility.
- Live permission state cards in the requirements window, so Screen Recording and Accessibility stay visible and can transition to a green success state while setup is in progress.

### Changed
- PeekOCR no longer interrupts users with permission prompts on launch. Permission activation is now explicit and user-initiated from settings, the menu bar reminder, or a blocked capture attempt.
- Capture attempts now stop cleanly when Screen Recording is missing and route through the new onboarding window instead of failing silently.
- The "Missing Permissions" window now keeps a fixed size, remains open while the guided setup flow runs, and updates each permission card in place instead of hiding granted permissions.

### Internal
- Split the permission requirements UI into dedicated intro/card subviews, stabilized the preview/runtime sizing, and aligned the public docs with the new onboarding flow for release readiness.

## [1.7.0] - 2026-04-18

### Added
- `⌘⇧5` (annotated screenshot) and `⌘⇧6` (GIF recording) overlays now span every connected display, so you can start a selection on any monitor — not just the main one.
- Capture feedback sound with on/off toggle and volume slider under Settings → General → Sonido. The sound plays after successful screenshot save, GIF export, and video export.

### Improved
- The clip editor's frame-capture button now plays the capture shutter sound on success, matching `⌘⇧4` and `⌘⇧5`. Clip exports (GIF/MP4) stay silent since the editor workflow is intentionally quiet on completion.
- Redesigned the GIF/Video clip editor (`⌘⇧6`) with a flatter, card-based sidebar: the `GIF ↔ Video` switch now sits inline next to the "Exportación" title, and the quality, output, and estimation sections share a single card surface style.
- Demoted the `FPS` field to an informative row inside the Calidad card (it is not user-editable for video exports), so the real decisions — Resolución and Codec — read first.
- Replaced the yellow trim selection and the fixed gradient behind the video preview with an accent-color selection plus a neutral black canvas with a subtle vignette, so the trimmer stops competing with the video content.
- Swapped the generic chevrons in the playback controls for frame-step SF Symbols (`backward.frame.fill` / `forward.frame.fill`), added shortcut hints, and promoted the export buttons to the large control size with `defaultAction` on the primary export button.
- Flattened the post-capture "Frame guardado" toast into a chip that matches the timeline chip style and slides in from the bottom edge instead of from the right.

### Fixed
- Selection overlays for `⌘⇧5` and `⌘⇧6` were being clipped on secondary displays when macOS had "Displays have separate Spaces" enabled. Fixed by spawning one overlay window per active non-mirrored display, keyed to that display's `NSScreen`.
- Fixed overlay windows landing off-screen on secondary displays: `NSWindow(contentRect:...:screen:)` doubles the content origin when a non-nil screen is passed. Switched to the 4-parameter init plus an explicit `setFrame(screen.frame, display: false)` so window placement uses global coordinates on every display.
- Removed a hard-coded local path from a SwiftUI `#Preview` scaffold; preview now uses `FileManager.default.temporaryDirectory`.

### Internal
- Added `DisplayEnumerator` utility wrapping `CGGetActiveDisplayList` with mirror-set filtering.
- Added `CaptureSoundService` singleton (lazy-loaded `AVAudioPlayer`, fire-and-forget playback) and `SoundSettings` `ObservableObject` backed by `UserDefaults`.

## [1.6.0] - 2026-04-11

### Improved
- Replaced the `⌘⇧5` post-capture annotation editor flow with a live overlay that lets you select, resize, move, and annotate before the screenshot is taken.
- Added lightweight pre-capture annotation tools for arrows, text labels, and highlight boxes directly on the live screen overlay.
- Polished the live annotation overlay so existing arrows/highlights/text can be moved in place, highlight boxes can be resized individually, text editing uses double-click instead of hijacking drag-to-move, and `⌘Z` undoes the latest overlay change.
- Synced live overlay annotation stroke width and text defaults with Settings so preview/export visuals match the configured annotation defaults.
- Added direct region capture support in `NativeScreenCaptureService` so annotated captures can finalize the selected rect without reopening the native picker.
- Moved OCR work off the UI-critical path so recognition no longer blocks the menu bar flow as aggressively.
- Reworked screenshot processing to use a settings snapshot plus detached processing for scaling and file persistence.
- Replaced AppKit-based image encoding with an ImageIO-based pipeline to reduce transient memory spikes during save/export.
- Switched screen capture decoding to ImageIO and memory-mapped reads to avoid unnecessary in-memory PNG duplication.
- Replaced the GIF editor playback polling timer with an AVPlayer periodic time observer.
- Added cached support detection for native screen recording capabilities.
- Added safer cleanup for failed GIF/MP4 exports so partial files do not linger on disk.
- Moved history persistence onto a utility queue to reduce synchronous main-thread work.

### Fixed
- Fixed multiple live overlay UX edge cases where outside clicks could accidentally start a new text/arrow action, stale selection outlines could linger after tool changes, and cursor feedback could remain stuck in the wrong state.
- Fixed a real leak in shortcut recording by storing and removing NSEvent local monitors correctly.
- Removed always-on permission polling from settings and now refresh permission state when the app becomes active.
- Prevented duplicate Carbon hotkey event handler installation.
- Standardized filename timestamp generation across screenshots, frame captures, GIF exports, and MP4 exports.
- Replaced view-owned singleton state wrappers (`@StateObject`) with externally owned observers where appropriate.

### Internal
- Added `AppDateFormatters` utility helpers for consistent timestamp formatting.
- Tightened runtime behavior for long-lived menu bar usage with cleaner worker/background boundaries.

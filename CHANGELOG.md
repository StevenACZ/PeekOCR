# Changelog

All notable changes to PeekOCR will be documented in this file.

The format is based on Keep a Changelog,
and this project loosely follows Semantic Versioning.

## [Unreleased]

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

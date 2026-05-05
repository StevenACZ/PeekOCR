# PeekOCR Agent Notes

PeekOCR is a public native macOS menu bar app for OCR, QR detection,
screenshots, live annotation capture, GIF clip recording, and MP4/GIF export.
Speak Spanish with the user; write code, commits, and public docs in English.

## Product Boundary

- macOS 13+ on Apple Silicon only (`arm64`, M1 or newer).
- Native Swift 5.9, SwiftUI, AppKit, Vision, CoreGraphics/ImageIO, and
  AVFoundation/AVKit.
- No cloud services, account system, network sync, or background upload flow.
- Do not commit private paths, personal device names, screenshots, logs, team
  IDs, signing data, or local planning notes.

## Current Reality

- `CaptureCoordinator` owns capture orchestration for OCR, screenshot, live
  annotated screenshot, and GIF clip flows.
- Screen Recording and Accessibility prompts must stay explicit and
  user-driven through the menu reminder, settings rows, or missing-permissions
  window.
- Live annotation uses one overlay window per active non-mirrored display, with
  selection, move, resize, arrow, text, highlight, cursor, and undo behavior
  split across focused `LiveAnnotationOverlayView+*.swift` files.
- GIF clips use native screen recording, a trim/editor window, GIF/MP4 export
  services, non-interactive video preview, and lightweight export metrics logs.
- Capture sound plays only after successful screenshot save and current-frame
  save. OCR, GIF recording, and GIF/MP4 exports stay silent.
- The app bundle should avoid duplicate resources: app icons live in
  `Assets.car`; standalone `AppIcon.icns` generation is disabled.

## Files To Check First

- `PeekOCR/Services/CaptureCoordinator.swift`
- `PeekOCR/Services/Permissions/PermissionService.swift`
- `PeekOCR/Services/Permissions/PermissionAssistant.swift`
- `PeekOCR/Services/Permissions/PermissionRequirementsWindowController.swift`
- `PeekOCR/Services/LiveAnnotationOverlayWindowController.swift`
- `PeekOCR/Services/LiveAnnotationRenderer.swift`
- `PeekOCR/Services/GifExportService.swift`
- `PeekOCR/Services/VideoExportService.swift`
- `PeekOCR/Views/Annotation/Overlay/LiveAnnotationOverlayView.swift`
- `PeekOCR/Views/Gif/GifClipEditorView.swift`
- `PeekOCR/Views/Gif/GifClipSidebarView.swift`
- `PeekOCR/Views/MenuBar/MenuBarPopoverView.swift`
- `PeekOCR/Views/Permissions/PermissionRequirementsView.swift`
- `PeekOCR/Managers/HistoryManager.swift`

## Preserve

- Public docs stay compact and aligned to live code: `README.md`,
  `CHANGELOG.md`, and `docs/*.md`.
- Keep files small: split views before 300 lines, helpers before 50 lines when
  responsibility is separable.
- Use ImageIO/CoreGraphics for background-safe image encoding/decoding.
- Keep OCR, image processing, and export work off the UI-critical path.
- Clean up monitors, timers, observers, temporary files, and partial exports.
- Prefer event-driven permission refreshes over polling.
- Use `@ObservedObject` for shared singletons owned outside a view lifecycle.
- For hot paths, avoid avoidable `Data` copies, repeated encoders, unnecessary
  image decode/resize work, and render-loop logging.

## Verification

Use targeted checks for docs-only changes. For code or release-size changes:

```bash
git status --short --ignored
xcodebuild -project PeekOCR.xcodeproj -scheme PeekOCR -configuration Debug build
xcodebuild -project PeekOCR.xcodeproj -scheme PeekOCR -configuration Release build
xcodebuild -project PeekOCR.xcodeproj -scheme PeekOCR -configuration Release -showBuildSettings | rg "ARCHS|ONLY_ACTIVE_ARCH|EXCLUDED_ARCHS|SDKROOT"
du -sh path/to/PeekOCR.app path/to/PeekOCR.app/Contents/MacOS/PeekOCR path/to/PeekOCR.app/Contents/Resources
lipo -archs path/to/PeekOCR.app/Contents/MacOS/PeekOCR
git diff --check
```

`xcodebuild test` is not currently usable until the `PeekOCR` scheme gets a
test action.

## Release Notes

- Release metadata lives in `PeekOCR.xcodeproj/project.pbxproj` and
  `CHANGELOG.md`.
- Build/package artifacts locally, then verify bundle version, architecture,
  signing, app size, `hdiutil verify`, and checksum before publishing.
- If only Apple Development signing is available, keep the Gatekeeper /
  notarization caveat explicit.
- Do not run `git add`, `git commit`, `git push`, `gh pr create`, merge,
  rebase, reset, tag, or release publication without explicit user approval.

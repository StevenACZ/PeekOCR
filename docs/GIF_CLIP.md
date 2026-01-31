# GIF Clip Capture

PeekOCR includes a short **GIF Clip** capture mode designed for sharing UI bugs/animations either as a lightweight GIF (great for frame-by-frame debugging) or as an MP4 video (better quality/size for sharing with a team).

## User Flow

1. Trigger **GIF Clip** via the hotkey (default: `⌘⇧6`) or the Menu Bar quick action.
2. Select a screen region (cursor becomes a crosshair).
   - Press `Esc` to cancel selection.
3. Recording starts with a small **REC HUD** that shows elapsed seconds (max duration is configurable in Settings: **3–60s**, default **10s**).
   - Stop early via the HUD Stop button.
   - Or press the GIF hotkey again to stop.
4. The post-record editor opens:
   - Play/pause preview
   - Step frame-by-frame (buttons and keyboard arrows)
   - Trim via the timeline range slider (minimum duration: **3s**)
5. Export:
   - Choose **GIF** or **Video** in the sidebar
   - UI is disabled while exporting and a loading overlay is shown
   - Output is saved to the configured output directory (same directory used by screenshots)
6. The temporary `.mov` file is deleted after the editor completes.

## Key Modules

### Capture entry points
- `Services/CaptureCoordinator.swift` (`CaptureMode.gifClip`)
- `Services/HotKeyManager.swift` (routes the hotkey to `CaptureCoordinator`)
- `Views/MenuBar/MenuBarPopoverView.swift` (quick action button)

### Region selection + recording
- `Services/GifRecordingController.swift` (orchestrates selection → recording → stop/cancel)
- `Services/GifRecordingOverlayWindowController.swift` (full-screen keyable overlay window)
- `Views/Gif/Overlay/GifRecordingOverlayView.swift` (selection UI, dim outside region)
- `Services/GifRecordingHudWindowController.swift` + `Views/Gif/Overlay/GifRecordingHudView.swift` (elapsed timer + Stop button)

### Post-record editor window
- `Services/GifClipWindowController.swift` (presents editor and returns exported URL)
- `Services/GifClipWindowFactory.swift` (window creation/config)
- `Views/Gif/GifClipEditorView.swift` (main editor UI)
- `Models/State/GifClipEditorState.swift` (AVPlayer playback + trim state)
- `Views/Components/RangeSlider.swift` (dual-handle trim control)
- `Views/Components/NonInteractiveVideoPlayer.swift` (preview-only AVPlayerView)

### Export pipeline
- `Services/GifExportService.swift` (extracts frames and writes animated GIF via ImageIO)
- `Services/VideoExportService.swift` (exports a trimmed segment as MP4, no audio)
- `Models/GifExportOptions.swift` (GIF profile/FPS presets and toggles)
- `Models/VideoExportOptions.swift` (video resolution/codec options, exports at 30 FPS)
- `Models/GifClipSettings.swift` (max duration + default export preferences)

## Behavior Notes

- **Max duration** is enforced by the recording controller (from `GifClipSettings.maxDurationSeconds`).
- **Stopping early** is supported via the hotkey or HUD Stop button.
- **Minimum trim duration** is enforced by the timeline slider (`Constants.Gif.minimumClipDurationSeconds`).

## Debugging Tips

- Recording relies on `/usr/sbin/screencapture -v` (video recording support is checked at runtime).
- Region coordinates must be converted from AppKit screen coordinates to CoreGraphics display coordinates before calling `screencapture -R ...`.

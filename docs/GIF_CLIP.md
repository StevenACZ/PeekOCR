# GIF Clip Capture

PeekOCR includes a short **GIF Clip** capture mode designed for sharing UI bugs/animations as a lightweight GIF that can be reviewed frame-by-frame.

## User Flow

1. Trigger **GIF Clip** via the hotkey (default: `⌘⇧6`) or the Menu Bar quick action.
2. Select a screen region (cursor becomes a crosshair).
   - Press `Esc` to cancel selection.
3. Recording starts with a countdown HUD (max duration: **10s**).
   - Stop early via the HUD Stop button.
   - Or press the GIF hotkey again to stop.
4. The post-record editor opens:
   - Play/pause preview
   - Step frame-by-frame (buttons and keyboard arrows)
   - Trim via the timeline range slider (minimum duration: **3s**)
5. Export GIF:
   - UI is disabled while exporting and a loading overlay is shown
   - The GIF is saved to the configured output directory (same directory used by screenshots)
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
- `Services/GifRecordingHudWindowController.swift` + `Views/Gif/Overlay/GifRecordingHudView.swift` (countdown + Stop button)

### Post-record editor window
- `Services/GifClipWindowController.swift` (presents editor and returns exported URL)
- `Services/GifClipWindowFactory.swift` (window creation/config)
- `Views/Gif/GifClipEditorView.swift` (main editor UI)
- `Models/State/GifClipEditorState.swift` (AVPlayer playback + trim state)
- `Views/Components/RangeSlider.swift` (dual-handle trim control)
- `Views/Components/NonInteractiveVideoPlayer.swift` (preview-only AVPlayerView)

### Export pipeline
- `Services/GifExportService.swift` (extracts frames and writes animated GIF via ImageIO)
- `Models/GifExportOptions.swift` (quality/FPS/size presets and toggles)

## Behavior Notes

- **Max duration** is enforced by the recording controller (`Constants.Gif.maxDurationSeconds`).
- **Stopping early** is supported via the hotkey or HUD Stop button.
- **Minimum trim duration** is enforced by the timeline slider (`Constants.Gif.minimumClipDurationSeconds`).
- **Dithering toggle** (`GifExportOptions.isDitheringEnabled`) is currently UI-only and reserved for future export improvements.

## Debugging Tips

- Recording relies on `/usr/sbin/screencapture -v` (video recording support is checked at runtime).
- Region coordinates must be converted from AppKit screen coordinates to CoreGraphics display coordinates before calling `screencapture -R ...`.

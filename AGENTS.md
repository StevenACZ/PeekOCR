# AGENTS.md - PeekOCR

## Project Overview

PeekOCR is a native macOS Menu Bar application for OCR text capture, QR code detection, screenshots, **GIF clip recording**, and **annotation editing**. Built with Swift 5.9, SwiftUI, and AppKit.

Important:
- this repository is public
- never add local absolute paths, private machine details, or personal environment data to committed docs/code

## Documentation Index

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layer diagram, data flow, patterns |
| [docs/COMPONENTS.md](docs/COMPONENTS.md) | Reusable UI components catalog |
| [docs/GIF_CLIP.md](docs/GIF_CLIP.md) | GIF clip capture flow + key modules |
| [docs/MODELS.md](docs/MODELS.md) | Data models and state managers |
| [docs/SERVICES.md](docs/SERVICES.md) | Service classes documentation |
| [docs/VIEWS.md](docs/VIEWS.md) | View hierarchy and modules |

## Files Worth Checking First

- `PeekOCR/Services/CaptureCoordinator.swift`
- `PeekOCR/Services/Permissions/PermissionService.swift`
- `PeekOCR/Services/Permissions/PermissionAssistant.swift`
- `PeekOCR/Services/Permissions/PermissionRequirementsWindowController.swift`
- `PeekOCR/Services/LiveAnnotationOverlayWindowController.swift`
- `PeekOCR/Services/LiveAnnotationRenderer.swift`
- `PeekOCR/Services/GifRecordingOverlayWindowController.swift`
- `PeekOCR/Views/Annotation/Overlay/LiveAnnotationOverlayView.swift`
- `PeekOCR/Views/MenuBar/MenuBarPopoverView.swift`
- `PeekOCR/Views/Permissions/PermissionRequirementsView.swift`
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
- `PeekOCR/Views/Components/PermissionSummaryBanner.swift`
- `PeekOCR/Managers/HistoryManager.swift`

## Dev Environment

### Requirements

- Xcode 15+
- macOS 13.0+ (Ventura)
- Swift 5.9

### Build Commands

```bash
# Debug build
xcodebuild -project PeekOCR.xcodeproj -scheme PeekOCR -configuration Debug build

# Release build
xcodebuild -project PeekOCR.xcodeproj -scheme PeekOCR -configuration Release build

# Clean build folder
xcodebuild clean -project PeekOCR.xcodeproj -scheme PeekOCR

# Open in Xcode
open PeekOCR.xcodeproj
```

## Project Structure (Final)

```
PeekOCR/
├── Models/
│   ├── Annotations/                  # Annotation data types
│   │   ├── Annotation.swift          # Single annotation model
│   │   ├── AnnotationTool.swift      # Tool enum (arrow, text, etc.)
│   │   ├── LiveAnnotation.swift      # Lightweight pre-capture annotation model
│   │   └── ResizeHandle.swift        # Resize handle positions
│   │
│   ├── State/                        # State managers
│   │   ├── UndoRedoManager.swift     # Generic undo/redo
│   │   ├── SelectionManager.swift    # Selection state
│   │   ├── TextInputController.swift # Text input lifecycle
│   │   ├── AnnotationUndoManager.swift   # Annotation-specific undo/redo (NEW)
│   │   ├── AnnotationDragManager.swift   # Drag and resize state (NEW)
│   │   ├── AnnotationTextManager.swift   # Text input state (NEW)
│   │   └── GifClipEditorState.swift      # GIF trim + playback state
│   │
│   ├── AnnotationState.swift         # Main editor state (refactored, uses composition)
│   ├── AppState.swift                # Global app state
│   ├── AppSettings.swift             # User preferences
│   ├── AnnotationSettings.swift      # Annotation defaults
│   ├── ScreenshotSettings.swift      # Screenshot options
│   ├── SoundSettings.swift           # Capture-sound preferences (enable + volume)
│   ├── CaptureItem.swift             # History item
│   ├── GifExportOptions.swift         # GIF export presets/options
│   └── SaveLocation.swift            # Save location enum
│
├── Services/
│   ├── Annotation/
│   │   ├── AnnotationGeometry.swift       # Geometry calculations
│   │   └── AnnotationWindowFactory.swift  # Window creation
│   │
│   ├── Screenshot/
│   │   ├── ImageScalingService.swift      # High-quality scaling
│   │   └── ImageEncodingService.swift     # Format conversion
│   │
│   ├── HotKey/
│   │   └── HotKeyDefinition.swift         # Hotkey config struct
│   │
│   ├── Permissions/
│   │   ├── AppPermission.swift            # Supported permission definitions
│   │   ├── PermissionService.swift        # Missing-permission checks + guided flow entry
│   │   ├── PermissionAssistant.swift      # Floating helper over System Settings
│   │   ├── PermissionRequirementsWindowController.swift # Blocked-capture explainer window
│   │   └── PermissionSettingsWindowLocator.swift # Tracks Settings window positioning
│   │
│   ├── AnnotationWindowController.swift   # Window lifecycle
│   ├── CaptureCoordinator.swift           # Capture orchestration
│   ├── CaptureSoundService.swift          # Shutter sound playback (async AVAudioPlayer)
│   ├── DisplayEnumerator.swift            # Active non-mirror displays → NSScreen pairs
│   ├── LiveAnnotationOverlayWindowController.swift # Per-display live pre-capture overlays
│   ├── LiveAnnotationRenderer.swift       # Shared live overlay/export renderer
│   ├── GifClipWindowController.swift      # GIF editor window lifecycle
│   ├── GifClipWindowFactory.swift         # GIF editor window creation
│   ├── GifExportService.swift             # Video -> GIF export
│   ├── GifRecordingController.swift       # Selection + recording orchestration
│   ├── GifRecordingHudWindowController.swift     # Countdown + stop HUD
│   ├── GifRecordingOverlayWindowController.swift # Per-display selection overlay
│   ├── ScreenshotService.swift            # Screenshot processing
│   ├── NativeScreenCaptureService.swift   # Native capture
│   ├── NativeScreenRecordingService.swift # Native video capture support checks
│   ├── HotKeyManager.swift                # Global shortcuts
│   └── OCRService.swift                   # Text recognition
│
├── Views/
│   ├── Annotation/
│   │   ├── Canvas/
│   │   │   ├── AnnotationCanvasView.swift    # Drawing surface (~182 lines)
│   │   │   ├── AnnotationRenderer.swift      # Draw dispatcher
│   │   │   ├── SelectionHandlesView.swift    # Resize handles
│   │   │   └── TextInputOverlay.swift        # Text input field
│   │   │
│   │   ├── Editor/
│   │   │   ├── AnnotationEditorView.swift    # Main editor (~125 lines)
│   │   │   ├── KeyboardEventHandler.swift    # Keyboard shortcuts
│   │   │   └── CGContextAnnotationRenderer.swift  # Export rendering
│   │   │
│   │   ├── Toolbar/
│   │   │   ├── AnnotationToolbar.swift       # Main toolbar
│   │   │   ├── ToolButton.swift              # Tool selection
│   │   │   ├── ActionIconButton.swift        # Action buttons
│   │   │   └── ShortcutKeyBadge.swift        # Shortcut display
│   │   │
│   │   ├── ColorPaletteView.swift
│   │   ├── StrokeWidthPicker.swift
│   │   └── Overlay/
│   │       └── LiveAnnotationOverlayView.swift # Full-screen live pre-capture overlay
│   │
│   ├── MenuBar/
│   │   ├── MenuBarPopoverView.swift          # Main popover + permission reminder
│   │   ├── MenuBarActionButton.swift         # Quick action button
│   │   ├── HistoryItemRow.swift              # History item row
│   │   └── EmptyStateView.swift              # Empty state placeholder
│   │
│   ├── Permissions/
│   │   ├── PermissionRequirementsView.swift      # Missing-permissions window content
│   │   ├── PermissionRequirementsIntroView.swift # Intro block for permission onboarding
│   │   └── PermissionRequirementCard.swift       # Per-permission activation card
│   │
│   ├── Gif/
│   │   ├── GifClipEditorView.swift           # Post-record editor window
│   │   ├── GifClipKeyboardHandler.swift      # Frame-by-frame shortcuts
│   │   ├── GifClipPlaybackControlsView.swift # Play/pause + stepping UI
│   │   ├── GifClipSidebarView.swift          # Export options + estimates
│   │   ├── GifClipTimelineReadoutView.swift  # In/out readout
│   │   ├── GifClipTimelineView.swift         # Timeline + trim range
│   │   ├── GifClipVideoPreviewView.swift     # Video preview container
│   │   ├── GifExportLoadingOverlay.swift     # Export loading UI
│   │   └── Overlay/
│   │       ├── GifRecordingHudView.swift     # HUD SwiftUI view
│   │       └── GifRecordingOverlayView.swift # Selection overlay view
│   │
│   ├── Settings/
│   │   ├── Sections/                         # Modular settings sections
│   │   │   ├── HotkeyDisplaySection.swift    # Hotkey display
│   │   │   ├── SaveOptionsSection.swift      # Save toggles
│   │   │   ├── SaveLocationSection.swift     # Location picker
│   │   │   ├── ImageFormatSection.swift      # Format picker
│   │   │   ├── ImageScaleSection.swift       # Scale slider
│   │   │   └── AnnotationDefaultsSection.swift  # Default settings
│   │   │
│   │   ├── SettingsView.swift
│   │   ├── GeneralSettingsTab.swift
│   │   ├── ShortcutsSettingsTab.swift
│   │   ├── ScreenshotSettingsTab.swift       # Uses sections (~36 lines)
│   │   ├── HistorySettingsTab.swift
│   │   └── AboutTab.swift
│   │
│   ├── Components/                           # Reusable components
│   │   ├── NonInteractiveVideoPlayer.swift   # AVPlayerView wrapper (no controls)
│   │   ├── RangeSlider.swift                 # Dual-handle range slider
│   │   ├── SectionHeader.swift
│   │   ├── SectionDivider.swift
│   │   ├── SettingSliderRow.swift
│   │   ├── ShortcutRecorderRow.swift
│   │   ├── PermissionStatusRow.swift
│   │   └── PermissionSummaryBanner.swift
│   │
│   └── Helpers/
│       ├── HitTestEngine.swift               # Collision detection
│       └── AnnotationTransformer.swift       # Move/resize operations
│
├── Managers/
│   └── HistoryManager.swift                  # Capture history (singleton)
│
├── Resources/
│   ├── capture-shutter.m4a                   # Bundled shutter sound
│   └── ATTRIBUTIONS.md                       # Third-party asset licenses
│
├── Utils/
│   └── AppLogger.swift                       # Centralized logging (OSLog)
│
├── Extensions/
│   ├── CaptureType+Display.swift
│   └── HotKeyDisplay.swift
│
├── AppDelegate.swift
├── PeekOCRApp.swift
└── Constants.swift

```

## Performance Focus

PeekOCR is expected to behave well as a long-lived menu bar app. When changing runtime-sensitive code, prefer:

- background OCR/image/export work over main-thread processing
- ImageIO/CoreGraphics for background-safe image encoding/decoding
- explicit cleanup for monitors, timers, observers, and temporary files
- event-driven permission refreshes instead of perpetual polling
- `@ObservedObject` for shared singletons owned outside the view lifecycle

## UX Guardrails

### Permission UX

- Do not trigger permission prompts automatically at app launch.
- Missing permissions should surface through explicit UI: settings rows, the menu bar reminder banner, or the dedicated requirements window shown when capture is blocked.
- `PermissionService` owns the "what is missing?" logic and starts the guided activation flow.
- `PermissionAssistant` opens the correct System Settings pane and keeps the floating helper aligned with the settings window.
- `PermissionRequirementsWindowController` presents the explainer window when capture cannot proceed yet.
- Accessibility-backed hotkeys should refresh when the app becomes active again after the user enables the permission.

### Multi-display and Windowing Notes

- Capture overlays (`LiveAnnotationOverlayWindowController`, `GifRecordingOverlayWindowController`) spawn one borderless window per active non-mirrored display via `DisplayEnumerator.activeScreens()`. The first mouse-down claims the session and dismisses sibling overlays.
- Do not pass a non-nil `screen:` argument to `NSWindow(contentRect:styleMask:backing:defer:screen:)` when `contentRect` already contains global coordinates. Use the 4-parameter initializer and then `setFrame(screen.frame, display: false)`.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+). Files added anywhere under `PeekOCR/` are auto-discovered; manual `project.pbxproj` edits are unnecessary.

### Clip Editor UI Notes

- `GifClipSidebarView` uses a flat header plus shared card sections via `cardSection(title:content:)`. Reuse that helper instead of creating new background treatments.
- The `GIF ↔ Video` segmented picker belongs inline in the export header, not in its own section.
- Video export `FPS` is an informational row inside the quality card, not a user-editable picker.
- Timeline trim selection uses `Color.accentColor`, with a white capsule playhead and dot. Do not reintroduce the previous yellow highlight.
- The preview container should remain a neutral black rounded rectangle with a subtle vignette, not a decorative gradient.
- Playback controls should keep `backward.frame.fill` and `forward.frame.fill` for frame stepping.
- The primary export button keeps `.keyboardShortcut(.defaultAction)` and Cancel stays bound to `.cancelAction`.

### Capture Sound Notes

- `PeekOCR/Resources/capture-shutter.m4a` is played asynchronously via `CaptureSoundService.shared.play()`.
- The shutter sound plays after successful screenshot save and after saving the current frame from the clip editor.
- OCR captures, GIF/video recordings, and GIF/video exports should stay silent.
- Preferences live in `SoundSettings.shared` and new audio assets must be documented in `PeekOCR/Resources/ATTRIBUTIONS.md`.

## Key Architecture

### Patterns Used

- **MVVM**: Views observe ObservableObject state
- **Coordinator**: CaptureCoordinator orchestrates capture flow
- **Singleton**: Shared services (`CaptureCoordinator.shared`)
- **Factory**: `AnnotationWindowFactory` creates configured windows
- **Static Helpers**: Pure functions in enums (`AnnotationGeometry`, `HitTestEngine`, `ImageScalingService`)
- **Composition**: AnnotationState delegates to specialized managers (UndoManager, DragManager, TextManager)
- **Centralized Logging**: AppLogger with OSLog for structured debugging

### Component Guidelines

- Each file starts with 1-line English description comment
- Max ~80-150 lines per component (exceptions documented)
- Single responsibility per file
- Reusable components in `Views/Components/`
- Settings sections in `Views/Settings/Sections/`
- Include `#Preview` for visual testing

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Views | `*View.swift`, `*Section.swift` | `AnnotationCanvasView.swift` |
| Services | `*Service.swift`, `*Manager.swift` | `ScreenshotService.swift` |
| Factories | `*Factory.swift` | `AnnotationWindowFactory.swift` |
| Helpers | `*Engine.swift`, `*Transformer.swift` | `HitTestEngine.swift` |
| Components | Descriptive noun | `ToolButton.swift` |

## Capture Modes

| Mode | Hotkey | Action |
|------|--------|--------|
| OCR | `⇧ Space` | Extract text, copy to clipboard |
| Screenshot | `⌘⇧4` | Save image to file |
| Annotated | `⌘⇧5` | Live overlay: select, adjust, annotate, then save |
| GIF Clip | `⌘⇧6` | Select region, record up to 10s, export as GIF |

## Common Tasks

### Adding a New Capture Mode
1. Add case to `CaptureMode` in `Services/CaptureCoordinator.swift`
2. Add a quick action button in `Views/MenuBar/MenuBarPopoverView.swift`
3. Register the default hotkey in `Models/AppSettings.swift` and `Services/HotKeyManager.swift`
4. Add/label the shortcut in `Views/Settings/ShortcutsSettingsTab.swift`
5. Update docs and manual QA checklist

### Adding a New Annotation Tool
1. Add case to `AnnotationTool` enum
2. Add icon, display name, shortcut key
3. Add drawing in `AnnotationRenderer`
4. Add export in `CGContextAnnotationRenderer`
5. Update `KeyboardEventHandler` if needed

### Adding a New Setting
1. Add property to settings model
2. Create section in `Views/Settings/Sections/` if needed
3. Add to settings tab
4. Use `@AppStorage` for persistence

### Adding a New Component
1. Create in `Views/Components/` or `Views/Settings/Sections/`
2. Add English description comment
3. Make reusable with parameters
4. Document in `docs/COMPONENTS.md`

### Adding a New Service
1. Create in appropriate subfolder (`Services/Screenshot/`, `Services/HotKey/`, etc.)
2. Add English description comment
3. Use static methods for pure operations
4. Document in `docs/SERVICES.md`

## Frameworks

| Framework | Purpose |
|-----------|---------|
| SwiftUI | UI components |
| AppKit | Menu bar, windows |
| Vision | OCR, QR detection |
| Carbon | Global hotkeys |
| CoreGraphics | Image processing |
| CoreText | Text rendering |
| AVFoundation / AVKit | Video preview + frame extraction |
| ImageIO | GIF encoding |
| UniformTypeIdentifiers | GIF UTType identifiers |

## Permissions Required

- **Screen Recording**: For capture
- **Accessibility**: For global hotkeys

Permission prompts should remain explicit and user-driven. Prefer the menu bar banner, settings activation rows, and the dedicated requirements window over automatic launch-time prompts.

## Testing Checklist

- [ ] Menu bar icon appears
- [ ] Missing permissions show the menu bar reminder banner instead of an automatic startup prompt
- [ ] Hotkeys trigger capture
- [ ] Trying to capture without Screen Recording opens the missing-permissions window
- [ ] Live annotation overlay opens for `⌘⇧5`
- [ ] Selection can be created, moved, and resized before capture
- [ ] Overlay tools work for arrow, text, and highlight before capture
- [ ] GIF clip capture opens for `⌘⇧6` (select → record → editor)
- [ ] Overlays for `⌘⇧5` and `⌘⇧6` appear on every connected display and selection works on secondary monitors
- [ ] Capture sound plays on screenshot save, GIF export, and video export (and not on OCR)
- [ ] Sound toggle and volume slider in Settings → General → Sonido take effect and persist
- [ ] Undo/redo works
- [ ] Selection and resize works
- [ ] Save exports image correctly
- [ ] GIF export saves correctly and appears in history
- [ ] Settings persist

## Docs To Keep Updated

- `README.md`
- `AGENTS.md`
- `CHANGELOG.md`
- `docs/ARCHITECTURE.md`
- `docs/COMPONENTS.md`
- `docs/SERVICES.md`
- `docs/VIEWS.md`

## Final Validation Checklist

- Build the app successfully with `xcodebuild`.
- Check `git diff --stat` for unexpected churn.
- Update docs for any user-visible or architecture-visible changes.
- If export or capture behavior changes, verify failure paths do not leave partial temp or output files behind.

## Git Workflow

```bash
# Before committing
xcodebuild -scheme PeekOCR build

# Commit format
<type>: <description>
# Types: feat, fix, refactor, style, docs, chore
```

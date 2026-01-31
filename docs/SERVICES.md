# Services

Documentation of service classes and their responsibilities.

## Capture Services

### CaptureCoordinator
Orchestrates the capture workflow.

**Location:** `Services/CaptureCoordinator.swift`

**Responsibilities:**
- Start capture with a specified mode (OCR, screenshot, annotated screenshot, GIF clip)
- Coordinate with native capture/recording services
- Route results to clipboard / file export
- Add items to history

```swift
// Usage
CaptureCoordinator.shared.startCapture(mode: .ocr)
CaptureCoordinator.shared.startCapture(mode: .screenshot)
CaptureCoordinator.shared.startCapture(mode: .annotatedScreenshot)
CaptureCoordinator.shared.startCapture(mode: .gifClip)
```

### NativeScreenCaptureService
Interfaces with macOS `screencapture` (image).

**Location:** `Services/NativeScreenCaptureService.swift`

**Responsibilities:**
- Execute native screenshot capture
- Handle temporary file management
- Return captured `CGImage`

### NativeScreenRecordingService
Low-level wrapper for macOS `screencapture` (video).

**Location:** `Services/NativeScreenRecordingService.swift`

**Responsibilities:**
- Detect whether the current OS supports video capture flags
- Provide an interactive recording fallback when needed

```swift
// Usage
let supported = await NativeScreenRecordingService.shared.supportsInteractiveVideoCapture()
```

### OCRService
Text recognition from images.

**Location:** `Services/OCRService.swift`

**Responsibilities:**
- Perform OCR using Vision framework
- Detect QR codes
- Return recognized text

## Screenshot Services

### ScreenshotService
Main screenshot processing orchestrator.

**Location:** `Services/ScreenshotService.swift`

**Responsibilities:**
- Process screenshots (copy, save)
- Coordinate scaling and encoding services

```swift
// Usage
await ScreenshotService.shared.processScreenshot(image)
```

### ImageScalingService
High-quality image scaling.

**Location:** `Services/Screenshot/ImageScalingService.swift`

**Responsibilities:**
- Scale images using high-quality interpolation
- Maintain quality during resize
- Handle proper color space conversion

```swift
// Usage
let scaled = ImageScalingService.scaleImage(image, scale: 0.5)
```

### ImageEncodingService
Format conversion for various image formats.

**Location:** `Services/Screenshot/ImageEncodingService.swift`

**Responsibilities:**
- Convert to PNG, JPEG, TIFF, HEIC
- Configure quality settings per format
- Handle format-specific encoding options

```swift
// Usage
let data = ImageEncodingService.encode(image, format: .png)
let jpegData = ImageEncodingService.encode(image, format: .jpg, quality: 0.8)
```

## GIF Clip Services

### GifRecordingController
Orchestrates region selection and short screen video recording for clip capture.

**Location:** `Services/GifRecordingController.swift`

**Responsibilities:**
- Present a full-screen region selection overlay (ESC cancels)
- Start a region recording using `screencapture -R ... -v`
- Show an external HUD with remaining time + Stop button (not captured)
- Support stopping early by pressing the GIF hotkey again
- Return a temporary `.mov` URL (caller deletes it after export)

```swift
// Usage
let maxDurationSeconds = GifClipSettings.shared.maxDurationSeconds
let videoURL = await GifRecordingController.shared.record(maxDurationSeconds: maxDurationSeconds)
```

### GifRecordingOverlayWindowController
Full-screen overlay window used for region selection + recording focus.

**Location:** `Services/GifRecordingOverlayWindowController.swift`

**Responsibilities:**
- Host the overlay view across all screens
- Capture selection rect + screen
- Drive recording mode visuals (dim outside selection, crosshair cursor)

### GifRecordingHudWindowController
Small HUD panel shown during recording.

**Location:** `Services/GifRecordingHudWindowController.swift`

**Responsibilities:**
- Display remaining seconds and progress
- Provide a quick Stop button

### GifClipWindowController
Manages the GIF clip editor window lifecycle and async continuation.

**Location:** `Services/GifClipWindowController.swift`

**Responsibilities:**
- Present the post-recording editor (`GifClipEditorView`)
- Return the exported result (GIF or MP4), or nil if canceled

```swift
// Usage
let result = await GifClipWindowController.shared.showEditor(with: videoURL, saveDirectory: outputDir)
```

### GifClipWindowFactory
Creates and configures the editor `NSWindow`.

**Location:** `Services/GifClipWindowFactory.swift`

### GifExportService
Exports a trimmed segment of a video to an optimized animated GIF.

**Location:** `Services/GifExportService.swift`

**Responsibilities:**
- Extract frames from a time range using `AVAssetImageGenerator`
- Encode frames into an animated GIF via `ImageIO`
- Save into the configured output directory

### VideoExportService
Exports a trimmed segment of a video to an MP4 file (no audio).

**Location:** `Services/VideoExportService.swift`

**Responsibilities:**
- Trim to a selected time range
- Downscale to a maximum resolution preset (preserving aspect ratio)
- Encode as MP4 using H.264 or HEVC

## Annotation Services

### AnnotationWindowController
Manages annotation editor window lifecycle.

**Location:** `Services/AnnotationWindowController.swift`

**Responsibilities:**
- Present editor window with async continuation
- Handle save/cancel callbacks
- Manage window cleanup

```swift
// Usage
let result = await AnnotationWindowController.shared.showEditor(with: image)
```

### AnnotationWindowFactory
Creates and configures editor windows.

**Location:** `Services/Annotation/AnnotationWindowFactory.swift`

**Responsibilities:**
- Create configured `NSWindow` instances
- Calculate optimal window size for images
- Configure window styling and behavior

```swift
// Usage
let size = AnnotationWindowFactory.calculateWindowSize(for: image)
let window = AnnotationWindowFactory.createWindow(size: size, delegate: self)
```

### AnnotationGeometry
Geometry calculations.

**Location:** `Services/Annotation/AnnotationGeometry.swift`

See [MODELS.md](./MODELS.md) for related models.

## HotKey Services

### HotKeyManager
Global keyboard shortcuts.

**Location:** `Services/HotKeyManager.swift`

**Responsibilities:**
- Register global hotkeys using Carbon API
- Handle hotkey events and route to `CaptureCoordinator`
- Manage accessibility permissions

### HotKeyDefinition
Configuration struct for hotkeys.

**Location:** `Services/HotKey/HotKeyDefinition.swift`

**Responsibilities:**
- Define hotkey configuration structure
- Provide shared signature for Carbon registration
- Define hotkey identifiers (including GIF clip)

## Service Patterns

### Singleton Pattern
Most services use shared instances:

```swift
CaptureCoordinator.shared
ScreenshotService.shared
HistoryManager.shared
AppSettings.shared
```

### Coordinator Pattern
`CaptureCoordinator` orchestrates complex workflows involving multiple services.

### Factory Pattern
`AnnotationWindowFactory` / `GifClipWindowFactory` create configured windows with consistent styling.

### Static Helpers
Services like `ImageScalingService` and `ImageEncodingService` use static methods for pure operations.

# Services

Documentation of service classes and their responsibilities.

## Capture Services

### CaptureCoordinator
Orchestrates the capture workflow.

**Location:** `Services/CaptureCoordinator.swift`

**Responsibilities:**
- Start capture with specified mode (OCR, screenshot, annotated)
- Coordinate with native capture service
- Process results based on mode
- Copy results to clipboard

```swift
// Usage
CaptureCoordinator.shared.startCapture(mode: .ocr)
CaptureCoordinator.shared.startCapture(mode: .screenshot)
CaptureCoordinator.shared.startCapture(mode: .annotatedScreenshot)
```

### NativeScreenCaptureService
Interfaces with macOS screencapture tool.

**Location:** `Services/NativeScreenCaptureService.swift`

**Responsibilities:**
- Execute native screencapture command
- Handle temporary file management
- Return captured CGImage

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
- Create configured NSWindow instances
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

See [MODELS.md](./MODELS.md) for details.

## HotKey Services

### HotKeyManager
Global keyboard shortcuts.

**Location:** `Services/HotKeyManager.swift`

**Responsibilities:**
- Register global hotkeys using Carbon API
- Handle hotkey events
- Manage accessibility permissions

```swift
// Usage
HotKeyManager.shared.registerHotKeys()
HotKeyManager.shared.reregisterHotKeys()
```

### HotKeyDefinition
Configuration struct for hotkeys.

**Location:** `Services/HotKey/HotKeyDefinition.swift`

**Responsibilities:**
- Define hotkey configuration structure
- Provide shared signature for Carbon registration
- Define hotkey identifiers

```swift
// Usage
let hotKeyID = HotKeyDefinition.signature
```

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
CaptureCoordinator orchestrates complex workflows involving multiple services.

### Factory Pattern
AnnotationWindowFactory creates configured windows with consistent styling.

### Static Helpers
Services like ImageScalingService and ImageEncodingService use static methods for pure operations.

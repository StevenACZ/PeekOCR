# Data Models

Documentation of data models and state managers.

## Annotation Models

### Annotation
Data model for a single annotation.

**Location:** `Models/Annotations/Annotation.swift`

```swift
struct Annotation: Identifiable {
    let id: UUID
    let tool: AnnotationTool
    let color: Color
    let strokeWidth: CGFloat
    var startPoint: CGPoint
    var endPoint: CGPoint
    var points: [CGPoint]     // For freehand
    var text: String          // For text
    var fontSize: CGFloat
}
```

### AnnotationTool
Available annotation tools.

**Location:** `Models/Annotations/AnnotationTool.swift`

```swift
enum AnnotationTool: String, CaseIterable {
    case select
    case arrow
    case text
    case freehand
    case rectangle
    case oval

    var iconName: String      // SF Symbol
    var displayName: String   // Localized name
    var shortcutKey: String   // Keyboard shortcut (0-5)
}
```

### ResizeHandle
Resize handle positions.

**Location:** `Models/Annotations/ResizeHandle.swift`

```swift
enum ResizeHandle: CaseIterable {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
}
```

## State Managers

### UndoRedoManager
Generic undo/redo manager.

**Location:** `Models/State/UndoRedoManager.swift`

```swift
class UndoRedoManager<T>: ObservableObject {
    @Published private(set) var canUndo: Bool
    @Published private(set) var canRedo: Bool

    func saveState(_ state: T)
    func undo() -> T?
    func redo() -> T?
    func clear()
}
```

### AnnotationState
Main state for annotation editor.

**Location:** `Models/AnnotationState.swift`

```swift
class AnnotationState: ObservableObject {
    // Tool settings
    @Published var selectedTool: AnnotationTool
    @Published var selectedColor: Color
    @Published var strokeWidth: CGFloat

    // Annotations
    @Published var annotations: [Annotation]
    @Published var currentAnnotation: Annotation?

    // Selection
    @Published var selectedAnnotationId: UUID?

    // Undo/Redo
    var canUndo: Bool
    var canRedo: Bool

    // Methods
    func startAnnotation(at:)
    func updateAnnotation(to:)
    func finishAnnotation()
    func undo()
    func redo()
    func selectAnnotation(at:) -> Bool
    // ...
}
```

### AppSettings
User preferences with persistence.

**Location:** `Models/AppSettings.swift`

- Screenshot settings (format, quality, scale)
- Hotkey configurations
- Save location preferences
- Annotation defaults
- GIF hotkey configuration (`gifHotKeyCode` / `gifHotKeyModifiers`)

### CaptureItem
History item for captures.

**Location:** `Models/CaptureItem.swift`

```swift
struct CaptureItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let captureType: CaptureType
    let timestamp: Date

    var displayText: String
    var formattedTime: String
    var icon: String
}

enum CaptureType: String, Codable {
    case text
    case qrCode
    case screenshot
    case gif
    case video
}
```

## Clip Models

### GifExportOptions
Export presets and toggles for GIF rendering.

**Location:** `Models/GifExportOptions.swift`

```swift
struct GifExportOptions: Equatable {
    var profile: GifExportProfile
    var fps: Int
    var maxPixelSize: Int
    var isLoopEnabled: Bool
}
```

### VideoExportOptions
Export options for MP4 (no audio) rendering.

**Location:** `Models/VideoExportOptions.swift`

```swift
struct VideoExportOptions: Equatable {
    var resolution: VideoExportResolution
    var fps: Int
    var codec: VideoExportCodec
}
```

### GifClipSettings
UserDefaults-backed settings for clip capture and export defaults.

**Location:** `Models/GifClipSettings.swift`

### GifClipEditorState
Trim + playback state for the GIF clip editor.

**Location:** `Models/State/GifClipEditorState.swift`

**Responsibilities:**
- Load video duration + nominal FPS
- Keep `startSeconds` / `endSeconds` within bounds (with a minimum clip duration)
- Control preview playback and frame-by-frame stepping via `AVPlayer`

## Geometry Helpers

### AnnotationGeometry
Pure geometry calculations.

**Location:** `Services/Annotation/AnnotationGeometry.swift`

```swift
enum AnnotationGeometry {
    static func boundingRect(for:) -> CGRect
    static func shapeRect(from:to:) -> CGRect
    static func calculateImageRect(imageSize:canvasSize:) -> CGRect
    static func handleRect(for:in:) -> CGRect
}
```

### HitTestEngine
Collision detection.

**Location:** `Views/Helpers/HitTestEngine.swift`

```swift
enum HitTestEngine {
    static func hitTest(annotation:at:) -> Bool
    static func hitTestHandle(at:for:) -> ResizeHandle?
    static func hitTestLine(from:to:point:tolerance:) -> Bool
}
```

### AnnotationTransformer
Transform operations.

**Location:** `Views/Helpers/AnnotationTransformer.swift`

```swift
enum AnnotationTransformer {
    static func move(_:dx:dy:) -> Annotation
    static func resize(_:handle:dx:dy:) -> Annotation
    static func scale(_:by:) -> Annotation
}
```

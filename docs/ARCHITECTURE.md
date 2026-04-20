# Architecture Overview

PeekOCR follows a clean **MVVM** architecture with clear separation of concerns.

## Layer Diagram

```
┌─────────────────────────────────────────────────────────┐
│                       VIEWS                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  MenuBar    │  │  Annotation │  │  Settings   │     │
│  │  Popover    │  │   Editor    │  │    Tabs     │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│  ┌─────────────┐  ┌──────────────────────────────┐     │
│  │ GIF Overlay │  │        GIF Clip Editor        │     │
│  └─────────────┘  └──────────────────────────────┘     │
│  ┌──────────────────────────────┐                      │
│  │   Permission Requirements     │                      │
│  └──────────────────────────────┘                      │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                       STATE                              │
│  ┌───────────────┐  ┌──────────────────┐  ┌───────────┐│
│  │AnnotationState │  │GifClipEditorState│  │AppSettings││
│  └───────────────┘  └──────────────────┘  └───────────┘│
│  ┌───────────────────────────────────────────────────┐  │
│  │                 HistoryManager                      │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                     SERVICES                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Capture    │  │ Screenshot  │  │   HotKey    │     │
│  │ Coordinator │  │  Service    │  │  Manager    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│  ┌──────────────────────┐  ┌────────────────────────┐  │
│  │ GifRecordingController│  │ GifExport/VideoExport   │  │
│  └──────────────────────┘  └────────────────────────┘  │
│  ┌──────────────────────┐  ┌────────────────────────┐  │
│  │  PermissionService   │  │  PermissionAssistant     │  │
│  └──────────────────────┘  └────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      MODELS                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Annotation  │  │CaptureItem  │  │  Settings   │     │
│  │   Models    │  │ + CaptureType│ │   Models    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│  ┌───────────────────────────────────────────────────┐  │
│  │        Gif/Video Export Options + Settings          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Data Flow

1. **User Action** → View receives gesture/input
2. **State Update** → Observable state objects publish changes
3. **Permission Gate** → Capture flows check required permissions before continuing
4. **Service Call** → Services execute business logic
5. **Model Update** → Data models are modified
6. **UI Refresh** → SwiftUI reactively updates views

## Key Patterns

### ObservableObject Pattern
- `AnnotationState`: Manages annotation editor state
- `AppSettings`: Persists user preferences
- `HistoryManager`: Tracks capture history

### Coordinator Pattern
- `CaptureCoordinator`: Orchestrates capture workflow
- `AnnotationWindowController`: Manages editor window lifecycle

### Permission-Gated Flow
- `PermissionService`: Centralizes granted/missing permission checks
- `PermissionAssistant`: Opens the correct System Settings pane and overlays guidance only after an explicit user action
- `PermissionRequirementsWindowController`: Explains blocked capture requirements without interrupting app launch

### Static Helpers
- `AnnotationGeometry`: Pure geometry calculations
- `HitTestEngine`: Collision detection algorithms
- `AnnotationTransformer`: Annotation transformations

## File Organization

```
PeekOCR/
├── Models/
│   ├── Annotations/     # Annotation data types
│   └── State/           # Observable state managers
├── Services/
│   ├── Annotation/      # Editor services
│   ├── Screenshot/      # Image processing
│   ├── HotKey/          # Keyboard shortcuts
│   ├── Permissions/     # Guided permission onboarding
│   └── (root)           # CaptureCoordinator, Gif* services, NativeScreen* wrappers
├── Views/
│   ├── Annotation/      # Editor views
│   │   ├── Canvas/      # Drawing canvas
│   │   ├── Editor/      # Main editor
│   │   └── Toolbar/     # Tool selection
│   ├── Gif/             # GIF clip editor + recording overlay views
│   ├── MenuBar/         # Menu bar popover
│   ├── Permissions/     # Missing-permission onboarding window
│   ├── Settings/        # Preferences
│   └── Components/      # Reusable UI
├── Utils/               # Utilities
│   └── AppLogger        # Centralized logging
├── Managers/            # Singleton managers
└── Extensions/          # Swift extensions
```

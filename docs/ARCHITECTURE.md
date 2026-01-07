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
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                       STATE                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │AnnotationState│ │AppSettings │  │HistoryManager│    │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                     SERVICES                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Capture    │  │ Screenshot  │  │   HotKey    │     │
│  │ Coordinator │  │  Service    │  │  Manager    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      MODELS                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Annotation  │  │CaptureItem  │  │  Settings   │     │
│  │   Tool      │  │             │  │   Models    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

## Data Flow

1. **User Action** → View receives gesture/input
2. **State Update** → Observable state objects publish changes
3. **Service Call** → Services execute business logic
4. **Model Update** → Data models are modified
5. **UI Refresh** → SwiftUI reactively updates views

## Key Patterns

### ObservableObject Pattern
- `AnnotationState`: Manages annotation editor state
- `AppSettings`: Persists user preferences
- `HistoryManager`: Tracks capture history

### Coordinator Pattern
- `CaptureCoordinator`: Orchestrates capture workflow
- `AnnotationWindowController`: Manages editor window lifecycle

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
│   └── HotKey/          # Keyboard shortcuts
├── Views/
│   ├── Annotation/      # Editor views
│   │   ├── Canvas/      # Drawing canvas
│   │   ├── Editor/      # Main editor
│   │   └── Toolbar/     # Tool selection
│   ├── MenuBar/         # Menu bar popover
│   ├── Settings/        # Preferences
│   └── Components/      # Reusable UI
└── Extensions/          # Swift extensions
```

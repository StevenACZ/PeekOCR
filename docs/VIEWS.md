# Views Structure

Tree of views organized by module.

## View Hierarchy

```
PeekOCRApp
├── MenuBarPopoverView          # Menu bar interface
│   ├── HeaderSection
│   ├── QuickActionsSection
│   │   ├── MenuBarActionButton (OCR)
│   │   ├── MenuBarActionButton (Screenshot)
│   │   └── MenuBarActionButton (GIF Clip)
│   ├── HistorySection
│   │   ├── HistoryItemRow
│   │   └── EmptyStateView
│   └── FooterSection
│
├── SettingsView               # Preferences window
│   ├── GeneralSettingsTab
│   ├── ShortcutsSettingsTab
│   │   └── ShortcutRecorderRow
│   ├── ScreenshotSettingsTab
│   │   ├── ImageFormatSection
│   │   ├── ImageScaleSection
│   │   └── AnnotationDefaultsSection
│   ├── HistorySettingsTab
│   └── AboutTab
│
├── AnnotationEditorView       # Screenshot editor
│   ├── AnnotationToolbar
│   │   ├── ToolsSection
│   │   │   └── ToolButton
│   │   ├── ColorPaletteView
│   │   ├── StrokeWidthPicker
│   │   ├── ActionButtonsSection
│   │   │   └── ActionIconButton
│   │   └── SaveCancelSection
│   │
│   └── AnnotationCanvasView
│       ├── Canvas (drawing)
│       │   └── AnnotationRenderer
│       ├── SelectionHandlesView
│       └── TextInputOverlay
│
└── GifClipEditorView (window) # GIF post-record editor
    ├── GifClipVideoPreviewView
    │   └── NonInteractiveVideoPlayer
    ├── GifClipTimelineView
    │   ├── RangeSlider
    │   └── GifClipTimelineReadoutView
    ├── GifClipPlaybackControlsView
    ├── GifClipSidebarView
    └── GifExportLoadingOverlay
```

## Module Breakdown

### MenuBar (`Views/MenuBar/`)
| View | Description |
|------|-------------|
| `MenuBarPopoverView` | Main popover container |
| `MenuBarActionButton` | Quick action button |
| `HistoryItemRow` | Capture history item |
| `EmptyStateView` | Empty list placeholder |

### Annotation Editor (`Views/Annotation/`)

**Canvas** (`Canvas/`)
| View | Description |
|------|-------------|
| `AnnotationCanvasView` | Main drawing canvas |
| `AnnotationRenderer` | Draws annotations |
| `SelectionHandlesView` | Selection UI |
| `TextInputOverlay` | Text entry field |

**Editor** (`Editor/`)
| View | Description |
|------|-------------|
| `AnnotationEditorView` | Main editor container |
| `KeyboardEventHandler` | Keyboard shortcuts |
| `CGContextAnnotationRenderer` | Export rendering |

**Toolbar** (`Toolbar/`)
| View | Description |
|------|-------------|
| `AnnotationToolbar` | Main toolbar |
| `ToolButton` | Tool selection button |
| `ActionIconButton` | Action button |
| `ShortcutKeyBadge` | Shortcut display |

### Settings (`Views/Settings/`)

**Tabs** (`Tabs/`)
| View | Description |
|------|-------------|
| `GeneralSettingsTab` | General preferences |
| `ShortcutsSettingsTab` | Hotkey configuration |
| `ScreenshotSettingsTab` | Screenshot options |
| `HistorySettingsTab` | History settings |
| `AboutTab` | App information |

**Sections** (`Sections/`)
| View | Description |
|------|-------------|
| `SaveOptionsSection` | Save toggles |
| `SaveLocationSection` | Location picker |
| `ImageFormatSection` | Format + quality |
| `ImageScaleSection` | Scale slider |
| `HotkeyDisplaySection` | Shows configured hotkeys |
| `AnnotationDefaultsSection` | Annotation defaults |

### GIF Clip (`Views/Gif/`)
Post-record editor + recording overlay.

| View | Description |
|------|-------------|
| `GifClipEditorView` | Main editor window content |
| `GifClipVideoPreviewView` | Video preview container |
| `GifClipPlaybackControlsView` | Playback + stepping controls |
| `GifClipTimelineView` | Timeline trimming UI |
| `GifClipTimelineReadoutView` | In/Out + duration readout |
| `GifClipSidebarView` | Export options + output + estimates |
| `GifExportLoadingOverlay` | Export loading UI |
| `Overlay/GifRecordingOverlayView` | Full-screen selection overlay |
| `Overlay/GifRecordingHudView` | Recording HUD (countdown + stop) |

### Components (`Views/Components/`)
Reusable components. See [COMPONENTS.md](./COMPONENTS.md).

## View Responsibilities

### Container Views
- Compose child views
- Manage layout
- Pass state down

### Section Views
- Group related controls
- Handle section-specific logic
- Usually private structs

### Component Views
- Reusable across modules
- Parameterized behavior
- Stateless when possible

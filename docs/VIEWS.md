# Views Structure

Tree of views organized by module.

## View Hierarchy

```
PeekOCRApp
├── MenuBarPopoverView          # Menu bar interface
│   ├── HeaderSection
│   ├── PermissionReminderSection
│   │   └── PermissionSummaryBanner
│   ├── QuickActionsSection
│   │   ├── MenuBarActionButton (OCR)
│   │   ├── MenuBarActionButton (Screenshot)
│   │   └── MenuBarActionButton (Clip)
│   ├── HistorySection
│   │   ├── HistoryItemRow
│   │   └── EmptyStateView
│   └── FooterSection
│
├── SettingsView               # Preferences window
│   ├── GeneralSettingsTab
│   │   └── PermissionStatusRow
│   ├── ShortcutsSettingsTab
│   │   └── ShortcutRecorderRow
│   ├── ScreenshotSettingsTab
│   │   ├── ImageFormatSection
│   │   ├── ImageScaleSection
│   │   └── AnnotationDefaultsSection
│   ├── ClipSettingsTab
│   ├── HistorySettingsTab
│   └── AboutTab
│
├── AnnotationEditorView       # Legacy post-capture screenshot editor
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
├── LiveAnnotationOverlayView  # Full-screen pre-capture annotation overlay
│
├── PermissionRequirementsView # Permission onboarding window
│   ├── PermissionRequirementsIntroView
│   └── PermissionRequirementCard
│
└── GifClipEditorView (window) # GIF post-record editor
    ├── GifClipVideoPreviewView
    │   └── NonInteractiveVideoPlayer
    ├── GifClipTimelineView
    │   ├── RangeSlider
    │   └── GifClipTimelineReadoutView
    ├── GifClipPlaybackControlsView
    ├── GifClipSidebarView
    └── ClipExportOverlay
```

## Module Breakdown

### MenuBar (`Views/MenuBar/`)
| View | Description |
|------|-------------|
| `MenuBarPopoverView` | Main popover container |
| `PermissionSummaryBanner` | Missing-permissions reminder shown above quick actions |
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

**Overlay** (`Overlay/`)
| View | Description |
|------|-------------|
| `LiveAnnotationOverlayView` | Full-screen live pre-capture annotation surface with inline move/edit/resize, contextual cursor handling, and lightweight undo |

### Settings (`Views/Settings/`)

**Tabs** (`Tabs/`)
| View | Description |
|------|-------------|
| `GeneralSettingsTab` | General preferences |
| `ShortcutsSettingsTab` | Hotkey configuration |
| `ScreenshotSettingsTab` | Screenshot options |
| `ClipSettingsTab` | Clip recording + export defaults |
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

### Permissions (`Views/Permissions/`)
Guided permission onboarding surfaces.

| View | Description |
|------|-------------|
| `PermissionRequirementsView` | Fixed-size window content shown when capture is blocked, keeping both permissions visible with live state |
| `PermissionRequirementsIntroView` | Intro/header block that summarizes pending vs ready permission status |
| `PermissionRequirementCard` | Per-permission card that can show either activation or green success state |

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
| `ClipExportOverlay` | Export overlay (loading + success) |
| `Overlay/GifRecordingOverlayView` | Full-screen selection overlay |
| `Overlay/GifRecordingHudView` | Recording HUD (timer + stop) |

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

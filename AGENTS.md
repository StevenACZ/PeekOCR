# AGENTS.md - PeekOCR

## Project Overview

PeekOCR is a native macOS Menu Bar application for OCR text capture, QR code detection, and screenshots. Built with Swift 5.9, SwiftUI, and AppKit.

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

### Run the App

```bash
# Build and run from terminal
xcodebuild -project PeekOCR.xcodeproj -scheme PeekOCR -configuration Debug build && open ~/Library/Developer/Xcode/DerivedData/PeekOCR-*/Build/Products/Debug/PeekOCR.app
```

## Project Structure

```
PeekOCR/
├── PeekOCRApp.swift              # Entry point with @main
├── AppDelegate.swift             # Menu bar setup, popover
├── Constants.swift               # App-wide constants (UI, History, App info)
├── Info.plist                    # LSUIElement, permissions
├── Extensions/                   # Shared utilities & extensions
│   ├── CaptureType+Display.swift # Display properties (color, label) for CaptureType
│   └── HotKeyDisplay.swift       # Hotkey display utilities (modifiers, key codes)
├── Models/                       # Data models
│   ├── AppState.swift            # Global observable state
│   ├── AppSettings.swift         # UserDefaults wrapper (hotkeys, launch settings)
│   ├── CaptureItem.swift         # History item model (text, qrCode, screenshot)
│   ├── ScreenshotSettings.swift  # Screenshot preferences
│   ├── SaveLocation.swift        # Enum for save locations (desktop, downloads, etc.)
│   └── ImageFormat.swift         # Enum for image formats (PNG, JPG, TIFF, HEIC)
├── Services/                     # Business logic
│   ├── CaptureCoordinator.swift        # Orchestrates capture flow
│   ├── NativeScreenCaptureService.swift # macOS native screencapture -i
│   ├── HotKeyManager.swift             # Carbon global hotkeys
│   ├── OCRService.swift                # Vision framework OCR
│   ├── ScreenshotService.swift         # Screenshot processing & saving
│   └── PasteboardService.swift         # Clipboard operations
├── Managers/                     # State managers
│   ├── HistoryManager.swift            # Last 6 captures
│   └── LaunchAtLoginManager.swift      # SMAppService
└── Views/                        # UI
    ├── MenuBarPopoverView.swift        # Main dropdown menu
    ├── SettingsView.swift              # Settings window container
    ├── Components/                     # Reusable UI components
    │   ├── ShortcutRecorderRow.swift   # Keyboard shortcut recorder
    │   └── PermissionStatusRow.swift   # Permission status indicator
    └── Settings/                       # Settings tabs
        ├── GeneralSettingsTab.swift
        ├── ShortcutsSettingsTab.swift
        ├── ScreenshotSettingsTab.swift
        ├── HistorySettingsTab.swift
        └── AboutTab.swift
```

## Key Architecture Decisions

### Menu Bar Only App

- `LSUIElement = true` in Info.plist hides from Dock
- Uses NSStatusItem for menu bar presence
- NSPopover for dropdown menu

### Native Screen Capture

- Uses macOS native `screencapture -i` command for all capture modes
- Provides familiar UI with Retina resolution support
- Temporary file handling with cleanup

### Global Hotkeys

- Uses Carbon EventHotKey API (more reliable than NSEvent)
- Requires Accessibility permission
- Default: `⇧ Space` (OCR), `⌘⇧4` (Screenshot)

### No Sandbox

- Disabled for screen capture and global hotkeys
- Required permissions: Screen Recording, Accessibility

### macOS Compatibility

- Target: macOS 13.0+
- `SettingsLink`: macOS 14+ (fallback for 13)

### Centralized Constants

All magic numbers and repeated values are centralized in `Constants.swift`:

```swift
Constants.UI.popoverWidth        // 320
Constants.UI.historyMaxHeight    // 180
Constants.History.maxItems       // 6
Constants.History.maxPreviewLength // 50
Constants.App.version            // "1.0.0"
Constants.App.minimumOSVersion   // "macOS 13.0+"
```

### Reusable Components

UI components that are used in multiple places are extracted to `Views/Components/`:

- `ShortcutRecorderRow` - For recording keyboard shortcuts
- `PermissionStatusRow` - For displaying permission status with action button

### Extensions for Display Logic

Display-related logic is centralized in extensions:

- `CaptureType+Display.swift` - `displayColor` and `displayLabel` properties
- `HotKeyDisplay.swift` - `displayString()` and `carbonModifiers()` utilities

## Capture Modes

| Mode       | Hotkey    | Action                                             |
| ---------- | --------- | -------------------------------------------------- |
| OCR        | `⇧ Space` | Extract text from screen region, copy to clipboard |
| Screenshot | `⌘⇧4`     | Save image to file, optionally copy to clipboard   |

### Capture Types in History

| Type          | Color  | Description         |
| ------------- | ------ | ------------------- |
| `.text`       | Blue   | OCR text extraction |
| `.qrCode`     | Purple | QR code detection   |
| `.screenshot` | Green  | Screenshot capture  |

## Code Style Guidelines

### Patterns Used

- **Singleton pattern** for shared services (`static let shared`)
- **ObservableObject** for reactive SwiftUI state
- **Coordinator pattern** for capture flow orchestration
- **Extension pattern** for adding display properties to enums

### Naming Conventions

- Services: `*Service.swift` (business logic)
- Managers: `*Manager.swift` (state management)
- Views: `*View.swift` or `*Tab.swift`
- Components: Reusable views in `Views/Components/`
- Extensions: `TypeName+Feature.swift`

### Import Order

```swift
import Foundation
import AppKit      // or SwiftUI
import Combine
import Vision      // Framework-specific
```

## Testing Instructions

### Manual Testing Checklist

- [ ] App appears in menu bar with eye icon
- [ ] Click menu bar icon shows popover
- [ ] `⇧ Space` triggers native capture for OCR
- [ ] `⌘⇧4` triggers native capture for screenshot
- [ ] QR codes are detected automatically
- [ ] Captured text copies to clipboard
- [ ] Screenshots save to configured location
- [ ] History shows last 6 captures with correct colors/labels
- [ ] Settings window opens correctly (height: 450px)
- [ ] Hotkey customization works
- [ ] Image scale slider works (10%-100%)

### Permissions Testing

- [ ] Screen Recording permission prompt appears
- [ ] Accessibility permission prompt appears
- [ ] App functions after permissions granted

## Common Issues & Fixes

### Screen capture returns nil

Check Screen Recording permission in System Preferences > Privacy & Security.

### Hotkeys not working

1. Check Accessibility permission
2. Try re-registering hotkeys in Settings

### Build errors with Combine

Ensure `import Combine` is present in files using `@Published` or `ObservableObject`.

### Info.plist warning

Already fixed with PBXFileSystemSynchronizedBuildFileExceptionSet in project.pbxproj.

## Git Workflow

### Commit Message Format

```
<type>: <description>

Types: feat, fix, refactor, style, docs, chore
```

### Before Committing

```bash
# Build to verify no errors
xcodebuild -scheme PeekOCR build

# Check status
git status
```

## Frameworks Used

| Framework              | Purpose                         |
| ---------------------- | ------------------------------- |
| SwiftUI                | Settings UI, Popover content    |
| AppKit                 | Menu bar, Window management     |
| Vision                 | OCR, QR detection               |
| Carbon                 | Global hotkeys                  |
| CoreGraphics           | Image processing, scaling       |
| UniformTypeIdentifiers | Image format handling (PNG/JPG) |
| ServiceManagement      | Launch at login                 |

## Future Improvements

- [ ] Notification when text copied
- [ ] Sound feedback option
- [ ] Custom app icon design
- [ ] Localization (en, es)
- [ ] Export history to file
- [ ] Drag & drop image for OCR

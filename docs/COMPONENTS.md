# Reusable Components

Catalog of reusable SwiftUI components in `Views/Components/`.

## General Components

### SectionHeader
Section title with uppercase styling.

```swift
SectionHeader(title: "Tools")
```

### SectionDivider
Visual separator between sections.

```swift
SectionDivider()
```

### SettingSliderRow
Slider with label, value display, and optional indicators.

```swift
SettingSliderRow(
    title: "Scale",
    icon: "arrow.up.left.and.arrow.down.right",
    value: $scale,
    range: 10...100,
    step: 10,
    displayFormatter: { "\(Int($0))%" },
    indicators: ["10%", "50%", "100%"]
)
```

### ShortcutRecorderRow
Row for recording keyboard shortcuts.

```swift
ShortcutRecorderRow(
    title: "Capture",
    keyCode: $keyCode,
    modifiers: $modifiers,
    onRecord: { /* handle */ }
)
```

### PermissionStatusRow
Displays permission status with action button.

```swift
PermissionStatusRow(
    title: "Screen Recording",
    isGranted: isGranted,
    onRequest: { /* request permission */ }
)
```

## Video / GIF Components

### NonInteractiveVideoPlayer
Preview-only video player (AVPlayerView) with controls disabled.

```swift
NonInteractiveVideoPlayer(player: player)
```

### RangeSlider
Dual-handle slider used for selecting a numeric range (e.g. GIF trim in/out).

```swift
RangeSlider(
    lowerValue: $startSeconds,
    upperValue: $endSeconds,
    bounds: 0...durationSeconds,
    step: 0.1,
    minimumDistance: Constants.Gif.minimumClipDurationSeconds
)
```

## Annotation Components

### ToolButton
Button for selecting annotation tools.

```swift
ToolButton(
    tool: .arrow,
    isSelected: selectedTool == .arrow
) {
    selectedTool = .arrow
}
```

### ActionIconButton
Icon button with hover effects.

```swift
ActionIconButton(
    icon: "arrow.uturn.backward",
    label: "Undo",
    shortcut: "⌘Z",
    isEnabled: canUndo,
    action: { state.undo() }
)
```

### ShortcutKeyBadge
Small badge showing keyboard shortcut.

```swift
ShortcutKeyBadge(key: "1")
```

### ColorPaletteView
Color picker with predefined palette.

```swift
ColorPaletteView(selectedColor: $color)
```

### StrokeWidthPicker
Stroke width slider with preview.

```swift
StrokeWidthPicker(strokeWidth: $width)
```

## MenuBar Components

### MenuBarActionButton
Action button with icon and shortcut.

```swift
MenuBarActionButton(
    title: "Capture Text",
    icon: "doc.text.viewfinder",
    shortcut: "⇧ Space"
) {
    /* action */
}
```

### HistoryItemRow
Row displaying capture history item.

```swift
HistoryItemRow(item: item) {
    historyManager.copyItem(item)
}
```

### EmptyStateView
Placeholder for empty lists.

```swift
EmptyStateView(
    icon: "doc.text.magnifyingglass",
    message: "No recent captures"
)
```

## Canvas Components

### TextInputOverlay
Floating text field for text annotations.

```swift
TextInputOverlay(
    text: $text,
    position: position,
    color: .red,
    fontSize: 16,
    onCommit: { /* save */ },
    onCancel: { /* cancel */ }
)
```

## Settings Sections

Modular sections for settings tabs in `Views/Settings/Sections/`.

### HotkeyDisplaySection
Displays the current hotkey configuration.

```swift
HotkeyDisplaySection(appSettings: AppSettings.shared)
```

### SaveOptionsSection
Toggle controls for clipboard and file save.

```swift
SaveOptionsSection(settings: ScreenshotSettings.shared)
```

### SaveLocationSection
Picker for save location with custom folder support.

```swift
SaveLocationSection(settings: ScreenshotSettings.shared)
```

### ImageFormatSection
Format picker with quality slider for JPG.

```swift
ImageFormatSection(settings: ScreenshotSettings.shared)
```

### ImageScaleSection
Slider for output image scale percentage.

```swift
ImageScaleSection(settings: ScreenshotSettings.shared)
```

### AnnotationDefaultsSection
Sliders for default stroke width and font size.

```swift
AnnotationDefaultsSection(appSettings: AppSettings.shared)
```

## Adding New Components

1. Create file in `Views/Components/` or `Views/Settings/Sections/`
2. Add English description comment at top
3. Keep under 80 lines if possible
4. Make it reusable with parameters
5. Add `#Preview` for visual testing

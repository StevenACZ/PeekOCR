<h1 align="center">👁️ PeekOCR</h1>

<p align="center">
  <strong>OCR, screenshots, GIF clips, and annotations — from your macOS menu bar</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 13+"/>
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.9"/>
  <img src="https://img.shields.io/badge/License-MIT-34C759?style=for-the-badge" alt="MIT License"/>
</p>

---

## ✨ What is PeekOCR?

PeekOCR is a macOS menu bar app that lets you quickly **select an area of your screen** to:

- copy extracted text (OCR) to the clipboard,
- save screenshots (optionally annotated),
- and record short **GIF clips** (ideal for sharing UI bugs/animations).

### 🎯 Features

| Feature                  | Description                                        |
| ------------------------ | -------------------------------------------------- |
| 📸 **OCR Capture**       | Select an area and copy the extracted text         |
| 🔗 **QR Detection**      | Detect and copy QR contents                        |
| 📷 **Screenshots**       | Save images with configurable format/quality/scale |
| ✍️ **Live Annotation Capture** | Select, adjust, annotate in-place, then export      |
| 🎞️ **GIF Clip Capture**  | Record up to 10s, trim, preview, and export as GIF |
| 🕘 **History**           | Quickly access your last 6 captures                |
| ⌨️ **Hotkeys**           | Customize global shortcuts in Settings             |

---

## 🚀 Installation

1. Download the latest version from [Releases](https://github.com/StevenACZ/PeekOCR/releases)
2. Open the DMG and drag `PeekOCR.app` to your Applications folder
3. Launch PeekOCR
4. Grant the required permissions when prompted

---

## ⌨️ How to Use

### Default Keyboard Shortcuts

All shortcuts can be changed in Settings.

| Action                         | Shortcut  |
| ------------------------------ | --------- |
| **Capture text (OCR)**         | `⇧ Space` |
| **Capture screenshot**         | `⌘⇧4`     |
| **Capture with annotations**   | `⌘⇧5`     |
| **Capture GIF clip (max 10s)** | `⌘⇧6`     |

### Quick Start

**OCR**

1. Press `⇧ Space`
2. Drag to select a region
3. The extracted text is copied to your clipboard

**Annotated screenshot**

1. Press `⌘⇧5`
2. Drag to create the capture area
3. Adjust the selection by dragging corners or moving the region
4. Add arrows, text, or highlights directly on the live overlay
5. Move existing annotations inline, resize highlight boxes, and edit text with double click
6. Use `⌘Z` to undo the last live annotation change
7. Press `Enter` to capture and export the final annotated image

**GIF Clip**

1. Press `⌘⇧6`
2. Select a region
3. Record (auto-stops at 10s or stop early)
4. Trim in/out in the editor and export as a GIF

---

## 🔐 Permissions

PeekOCR needs two permissions to work properly:

| Permission           | Why                     |
| -------------------- | ----------------------- |
| **Screen Recording** | Capture screen content  |
| **Accessibility**    | Register global hotkeys |

> Tip: PeekOCR will guide you to enable these the first time you use a capture mode.

---

## 💻 Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

---

## ⚡ Performance and Stability

PeekOCR is designed to live in the macOS menu bar for long periods, so the project now prioritizes:

- OCR and image processing off the UI-critical path
- lower transient memory usage during screenshot save/export
- cleanup of temporary/partial export files on failures
- no leaked keyboard event monitors in settings
- fewer long-running polling timers in resident UI

## 📚 Documentation

- `AGENTS.md` (project map + conventions)
- `CLAUDE.md` (runtime and implementation guardrails)
- `CHANGELOG.md`
- `docs/ARCHITECTURE.md`
- `docs/SERVICES.md`
- `docs/MODELS.md`
- `docs/VIEWS.md`
- `docs/GIF_CLIP.md`

## 📝 License

MIT License — use and modify freely

---

<p align="center">
  Made with ❤️ for the macOS community
</p>

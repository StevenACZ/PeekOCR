# 👁️ PeekOCR - Especificación Completa del Proyecto

## Visión General

**PeekOCR** es una aplicación nativa de macOS que vive en la **Menu Bar**. Permite capturar texto desde cualquier parte de la pantalla usando OCR, detectar códigos QR, y opcionalmente traducir el texto capturado.

---

## ✅ Especificaciones Confirmadas

| Aspecto          | Valor                  |
| ---------------- | ---------------------- |
| **Nombre**       | PeekOCR                |
| **Plataforma**   | macOS 13.0+ (Ventura)  |
| **Tipo de App**  | Menu Bar (LSUIElement) |
| **Lenguaje**     | Swift 5.9 / SwiftUI    |
| **Distribución** | GitHub Releases        |

---

## Funcionalidades

### 1. 📸 Captura de Texto (OCR)

- **Atajo:** `Shift + Espacio`
- Activa overlay de selección similar a screenshot de Mac
- Detecta automáticamente:
  - **Texto** → extrae con OCR y copia al portapapeles
  - **QR Code** → extrae URL/contenido y copia al portapapeles
- Sin vista previa, sin sonidos, directo y rápido

### 2. 🌐 Captura + Traducción

- **Atajo:** `Control + Shift + Espacio`
- Mismo flujo de captura
- Traduce el texto antes de copiarlo (Apple Translation Framework)
- Default: Inglés → Español
- Idiomas configurables en ajustes

### 3. 📋 Historial

- Guarda las últimas **6 capturas**
- Visible desde menú desplegable
- Click para copiar de nuevo

### 4. ⚙️ Configuración

- Ventana accesible desde el menú
- Opciones:
  - Cambiar atajos de teclado
  - Seleccionar idioma origen/destino
  - Iniciar con macOS (on/off)
  - Limpiar historial

---

## Interfaz de Usuario

### Menu Bar

```
[...otras apps...]  👁️  [wifi] [batería] [hora]
```

### Menú Desplegable

```
┌─────────────────────────────────┐
│  👁️ PeekOCR                     │
├─────────────────────────────────┤
│  📸 Capturar Texto     ⇧Space   │
│  🌐 Traducir Texto    ⌃⇧Space   │
├─────────────────────────────────┤
│  📋 Historial                   │
│     ├─ "Lorem ipsum dol..."  ⏱  │
│     ├─ "Hello world..."      ⏱  │
│     └─ "https://example..."  ⏱  │
├─────────────────────────────────┤
│  ⚙️ Configuración...            │
├─────────────────────────────────┤
│  ❌ Salir                        │
└─────────────────────────────────┘
```

### Ventana de Configuración

```
┌────────────────────────────────────────────────────┐
│  ⚙️ Configuración                            [X]   │
├────────────────────────────────────────────────────┤
│                                                    │
│  ATAJOS DE TECLADO                                 │
│  ┌──────────────────────────────────────────────┐  │
│  │ Capturar Texto:      [ ⇧ Space    ] [Grabar] │  │
│  │ Traducir Texto:      [ ⌃⇧ Space   ] [Grabar] │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  TRADUCCIÓN                                        │
│  ┌──────────────────────────────────────────────┐  │
│  │ Idioma origen:       [ English      ▼]       │  │
│  │ Idioma destino:      [ Español      ▼]       │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  GENERAL                                           │
│  ┌──────────────────────────────────────────────┐  │
│  │ [✓] Iniciar PeekOCR con macOS               │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  HISTORIAL                                         │
│  ┌──────────────────────────────────────────────┐  │
│  │              [Limpiar Historial]             │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
└────────────────────────────────────────────────────┘
```

---

## Arquitectura Técnica

```
PeekOCR/
├── PeekOCRApp.swift              # Entry point, @main
├── AppDelegate.swift             # NSApplicationDelegate, setup menu bar
├── Views/
│   ├── MenuBarView.swift         # NSMenu para el dropdown
│   ├── SettingsView.swift        # SwiftUI settings window
│   └── CaptureOverlayView.swift  # NSWindow transparente para selección
├── Services/
│   ├── HotKeyManager.swift       # Global keyboard shortcuts
│   ├── ScreenCaptureService.swift# Captura de pantalla
│   ├── OCRService.swift          # Vision Framework OCR + QR
│   ├── TranslationService.swift  # Apple Translation
│   └── PasteboardService.swift   # Copy to clipboard
├── Models/
│   ├── CaptureItem.swift         # Modelo para historial
│   └── AppSettings.swift         # UserDefaults wrapper
├── Managers/
│   ├── HistoryManager.swift      # Gestión de últimas 6 capturas
│   └── LaunchAtLoginManager.swift# Iniciar con macOS
├── Resources/
│   └── Assets.xcassets/          # App icon
└── Info.plist
```

---

## Tecnologías y Frameworks

| Componente       | Framework/Tecnología                            |
| ---------------- | ----------------------------------------------- |
| UI Principal     | AppKit (NSStatusItem, NSMenu)                   |
| Settings UI      | SwiftUI                                         |
| OCR              | Vision (`VNRecognizeTextRequest`)               |
| QR Detection     | Vision (`VNDetectBarcodesRequest`)              |
| Traducción       | Apple Translation Framework                     |
| Hotkeys Globales | `CGEvent` / `NSEvent.addGlobalMonitorForEvents` |
| Captura Pantalla | `CGWindowListCreateImage`                       |
| Persistencia     | `UserDefaults`                                  |
| Clipboard        | `NSPasteboard`                                  |
| Launch at Login  | `SMAppService` (macOS 13+)                      |

---

## Permisos Requeridos (Info.plist)

```xml
<!-- Para captura de pantalla -->
<key>NSScreenCaptureUsageDescription</key>
<string>PeekOCR needs screen capture access to extract text from your screen.</string>

<!-- Para que sea Menu Bar only app -->
<key>LSUIElement</key>
<true/>
```

---

## Flujo de Usuario

### Captura de Texto (OCR)

```
1. Usuario presiona Shift + Espacio
2. Aparece overlay semi-transparente sobre toda la pantalla
3. Usuario dibuja rectángulo sobre el área deseada
4. Al soltar el mouse:
   a. Se captura esa región de la pantalla
   b. Se analiza con Vision Framework
   c. Si hay QR → extrae contenido
   d. Si hay texto → extrae texto
5. Resultado se copia al portapapeles
6. Se guarda en historial (máx 6)
7. Overlay desaparece
```

### Captura + Traducción

```
1-4. Igual que arriba
5. Texto extraído se pasa a Apple Translation
6. Texto traducido se copia al portapapeles
7-8. Igual que arriba
```

---

## Atajos de Teclado

| Acción               | Atajo Default                        |
| -------------------- | ------------------------------------ |
| Capturar Texto (OCR) | `⇧ Space` (Shift + Space)            |
| Capturar + Traducir  | `⌃⇧ Space` (Control + Shift + Space) |

_Configurables por el usuario_

---

## Configuración por Defecto

```swift
struct DefaultSettings {
    static let ocrHotkey = "Shift+Space"
    static let translateHotkey = "Control+Shift+Space"
    static let sourceLanguage = "en"
    static let targetLanguage = "es"
    static let launchAtLogin = false
    static let maxHistoryItems = 6
}
```

---

## Idiomas Soportados (Traducción)

Para el MVP:

- English (en)
- Español (es)
- Français (fr)
- Deutsch (de)
- Português (pt)
- Italiano (it)

---

## Instalación y Distribución

1. **Build:** Xcode Archive → Export as App
2. **Distribución:** GitHub Releases como `.zip` o `.dmg`
3. **Requisitos:**
   - macOS 13.0 Ventura o superior
   - Permiso de Screen Recording (se pide automáticamente)
   - Permiso de Accessibility para hotkeys globales

---

## TODO - Orden de Implementación

1. [ ] Crear estructura base del proyecto
2. [ ] AppDelegate + Menu Bar icon
3. [ ] Menú desplegable básico
4. [ ] Sistema de hotkeys globales
5. [ ] Overlay de captura (selección de área)
6. [ ] Servicio de captura de pantalla
7. [ ] OCR con Vision Framework
8. [ ] Detección de QR codes
9. [ ] Copiar al portapapeles
10. [ ] Historial (últimas 6)
11. [ ] Ventana de configuración
12. [ ] Traducción con Apple Translation
13. [ ] Launch at Login
14. [ ] Pulir UI y testing
15. [ ] Preparar para GitHub Release

---

## Notas Adicionales

- La app NO aparece en el Dock (LSUIElement = true)
- La app SÍ aparece en la Menu Bar con un icono 👁️
- El usuario puede abrir Configuración desde el menú
- El historial muestra texto truncado con timestamp
- Si hay conflicto de hotkeys, mostrar alerta

---

**Listo para implementar** 🚀

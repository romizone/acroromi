<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS_14+-blue?style=for-the-badge&logo=apple&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange?style=for-the-badge&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/UI-SwiftUI-blue?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Dependencies-Zero-brightgreen?style=for-the-badge" alt="Zero Dependencies">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License">
</p>

<h1 align="center">🐧 Acroromi</h1>
<h3 align="center">Native macOS PDF Application — Powerful, Portable, Zero Dependencies</h3>

<p align="center">
  <em>A full-featured PDF editor, viewer, and toolkit built entirely with Apple frameworks.</em><br>
  <em>No Homebrew. No pip. No npm. No Tesseract. Just drag, drop, and go.</em>
</p>

---

## 🎯 Overview

**Acroromi** is a native macOS PDF application that rivals commercial PDF editors — built from scratch using **Swift + SwiftUI** with **zero external dependencies**. Everything runs on Apple's built-in frameworks (PDFKit, Vision, Core Graphics, WebKit), making it truly portable.

📦 **Distributed as a DMG** — drag to Applications, done. Works on any Mac running macOS 14+.

---

## ✨ Features at a Glance

| # | Feature | Description | Framework |
|:-:|---------|-------------|-----------|
| 📖 | **PDF Viewer** | Smooth scrolling, zoom, multi-page layouts, text search | PDFKit |
| 🖍️ | **Annotations** | Highlight, underline, strikethrough, sticky notes, freehand drawing, shapes | PDFKit |
| ✏️ | **Text Editor** | Click-to-edit existing text, add new text with font/color/size picker | PDFKit + AppKit |
| 🔄 | **Converter** | PDF ↔ Images, HTML → PDF, PDF → Text extraction | Core Graphics + WebKit |
| 📑 | **Page Organizer** | Merge, split, rotate, reorder, delete, extract pages | PDFKit |
| 📝 | **Form Filler** | Detect and fill AcroForm fields, checkboxes, dropdowns | PDFKit |
| ✍️ | **Signatures** | Draw or type signatures, save for reuse | PDFKit + AppKit |
| 📧 | **E-Signatures** | Place signature fields, track signature requests | PDFKit |
| 🔒 | **Security** | Password protection, user/owner passwords, permissions | PDFKit |
| 🟥 | **Redaction** | Mark & permanently redact sensitive text or areas | Core Graphics |
| 📊 | **Compare** | Side-by-side text diff and visual pixel comparison | PDFKit + Core Graphics |
| 🔍 | **OCR** | Recognize text in scanned/image pages (18+ languages) | Vision |

---

## 📸 Screenshots

> 🚧 *Screenshots coming soon — build and try it yourself!*

---

## 🚀 Quick Start

### 📋 Requirements

| Requirement | Version |
|-------------|---------|
| 🍎 macOS | 14.0 (Sonoma) or later |
| 🔧 Swift | 5.9+ |
| 📦 Xcode CLT | Xcode 15+ Command Line Tools |

### ⚡ Build & Run

```bash
# Clone the repository
git clone https://github.com/romizone/acroromi.git
cd acroromi

# Build with Swift Package Manager
swift build

# Run directly
swift run

# Or build the .app bundle + DMG
bash build-app.sh
open .build/Acroromi.app
```

### 📀 Install from DMG

```bash
bash build-app.sh
# Output: .build/Acroromi.dmg
# Double-click the DMG → drag Acroromi.app to Applications
```

---

## 🏗️ Architecture

### 🧱 Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| 🎨 **UI Framework** | SwiftUI | Declarative, modern UI |
| 📄 **PDF Engine** | PDFKit | View, annotate, edit, forms |
| 👁️ **OCR Engine** | Vision (VNRecognizeTextRequest) | On-device ML text recognition |
| 🖼️ **Rendering** | Core Graphics | PDF manipulation, image conversion |
| 🌐 **Web → PDF** | WebKit (WKWebView) | HTML to PDF conversion |
| 📦 **Build System** | Swift Package Manager | No Xcode project needed |
| 🔗 **Dependencies** | **None** | 100% Apple frameworks |

### 📁 Project Structure

```
acroromi/
├── 📦 Package.swift                    # SPM manifest (macOS 14+, zero deps)
├── 📋 Info.plist                       # App metadata & file associations
├── 🔨 build-app.sh                    # Build .app bundle + DMG
├── 🐧 GenerateIcon.swift              # App icon generator (Red Penguin!)
│
└── 📂 Sources/Acroromi/
    ├── 🚀 AcroromiApp.swift            # @main entry point + app delegate
    ├── 🧠 AppState.swift               # Root app state (@Observable)
    ├── 🖥️ ContentView.swift            # Main layout (NavigationSplitView)
    │
    ├── 📂 Core/
    │   ├── 📄 PDFViewWrapper.swift     # NSViewRepresentable ↔ PDFView bridge
    │   ├── ✏️ EditablePDFView.swift    # Click-to-edit PDFView subclass
    │   ├── 📋 DocumentState.swift      # Per-document state management
    │   ├── 📁 PDFDocumentManager.swift # File open/save/recent documents
    │   └── ⚙️ Constants.swift          # App-wide constants
    │
    ├── 📂 UI/
    │   ├── 📊 SidebarView.swift        # Thumbnails, bookmarks, annotations
    │   ├── 🖼️ ThumbnailView.swift      # Scrollable page thumbnail strip
    │   ├── 🔧 ToolbarView.swift        # Main toolbar controls
    │   ├── 📏 StatusBarView.swift      # Page count & zoom display
    │   ├── 🔍 SearchBarView.swift      # Text search with navigation
    │   ├── 👋 WelcomeView.swift        # Drag-drop landing page
    │   └── 🎨 Styles.swift             # Shared visual styles
    │
    ├── 📂 Features/
    │   ├── 📖 Viewer/                  # PDF viewing, navigation, print
    │   ├── 🖍️ Annotations/            # Highlight, notes, drawing, shapes
    │   ├── ✏️ Editor/                  # Text & image editing
    │   ├── 🔄 Converter/              # Format conversion (images, HTML, text)
    │   ├── 📑 Organizer/              # Merge, split, rotate, reorder pages
    │   ├── 📝 FormSign/               # Form filling & signatures
    │   ├── 📧 ESignature/             # E-signature request management
    │   ├── 🔒 Security/               # Password protection & permissions
    │   ├── 🟥 Redaction/              # Sensitive content redaction
    │   ├── 📊 Compare/                # Document comparison (text + visual)
    │   └── 🔍 OCR/                    # Optical Character Recognition
    │
    └── 📂 Models/
        └── 🔧 ToolMode.swift           # Tool mode & sidebar enums
```

---

## 📖 Feature Details

### 📖 1. PDF Viewer
- 🔎 Smooth zoom in/out with pinch and keyboard shortcuts (`⌘+`, `⌘-`, `⌘0`)
- 📄 Display modes: Single Page, Continuous, Two-Up, Two-Up Continuous
- 🔍 Full-text search with result highlighting and navigation
- 🖨️ Native macOS print dialog integration
- 📑 Page navigation via sidebar thumbnails or keyboard (`⌘↑`, `⌘↓`)
- 📂 Drag & drop PDF files to open

### 🖍️ 2. Annotations
- 🟡 **Highlight** — yellow, green, blue, pink highlighting
- ➖ **Underline** — underline important text
- ~~📝~~ **Strikethrough** — cross out text
- 📌 **Sticky Notes** — add text notes anywhere on the page
- ✏️ **Freehand Drawing** — ink annotations with adjustable width
- 🔷 **Shapes** — rectangles, circles, lines, arrows
- 🎨 **Color Picker** — customizable annotation colors
- 📋 **Annotations Panel** — list all annotations in sidebar

### ✏️ 3. Text Editor
- 🖱️ **Click-to-Edit** — click any text on the PDF to edit inline
- ➕ **Add New Text** — place new text annotations anywhere
- 🔤 **Font Picker** — 14 font families (Helvetica, Times, Courier, Arial, Georgia, Verdana, Futura, Avenir, Menlo, Palatino, American Typewriter...)
- 📏 **Font Size** — adjustable from 8pt to 72pt
- 🎨 **Font Color** — full color picker for text color
- 👁️ **Live Preview** — see your text styled before adding
- 🔍 **Smart Detection** — auto-detects existing font, size, color, and alignment
- ↩️ **Undo** — remove last edit
- ⌨️ **Keyboard** — Enter to apply, Esc to cancel, Tab to commit

### 🔄 4. Converter
- 🖼️ **Images → PDF** — convert PNG, JPG, TIFF, HEIC to PDF
- 📄 **PDF → Images** — export pages as images (configurable DPI: 72–600)
- 🌐 **HTML → PDF** — convert web pages to PDF via WebKit
- 📝 **PDF → Text** — extract all text content to TXT file

### 📑 5. Page Organizer
- 🔀 **Merge** — combine multiple PDF files into one
- ✂️ **Split** — split PDF by page ranges
- 🔄 **Rotate** — rotate pages 90°/180°/270°
- 🗑️ **Delete** — remove unwanted pages
- 📤 **Extract** — extract selected pages to new PDF
- 🖱️ **Drag & Reorder** — rearrange pages with drag-and-drop thumbnail grid

### 📝 6. Form Filler & Signatures
- 📋 **Auto-detect** AcroForm widget fields
- ✍️ **Fill** text fields, checkboxes, radio buttons, dropdowns
- ✒️ **Draw Signature** — freehand signature pad
- ⌨️ **Type Signature** — type your name in signature style
- 💾 **Save Signatures** — reuse saved signatures across documents

### 🔒 7. Security & Protection
- 🔑 **User Password** — require password to open PDF
- 🔐 **Owner Password** — restrict printing, copying, editing
- 🛡️ **Permission Control** — granular access restrictions
- 🔓 **Unlock** — decrypt password-protected PDFs

### 🟥 8. Redaction
- 🖱️ **Mark Areas** — select regions to redact
- 🔍 **Search & Redact** — find text patterns and redact all matches
- ⚫ **Permanent Removal** — flatten redacted areas (bitmap approach, unrecoverable)
- ⚠️ **Confirmation** — safety prompt before applying irreversible redaction

### 📊 9. Compare Documents
- 📄 **Text Diff** — LCS-based text comparison with additions/deletions highlighted
- 🖼️ **Visual Diff** — pixel-level page comparison overlay
- ↔️ **Side-by-Side** — split pane view of both documents
- 🎨 **Color Coded** — green for additions, red for deletions, yellow for changes

### 🔍 10. OCR (Optical Character Recognition)
- 🧠 **On-device ML** — powered by Apple Vision framework, no internet needed
- 🌍 **18+ Languages** — English, Indonesian, Malay, French, German, Spanish, Italian, Portuguese, Dutch, Japanese, Korean, Chinese (Simplified & Traditional), Russian, Arabic, Thai, Vietnamese, Hindi
- ⚡ **Fast or Accurate** — choose recognition speed vs. accuracy
- 📄 **Smart Skip** — automatically skips pages that already have selectable text (no duplicates)
- 🖼️ **Import Images** — import image files as scanned PDF pages
- 🔍 **Searchable** — OCR text becomes searchable and selectable

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘O` | Open PDF |
| `⌘S` | Save |
| `⇧⌘S` | Save As |
| `⌘W` | Close (with save prompt) |
| `⌘P` | Print |
| `⌘F` | Find / Search |
| `⌘+` | Zoom In |
| `⌘-` | Zoom Out |
| `⌘0` | Actual Size (100%) |
| `⌘↑` | Previous Page |
| `⌘↓` | Next Page |

---

## 🐧 About the Icon

Acroromi features a cute **Red Penguin** mascot holding a PDF document — generated programmatically using pure Swift + Core Graphics. No image assets needed!

---

## 🛠️ Build System

The project uses **Swift Package Manager** — no `.xcodeproj` or `.xcworkspace` needed.

```swift
// Package.swift
let package = Package(
    name: "Acroromi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Acroromi", path: "Sources/Acroromi")
    ]
)
```

### 📀 DMG Distribution

```bash
bash build-app.sh
```

This script:
1. ⚡ Builds the Swift project in release mode
2. 📦 Creates a proper `.app` bundle with `Info.plist`
3. 🐧 Includes the Red Penguin app icon
4. 📀 Packages everything as a distributable DMG
5. ✅ Ready to drag-and-drop install on any Mac

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

1. 🍴 Fork the repository
2. 🌿 Create a feature branch (`git checkout -b feature/amazing-feature`)
3. 💾 Commit your changes (`git commit -m 'Add amazing feature'`)
4. 📤 Push to the branch (`git push origin feature/amazing-feature`)
5. 🔃 Open a Pull Request

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- 🍎 **Apple** — for PDFKit, Vision, Core Graphics, and WebKit frameworks
- 🐧 **Acroromi Penguin** — our adorable red mascot
- 🤖 **Claude** — AI-assisted development

---

<p align="center">
  <strong>🐧 Built with ❤️ using 100% Apple frameworks</strong><br>
  <em>No dependencies. No nonsense. Just PDF power.</em>
</p>

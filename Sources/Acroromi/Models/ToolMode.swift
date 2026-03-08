import Foundation

enum ToolMode: String, CaseIterable, Identifiable {
    case viewer
    case annotate
    case edit
    case organize
    case formSign
    case redact
    case compare
    case ocr
    case convert
    case protect
    case eSignature

    var id: String { rawValue }

    var label: String {
        switch self {
        case .viewer: return "Viewer"
        case .annotate: return "Annotate"
        case .edit: return "Edit"
        case .organize: return "Organize"
        case .formSign: return "Fill & Sign"
        case .redact: return "Redact"
        case .compare: return "Compare"
        case .ocr: return "OCR"
        case .convert: return "Convert"
        case .protect: return "Protect"
        case .eSignature: return "E-Signature"
        }
    }

    var icon: String {
        switch self {
        case .viewer: return "doc.text"
        case .annotate: return "pencil.and.outline"
        case .edit: return "pencil"
        case .organize: return "rectangle.stack"
        case .formSign: return "signature"
        case .redact: return "eye.slash"
        case .compare: return "doc.on.doc"
        case .ocr: return "text.viewfinder"
        case .convert: return "arrow.triangle.2.circlepath"
        case .protect: return "lock.shield"
        case .eSignature: return "pencil.and.list.clipboard"
        }
    }
}

enum AnnotationTool: String, CaseIterable, Identifiable {
    case highlight
    case underline
    case strikethrough
    case stickyNote
    case freeText
    case ink
    case rectangle
    case circle
    case line
    case arrow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .highlight: return "Highlight"
        case .underline: return "Underline"
        case .strikethrough: return "Strikethrough"
        case .stickyNote: return "Sticky Note"
        case .freeText: return "Text"
        case .ink: return "Draw"
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .line: return "Line"
        case .arrow: return "Arrow"
        }
    }

    var icon: String {
        switch self {
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        case .stickyNote: return "note.text"
        case .freeText: return "textformat"
        case .ink: return "scribble"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        }
    }
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case thumbnails
    case bookmarks
    case annotations
    case search

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thumbnails: return "Pages"
        case .bookmarks: return "Bookmarks"
        case .annotations: return "Annotations"
        case .search: return "Search"
        }
    }

    var icon: String {
        switch self {
        case .thumbnails: return "rectangle.grid.1x2"
        case .bookmarks: return "bookmark"
        case .annotations: return "text.bubble"
        case .search: return "magnifyingglass"
        }
    }
}

enum PDFDisplayModeOption: String, CaseIterable, Identifiable {
    case singlePage
    case singleContinuous
    case twoUp
    case twoUpContinuous

    var id: String { rawValue }

    var label: String {
        switch self {
        case .singlePage: return "Single Page"
        case .singleContinuous: return "Continuous"
        case .twoUp: return "Two Pages"
        case .twoUpContinuous: return "Two Pages Continuous"
        }
    }

    var icon: String {
        switch self {
        case .singlePage: return "doc"
        case .singleContinuous: return "doc.text"
        case .twoUp: return "book"
        case .twoUpContinuous: return "book.pages"
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case png
    case jpeg
    case tiff
    case text
    case rtf

    var id: String { rawValue }

    var label: String {
        switch self {
        case .png: return "PNG Image"
        case .jpeg: return "JPEG Image"
        case .tiff: return "TIFF Image"
        case .text: return "Plain Text"
        case .rtf: return "Rich Text"
        }
    }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        case .text: return "txt"
        case .rtf: return "rtf"
        }
    }
}

import SwiftUI
import PDFKit

struct AnnotationToolbarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(AnnotationTool.allCases) { tool in
                        Button(action: { appState.annotationTool = tool }) {
                            VStack(spacing: 2) {
                                Image(systemName: tool.icon)
                                    .font(.title3)
                                Text(tool.label)
                                    .font(.system(size: 9))
                            }
                            .frame(width: 60, height: 44)
                            .background(appState.annotationTool == tool ?
                                        Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }

            Divider()

            HStack(spacing: 12) {
                ColorPicker("Color", selection: $state.annotationColor)
                    .frame(width: 100)

                HStack(spacing: 4) {
                    Text("Width:")
                        .font(.caption)
                    Slider(value: $state.annotationLineWidth, in: 1...10, step: 0.5)
                        .frame(width: 80)
                    Text("\(appState.annotationLineWidth, specifier: "%.1f")")
                        .font(.caption)
                        .frame(width: 30)
                }

                Spacer()

                Button("Clear All Annotations") {
                    clearAllAnnotations()
                }
                .foregroundColor(.red)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func clearAllAnnotations() {
        guard let doc = appState.documentState.pdfDocument else { return }
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let annotations = page.annotations.filter {
                $0.type != "Link" && $0.type != "Widget"
            }
            for annotation in annotations {
                page.removeAnnotation(annotation)
            }
        }
        appState.documentState.hasUnsavedChanges = true
    }
}

struct AnnotationViewModel {
    static func addHighlight(to page: PDFPage, selection: PDFSelection, color: NSColor, type: PDFAnnotationSubtype) {
        selection.selectionsByLine().forEach { lineSelection in
            let bounds = lineSelection.bounds(for: page)
            let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
            annotation.color = color.withAlphaComponent(0.4)
            page.addAnnotation(annotation)
        }
    }

    static func addStickyNote(to page: PDFPage, at point: CGPoint, contents: String, color: NSColor) {
        let bounds = CGRect(x: point.x, y: point.y, width: 24, height: 24)
        let annotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        annotation.contents = contents
        annotation.color = color
        page.addAnnotation(annotation)
    }

    static func addFreeText(to page: PDFPage, bounds: CGRect, text: String, color: NSColor, fontSize: CGFloat = 14, fontName: String? = nil) {
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        if let fontName = fontName, let font = NSFont(name: fontName, size: fontSize) {
            annotation.font = font
        } else {
            annotation.font = NSFont.systemFont(ofSize: fontSize)
        }
        annotation.fontColor = color
        annotation.color = .clear
        page.addAnnotation(annotation)
    }

    static func addInkAnnotation(to page: PDFPage, path: NSBezierPath, color: NSColor, lineWidth: CGFloat) {
        let bounds = path.bounds.insetBy(dx: -lineWidth, dy: -lineWidth)
        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = color
        let border = PDFBorder()
        border.lineWidth = lineWidth
        annotation.border = border
        annotation.add(path)
        page.addAnnotation(annotation)
    }

    static func addShape(to page: PDFPage, bounds: CGRect, type: AnnotationTool, color: NSColor, lineWidth: CGFloat) {
        let pdfType: PDFAnnotationSubtype
        switch type {
        case .rectangle: pdfType = .square
        case .circle: pdfType = .circle
        case .line, .arrow: pdfType = .line
        default: return
        }

        let annotation = PDFAnnotation(bounds: bounds, forType: pdfType, withProperties: nil)
        annotation.color = color
        let border = PDFBorder()
        border.lineWidth = lineWidth
        annotation.border = border

        if type == .arrow {
            annotation.endLineStyle = .openArrow
        }

        page.addAnnotation(annotation)
    }

    static func removeAnnotation(_ annotation: PDFAnnotation, from page: PDFPage) {
        page.removeAnnotation(annotation)
    }
}

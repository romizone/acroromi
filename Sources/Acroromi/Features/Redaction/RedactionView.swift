import SwiftUI
import PDFKit

struct RedactionToolbarView: View {
    @Environment(AppState.self) var appState
    @State private var searchPattern = ""
    @State private var redactionMarks: [RedactionMark] = []
    @State private var showApplyConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Search and redact
                HStack {
                    TextField("Search text to redact...", text: $searchPattern)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                    Button("Find & Mark") {
                        findAndMark()
                    }
                }

                Divider().frame(height: 20)

                Button(action: markSelectedText) {
                    Label("Mark Selection", systemImage: "rectangle.badge.xmark")
                }

                Spacer()

                Text("\(redactionMarks.count) areas marked")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Clear Marks") {
                    clearRedactionMarks()
                }
                .disabled(redactionMarks.isEmpty)

                Button("Apply Redactions") {
                    showApplyConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(redactionMarks.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .alert("Apply Redactions?", isPresented: $showApplyConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Apply", role: .destructive) {
                applyRedactions()
            }
        } message: {
            Text("This action permanently removes the content under all marked areas. This cannot be undone.")
        }
    }

    private func findAndMark() {
        guard let doc = appState.documentState.pdfDocument, !searchPattern.isEmpty else { return }
        let selections = doc.findString(searchPattern, withOptions: .caseInsensitive)
        for selection in selections {
            for page in selection.pages {
                let bounds = selection.bounds(for: page)
                let pageIndex = doc.index(for: page)
                addRedactionMark(on: pageIndex, bounds: bounds)
            }
        }
    }

    private func markSelectedText() {
        // In a full implementation, this would use the current PDFView selection
        // For now, we mark the center of the current page
        guard let doc = appState.documentState.pdfDocument,
              let page = doc.page(at: appState.documentState.currentPageIndex) else { return }
        let pageBounds = page.bounds(for: .mediaBox)
        let markBounds = CGRect(
            x: pageBounds.midX - 100,
            y: pageBounds.midY - 15,
            width: 200,
            height: 30
        )
        addRedactionMark(on: appState.documentState.currentPageIndex, bounds: markBounds)
    }

    private func addRedactionMark(on pageIndex: Int, bounds: CGRect) {
        guard let doc = appState.documentState.pdfDocument,
              let page = doc.page(at: pageIndex) else { return }

        let mark = RedactionMark(pageIndex: pageIndex, bounds: bounds)
        redactionMarks.append(mark)

        // Visual indicator - semi-transparent red rectangle
        let annotation = PDFAnnotation(bounds: bounds, forType: .square, withProperties: nil)
        annotation.color = NSColor.red.withAlphaComponent(0.3)
        annotation.interiorColor = NSColor.red.withAlphaComponent(0.2)
        let border = PDFBorder()
        border.lineWidth = 1
        annotation.border = border
        annotation.contents = "REDACT"
        page.addAnnotation(annotation)
    }

    private func clearRedactionMarks() {
        guard let doc = appState.documentState.pdfDocument else { return }
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let toRemove = page.annotations.filter { $0.contents == "REDACT" }
            for annotation in toRemove {
                page.removeAnnotation(annotation)
            }
        }
        redactionMarks.removeAll()
    }

    private func applyRedactions() {
        guard let doc = appState.documentState.pdfDocument else { return }

        // Group marks by page
        let marksByPage = Dictionary(grouping: redactionMarks) { $0.pageIndex }

        for (pageIndex, marks) in marksByPage {
            guard let page = doc.page(at: pageIndex) else { continue }

            // Remove redaction marker annotations
            let toRemove = page.annotations.filter { $0.contents == "REDACT" }
            for annotation in toRemove {
                page.removeAnnotation(annotation)
            }

            // Render page to image, draw black rectangles, replace page
            let pageBounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 3.0 // High DPI for quality
            let imageWidth = Int(pageBounds.width * scale)
            let imageHeight = Int(pageBounds.height * scale)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: imageWidth,
                height: imageHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            context.scaleBy(x: scale, y: scale)

            // Draw original page
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            page.draw(with: .mediaBox, to: context)
            NSGraphicsContext.restoreGraphicsState()

            // Draw black rectangles over redacted areas
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            for mark in marks {
                context.fill(mark.bounds)
            }

            // Create new page from rendered image
            if let cgImage = context.makeImage() {
                let nsImage = NSImage(cgImage: cgImage, size: pageBounds.size)
                if let newPage = PDFPage(image: nsImage) {
                    newPage.setBounds(pageBounds, for: .mediaBox)
                    doc.removePage(at: pageIndex)
                    doc.insert(newPage, at: pageIndex)
                }
            }
        }

        redactionMarks.removeAll()
        appState.documentState.hasUnsavedChanges = true
    }
}

struct RedactionMark {
    let pageIndex: Int
    let bounds: CGRect
}

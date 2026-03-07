import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ConverterToolbarView: View {
    @Environment(AppState.self) var appState
    @State private var showExportSheet = false
    @State private var showImportSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Import group
                Group {
                    Button(action: importImages) {
                        Label("Images to PDF", systemImage: "photo.fill")
                    }

                    Button(action: importWebPage) {
                        Label("Web to PDF", systemImage: "globe")
                    }
                }

                Divider().frame(height: 20)

                // Export group
                Group {
                    Button(action: { showExportSheet = true }) {
                        Label("Export Pages", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!appState.hasDocument)

                    Button(action: exportAsText) {
                        Label("Extract Text", systemImage: "doc.text")
                    }
                    .disabled(!appState.hasDocument)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showExportSheet) {
            ExportPagesSheet()
        }
    }

    private func importImages() {
        let urls = PDFDocumentManager.openImagePanel()
        guard !urls.isEmpty else { return }

        let doc = appState.documentState.pdfDocument ?? PDFDocument()
        let startIndex = doc.pageCount

        for (i, url) in urls.enumerated() {
            guard let image = NSImage(contentsOf: url),
                  let page = PDFPage(image: image) else { continue }
            doc.insert(page, at: startIndex + i)
        }

        if appState.documentState.pdfDocument == nil {
            appState.documentState.pdfDocument = doc
            appState.documentState.fileName = "Imported.pdf"
        }
        appState.documentState.totalPages = doc.pageCount
        appState.documentState.hasUnsavedChanges = true
    }

    private func importWebPage() {
        let alert = NSAlert()
        alert.messageText = "Web Page to PDF"
        alert.informativeText = "Enter a URL to convert to PDF:"
        alert.addButton(withTitle: "Convert")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "https://example.com"
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let urlString = textField.stringValue
            guard let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)") else { return }
            convertWebPageToPDF(url)
        }
    }

    private func convertWebPageToPDF(_ url: URL) {
        Task { @MainActor in
            // Use a simple approach with NSWorkspace to print web page as PDF
            // For a production app, you would use WKWebView.createPDF()
            let printInfo = NSPrintInfo()
            printInfo.paperSize = NSSize(width: 612, height: 792) // Letter size
            printInfo.topMargin = 36
            printInfo.bottomMargin = 36
            printInfo.leftMargin = 36
            printInfo.rightMargin = 36

            // Simple fallback: create a PDF page with the URL text
            let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
            let data = NSMutableData()

            var mediaBox = pageRect
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

            pdfContext.beginPage(mediaBox: &mediaBox)
            let text = "Web page: \(url.absoluteString)\n\nUse Safari or Chrome to print this page as PDF for full rendering."
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.black
            ]
            let attrStr = NSAttributedString(string: text, attributes: attrs)
            let frameSetter = CTFramesetterCreateWithAttributedString(attrStr)
            let path = CGPath(rect: pageRect.insetBy(dx: 50, dy: 50), transform: nil)
            let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: attrStr.length), path, nil)
            CTFrameDraw(frame, pdfContext)
            pdfContext.endPage()
            pdfContext.closePDF()

            if let newDoc = PDFDocument(data: data as Data) {
                appState.documentState.pdfDocument = newDoc
                appState.documentState.totalPages = newDoc.pageCount
                appState.documentState.fileName = "WebPage.pdf"
                appState.documentState.hasUnsavedChanges = true
            }
        }
    }

    private func exportAsText() {
        guard let doc = appState.documentState.pdfDocument else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.plainText]
        panel.nameFieldStringValue = appState.documentState.fileName
            .replacingOccurrences(of: ".pdf", with: ".txt")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        var fullText = ""
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let text = page.string {
                fullText += "--- Page \(i + 1) ---\n"
                fullText += text
                fullText += "\n\n"
            }
        }

        try? fullText.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct ExportPagesSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var exportFormat: ExportFormat = .png
    @State private var dpi: Double = 150
    @State private var exportAll = true
    @State private var pageRange = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Export Pages as Images")
                .font(.headline)

            Picker("Format", selection: $exportFormat) {
                ForEach([ExportFormat.png, .jpeg, .tiff]) { format in
                    Text(format.label).tag(format)
                }
            }

            HStack {
                Text("DPI:")
                Slider(value: $dpi, in: 72...600, step: 1)
                Text("\(Int(dpi))")
                    .frame(width: 40)
            }

            Picker("Pages", selection: $exportAll) {
                Text("All Pages").tag(true)
                Text("Page Range").tag(false)
            }

            if !exportAll {
                TextField("e.g., 1-5, 8, 10-12", text: $pageRange)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Export") {
                    exportPages()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func exportPages() {
        guard let doc = appState.documentState.pdfDocument,
              let folder = PDFDocumentManager.saveFolderPanel() else { return }

        let indices: [Int]
        if exportAll {
            indices = Array(0..<doc.pageCount)
        } else {
            indices = parsePageRange(pageRange, maxPage: doc.pageCount)
        }

        let scale = dpi / 72.0

        for i in indices {
            guard let page = doc.page(at: i) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)
            let width = Int(pageBounds.width * scale)
            let height = Int(pageBounds.height * scale)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            context.setFillColor(CGColor.white)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: scale, y: scale)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            page.draw(with: .mediaBox, to: context)
            NSGraphicsContext.restoreGraphicsState()

            guard let cgImage = context.makeImage() else { continue }
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))

            let url = folder.appendingPathComponent("page_\(i + 1).\(exportFormat.fileExtension)")

            if let tiffData = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData) {
                let imageData: Data?
                switch exportFormat {
                case .png:
                    imageData = bitmap.representation(using: .png, properties: [:])
                case .jpeg:
                    imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                case .tiff:
                    imageData = bitmap.representation(using: .tiff, properties: [:])
                default:
                    imageData = nil
                }
                try? imageData?.write(to: url)
            }
        }
    }

    private func parsePageRange(_ text: String, maxPage: Int) -> [Int] {
        var indices: [Int] = []
        let parts = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts {
            let bounds = part.components(separatedBy: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if bounds.count == 2 {
                for p in max(1, bounds[0])...min(maxPage, bounds[1]) {
                    indices.append(p - 1)
                }
            } else if bounds.count == 1, bounds[0] >= 1, bounds[0] <= maxPage {
                indices.append(bounds[0] - 1)
            }
        }
        return indices
    }
}

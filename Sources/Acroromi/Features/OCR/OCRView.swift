import SwiftUI
import PDFKit
import Vision

struct OCRToolbarView: View {
    @Environment(AppState.self) var appState
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var selectedLanguages: Set<String> = ["en"]
    @State private var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    @State private var statusMessage = ""
    @State private var showImportImages = false

    let availableLanguages = [
        ("en", "English"), ("id", "Indonesian"), ("ms", "Malay"),
        ("fr", "French"), ("de", "German"), ("es", "Spanish"),
        ("it", "Italian"), ("pt", "Portuguese"), ("nl", "Dutch"),
        ("ja", "Japanese"), ("ko", "Korean"), ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"), ("ru", "Russian"),
        ("ar", "Arabic"), ("th", "Thai"), ("vi", "Vietnamese"),
        ("hi", "Hindi")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { showImportImages = true }) {
                    Label("Import Images", systemImage: "photo.on.rectangle")
                }

                Divider().frame(height: 20)

                Menu {
                    ForEach(availableLanguages, id: \.0) { code, name in
                        Button(action: {
                            if selectedLanguages.contains(code) {
                                selectedLanguages.remove(code)
                            } else {
                                selectedLanguages.insert(code)
                            }
                        }) {
                            HStack {
                                Text(name)
                                if selectedLanguages.contains(code) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Languages (\(selectedLanguages.count))", systemImage: "globe")
                }

                Picker("Accuracy", selection: $recognitionLevel) {
                    Text("Fast").tag(VNRequestTextRecognitionLevel.fast)
                    Text("Accurate").tag(VNRequestTextRecognitionLevel.accurate)
                }
                .frame(width: 150)

                Spacer()

                if isProcessing {
                    ProgressView(value: progress)
                        .frame(width: 150)
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button("Run OCR on Document") {
                        Task { await runOCR() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!appState.hasDocument)

                    Button("OCR Current Page") {
                        Task { await runOCROnCurrentPage() }
                    }
                    .disabled(!appState.hasDocument)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showImportImages) {
            ImportImagesSheet()
        }
    }

    /// Check if a page already has selectable text content (not just annotations).
    /// If the page has real embedded text, OCR would create duplicate text.
    private func pageHasTextContent(_ page: PDFPage) -> Bool {
        let text = page.string ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // If page has more than a few characters of real text, skip OCR
        return trimmed.count > 5
    }

    @MainActor
    private func runOCR() async {
        guard let doc = appState.documentState.pdfDocument else { return }
        isProcessing = true
        progress = 0

        var skippedCount = 0
        var processedCount = 0

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }

            // Skip pages that already have text content — only OCR image/scanned pages
            if pageHasTextContent(page) {
                statusMessage = "Page \(i + 1): already has text, skipping..."
                progress = Double(i + 1) / Double(doc.pageCount)
                skippedCount += 1
                continue
            }

            statusMessage = "OCR page \(i + 1) of \(doc.pageCount)..."
            progress = Double(i) / Double(doc.pageCount)

            await processPage(page, in: doc, at: i)
            processedCount += 1
        }

        progress = 1.0
        if processedCount > 0 {
            appState.documentState.hasUnsavedChanges = true
        }
        statusMessage = "Done! OCR: \(processedCount) pages, skipped: \(skippedCount) (already have text)"

        try? await Task.sleep(for: .seconds(3))
        isProcessing = false
        statusMessage = ""
    }

    @MainActor
    private func runOCROnCurrentPage() async {
        guard let doc = appState.documentState.pdfDocument,
              let page = doc.page(at: appState.documentState.currentPageIndex) else { return }

        isProcessing = true

        // Check if page already has text
        if pageHasTextContent(page) {
            statusMessage = "Page already has text content — OCR skipped to avoid duplicates"
            try? await Task.sleep(for: .seconds(2))
            isProcessing = false
            statusMessage = ""
            return
        }

        statusMessage = "Processing current page..."

        await processPage(page, in: doc, at: appState.documentState.currentPageIndex)

        appState.documentState.hasUnsavedChanges = true
        isProcessing = false
        statusMessage = "OCR complete!"

        try? await Task.sleep(for: .seconds(2))
        statusMessage = ""
    }

    private func processPage(_ page: PDFPage, in doc: PDFDocument, at index: Int) async {
        let pageBounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
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
        ) else { return }

        context.scaleBy(x: scale, y: scale)

        // Draw page to context
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        page.draw(with: .mediaBox, to: context)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = context.makeImage() else { return }

        // Perform OCR
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.recognitionLanguages = Array(selectedLanguages)
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observations = request.results else { return }

        // Add invisible text annotations for each recognized text
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let boundingBox = observation.boundingBox
            // Convert normalized coordinates to page coordinates
            let annotBounds = CGRect(
                x: boundingBox.origin.x * pageBounds.width,
                y: boundingBox.origin.y * pageBounds.height,
                width: boundingBox.width * pageBounds.width,
                height: boundingBox.height * pageBounds.height
            )

            // Create invisible text annotation (searchable but not visible)
            let annotation = PDFAnnotation(bounds: annotBounds, forType: .freeText, withProperties: nil)
            annotation.contents = topCandidate.string
            annotation.font = NSFont.systemFont(ofSize: max(annotBounds.height * 0.8, 6))
            annotation.fontColor = NSColor.clear // Invisible text
            annotation.color = NSColor.clear     // No background
            let border = PDFBorder()
            border.lineWidth = 0
            annotation.border = border
            page.addAnnotation(annotation)
        }
    }
}

struct ImportImagesSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var imageURLs: [URL] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Import Images as PDF")
                .font(.headline)

            List {
                ForEach(imageURLs, id: \.self) { url in
                    HStack {
                        Image(systemName: "photo")
                        Text(url.lastPathComponent)
                        Spacer()
                    }
                }
                .onMove { from, to in
                    imageURLs.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    imageURLs.remove(atOffsets: offsets)
                }
            }
            .frame(height: 200)

            HStack {
                Button("Add Images...") {
                    let urls = PDFDocumentManager.openImagePanel()
                    imageURLs.append(contentsOf: urls)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Create PDF") {
                    createPDFFromImages()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(imageURLs.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 350)
    }

    private func createPDFFromImages() {
        let doc = PDFDocument()
        for (i, url) in imageURLs.enumerated() {
            guard let image = NSImage(contentsOf: url),
                  let page = PDFPage(image: image) else { continue }
            doc.insert(page, at: i)
        }
        if doc.pageCount > 0 {
            appState.documentState.pdfDocument = doc
            appState.documentState.totalPages = doc.pageCount
            appState.documentState.currentPageIndex = 0
            appState.documentState.fileName = "Scanned.pdf"
            appState.documentState.hasUnsavedChanges = true
        }
    }
}

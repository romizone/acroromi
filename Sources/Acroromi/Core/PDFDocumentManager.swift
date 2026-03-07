import Foundation
import PDFKit
import AppKit

struct PDFDocumentManager {

    static func openPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open PDF"
        panel.message = "Select a PDF document"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func openMultiplePanel() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.title = "Select PDF Files"
        return panel.runModal() == .OK ? panel.urls : []
    }

    static func savePanel(defaultName: String = "Untitled.pdf") -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = defaultName
        panel.title = "Save PDF"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func openImagePanel() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .bmp]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.title = "Select Images"
        return panel.runModal() == .OK ? panel.urls : []
    }

    static func saveFolderPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Output Folder"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func mergeDocuments(_ urls: [URL]) -> PDFDocument? {
        let merged = PDFDocument()
        var pageIndex = 0
        for url in urls {
            guard let doc = PDFDocument(url: url) else { continue }
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                merged.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }
        return merged.pageCount > 0 ? merged : nil
    }

    static func splitDocument(_ document: PDFDocument, ranges: [ClosedRange<Int>]) -> [PDFDocument] {
        var results: [PDFDocument] = []
        for range in ranges {
            let newDoc = PDFDocument()
            var idx = 0
            for pageNum in range {
                guard pageNum < document.pageCount,
                      let page = document.page(at: pageNum) else { continue }
                newDoc.insert(page, at: idx)
                idx += 1
            }
            if newDoc.pageCount > 0 {
                results.append(newDoc)
            }
        }
        return results
    }

    static func extractPages(_ document: PDFDocument, indices: [Int]) -> PDFDocument? {
        let newDoc = PDFDocument()
        var idx = 0
        for pageIndex in indices.sorted() {
            guard pageIndex < document.pageCount,
                  let page = document.page(at: pageIndex) else { continue }
            newDoc.insert(page, at: idx)
            idx += 1
        }
        return newDoc.pageCount > 0 ? newDoc : nil
    }

    static func rotatePage(_ document: PDFDocument, at index: Int, by degrees: Int) {
        guard let page = document.page(at: index) else { return }
        page.rotation = (page.rotation + degrees) % 360
    }

    static func deletePage(_ document: PDFDocument, at index: Int) {
        guard index < document.pageCount else { return }
        document.removePage(at: index)
    }

    static func movePage(_ document: PDFDocument, from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < document.pageCount,
              let page = document.page(at: sourceIndex) else { return }
        document.removePage(at: sourceIndex)
        let adjustedDest = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        document.insert(page, at: min(adjustedDest, document.pageCount))
    }
}

import SwiftUI
import PDFKit

@Observable
class DocumentState {
    var pdfDocument: PDFDocument?
    var currentPageIndex: Int = 0
    var scaleFactor: CGFloat = 1.0
    var displayMode: PDFDisplayModeOption = .singleContinuous
    var isEncrypted: Bool = false
    var isUnlocked: Bool = true
    var fileName: String = ""
    var fileURL: URL?
    var hasUnsavedChanges: Bool = false
    var searchText: String = ""
    var searchResults: [PDFSelection] = []
    var currentSearchIndex: Int = 0

    // FIX: Make totalPages a computed property so it's always up-to-date after page operations
    var totalPages: Int {
        pdfDocument?.pageCount ?? 0
    }

    var pageLabel: String {
        guard totalPages > 0 else { return "No Document" }
        return "Page \(currentPageIndex + 1) of \(totalPages)"
    }

    var zoomPercentage: String {
        "\(Int(scaleFactor * 100))%"
    }

    func loadDocument(from url: URL) -> Bool {
        guard let doc = PDFDocument(url: url) else { return false }
        if doc.isEncrypted {
            isEncrypted = true
            isUnlocked = false
            pdfDocument = doc
        } else {
            pdfDocument = doc
            isEncrypted = false
            isUnlocked = true
        }
        currentPageIndex = 0
        fileName = url.lastPathComponent
        fileURL = url
        hasUnsavedChanges = false
        // FIX: Clear search results when loading new document
        searchText = ""
        searchResults = []
        currentSearchIndex = 0
        return true
    }

    func unlockDocument(password: String) -> Bool {
        guard let doc = pdfDocument else { return false }
        if doc.unlock(withPassword: password) {
            isUnlocked = true
            return true
        }
        return false
    }

    func saveDocument() -> Bool {
        guard let doc = pdfDocument, let url = fileURL else { return false }
        let success = doc.write(to: url)
        if success { hasUnsavedChanges = false }
        return success
    }

    func saveDocumentAs(to url: URL) -> Bool {
        guard let doc = pdfDocument else { return false }
        let success = doc.write(to: url)
        if success {
            fileURL = url
            fileName = url.lastPathComponent
            hasUnsavedChanges = false
        }
        return success
    }

    func performSearch() {
        guard let doc = pdfDocument, !searchText.isEmpty else {
            searchResults = []
            currentSearchIndex = 0
            return
        }
        searchResults = doc.findString(searchText, withOptions: .caseInsensitive)
        currentSearchIndex = 0
    }

    func nextSearchResult() -> PDFSelection? {
        guard !searchResults.isEmpty else { return nil }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        return searchResults[currentSearchIndex]
    }

    func previousSearchResult() -> PDFSelection? {
        guard !searchResults.isEmpty else { return nil }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        return searchResults[currentSearchIndex]
    }

    // FIX: Clamp currentPageIndex to valid range after page operations
    func clampCurrentPage() {
        if totalPages > 0 {
            currentPageIndex = max(0, min(currentPageIndex, totalPages - 1))
        } else {
            currentPageIndex = 0
        }
    }
}

import SwiftUI
import PDFKit

@Observable
class AppState {
    var documentState = DocumentState()
    var activeToolMode: ToolMode = .viewer
    var activeSidebarTab: SidebarTab = .thumbnails
    var showSidebar: Bool = true
    var showInspector: Bool = false
    var annotationTool: AnnotationTool = .highlight
    var annotationColor: Color = .yellow
    var annotationLineWidth: CGFloat = 2.0
    var showSearchBar: Bool = false
    var showPasswordPrompt: Bool = false
    var showProtectionSheet: Bool = false
    var showMergeSheet: Bool = false
    var showSplitSheet: Bool = false
    var showOCRSheet: Bool = false
    var showConvertSheet: Bool = false
    var showCompareSheet: Bool = false
    var showRedactionAlert: Bool = false

    // Compare mode
    var compareDocumentState: DocumentState?

    // Recent documents
    var recentDocuments: [URL] = []

    var hasDocument: Bool {
        documentState.pdfDocument != nil
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a PDF document to open"

        if panel.runModal() == .OK, let url = panel.url {
            openDocument(at: url)
        }
    }

    func openDocument(at url: URL) {
        // FIX: Check for unsaved changes before opening new document
        if hasDocument && documentState.hasUnsavedChanges {
            let result = showUnsavedChangesAlert()
            switch result {
            case .save:
                saveDocument()
            case .discard:
                break
            case .cancel:
                return // user cancelled, don't open new doc
            }
        }

        if documentState.loadDocument(from: url) {
            addToRecentDocuments(url)
            if documentState.isEncrypted && !documentState.isUnlocked {
                showPasswordPrompt = true
            }
        }
    }

    func saveDocument() {
        if documentState.fileURL != nil {
            _ = documentState.saveDocument()
        } else {
            saveDocumentAs()
        }
    }

    func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = documentState.fileName.isEmpty ? "Untitled.pdf" : documentState.fileName

        if panel.runModal() == .OK, let url = panel.url {
            _ = documentState.saveDocumentAs(to: url)
        }
    }

    /// Returns true if document was closed (or no unsaved changes), false if user cancelled.
    @discardableResult
    func closeDocument(promptSave: Bool = false) -> Bool {
        if promptSave && hasDocument && documentState.hasUnsavedChanges {
            let result = showUnsavedChangesAlert()
            switch result {
            case .save:
                saveDocument()
            case .discard:
                break // continue closing
            case .cancel:
                return false // user cancelled
            }
        }
        documentState = DocumentState()
        activeToolMode = .viewer
        showSearchBar = false
        return true
    }

    enum UnsavedAction { case save, discard, cancel }

    func showUnsavedChangesAlert() -> UnsavedAction {
        let alert = NSAlert()
        alert.messageText = "Do you want to save changes to \"\(documentState.fileName.isEmpty ? "Untitled" : documentState.fileName)\"?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }

    private func addToRecentDocuments(_ url: URL) {
        recentDocuments.removeAll { $0 == url }
        recentDocuments.insert(url, at: 0)
        if recentDocuments.count > AppConstants.maxRecentDocuments {
            recentDocuments = Array(recentDocuments.prefix(AppConstants.maxRecentDocuments))
        }
    }
}

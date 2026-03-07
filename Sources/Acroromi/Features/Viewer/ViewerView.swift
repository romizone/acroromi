import SwiftUI
import PDFKit

struct ViewerView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var docState = appState.documentState
        PDFViewWrapper(
            document: docState.pdfDocument,
            currentPage: $docState.currentPageIndex,
            scaleFactor: $docState.scaleFactor,
            displayMode: docState.displayMode,
            highlightSelections: docState.searchResults,
            annotationMode: appState.activeToolMode,
            annotationTool: appState.annotationTool,
            annotationColor: NSColor(appState.annotationColor),
            onPageChange: { index in
                appState.documentState.currentPageIndex = index
            },
            onScaleChange: { scale in
                appState.documentState.scaleFactor = scale
            },
            onEditCommitted: {
                appState.documentState.hasUnsavedChanges = true
            }
        )
    }
}

struct PrintManager {
    static func printDocument(_ pdfView: PDFView) {
        let printInfo = NSPrintInfo.shared
        printInfo.orientation = .portrait
        printInfo.scalingFactor = 1.0
        pdfView.print(with: printInfo, autoRotate: true)
    }

    static func printDocument(_ document: PDFDocument) {
        let printInfo = NSPrintInfo.shared
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.print(with: printInfo, autoRotate: true)
    }
}

import SwiftUI
import PDFKit

struct PDFViewWrapper: NSViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPage: Int
    @Binding var scaleFactor: CGFloat
    var displayMode: PDFDisplayModeOption
    var highlightSelections: [PDFSelection]
    var annotationMode: ToolMode
    var annotationTool: AnnotationTool
    var annotationColor: NSColor
    var onPageChange: ((Int) -> Void)?
    var onScaleChange: ((CGFloat) -> Void)?
    var onEditCommitted: (() -> Void)?

    func makeNSView(context: Context) -> EditablePDFView {
        let pdfView = EditablePDFView()
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageShadowsEnabled = true
        pdfView.backgroundColor = NSColor(calibratedWhite: 0.85, alpha: 1.0)

        context.coordinator.pdfView = pdfView
        context.coordinator.setupNotifications()

        return pdfView
    }

    func updateNSView(_ pdfView: EditablePDFView, context: Context) {
        // FIX: Update coordinator's parent to prevent stale struct
        context.coordinator.parent = self

        // Document change
        if pdfView.document !== document {
            pdfView.document = document
            if document != nil {
                pdfView.autoScales = true
            }
        }

        // Display mode - only change if different
        let targetMode: PDFDisplayMode
        switch displayMode {
        case .singlePage: targetMode = .singlePage
        case .singleContinuous: targetMode = .singlePageContinuous
        case .twoUp: targetMode = .twoUp
        case .twoUpContinuous: targetMode = .twoUpContinuous
        }
        if pdfView.displayMode != targetMode {
            pdfView.displayMode = targetMode
        }

        // Scale
        if abs(pdfView.scaleFactor - scaleFactor) > 0.01 && !context.coordinator.isUpdatingScale {
            pdfView.scaleFactor = scaleFactor
        }

        // Search highlights
        pdfView.highlightedSelections = highlightSelections.isEmpty ? nil : highlightSelections

        // Toggle edit mode — only when it actually changes
        let shouldBeEditing = (annotationMode == .edit)
        if pdfView.isEditModeActive != shouldBeEditing {
            if !shouldBeEditing {
                pdfView.commitEdit()
            }
            pdfView.isEditModeActive = shouldBeEditing
            pdfView.updateTrackingAreas()
        }

        // Navigate to page if changed externally (e.g., sidebar click, page navigation)
        if let doc = document, let targetPage = doc.page(at: currentPage),
           !context.coordinator.isUpdatingPage {
            if pdfView.currentPage !== targetPage {
                context.coordinator.isUpdatingPage = true
                pdfView.go(to: targetPage)
                DispatchQueue.main.async {
                    context.coordinator.isUpdatingPage = false
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PDFViewWrapper
        weak var pdfView: EditablePDFView?
        var isUpdatingScale = false
        var isUpdatingPage = false

        init(_ parent: PDFViewWrapper) {
            self.parent = parent
        }

        func setupNotifications() {
            NotificationCenter.default.addObserver(
                self, selector: #selector(pageChanged),
                name: .PDFViewPageChanged, object: pdfView
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(scaleChanged),
                name: .PDFViewScaleChanged, object: pdfView
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(editCommitted),
                name: .init("AcroromiEditCommitted"), object: nil
            )
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            let index = document.index(for: currentPage)
            isUpdatingPage = true
            DispatchQueue.main.async {
                self.parent.currentPage = index
                self.parent.onPageChange?(index)
                self.isUpdatingPage = false
            }
        }

        @objc func scaleChanged(_ notification: Notification) {
            guard let pdfView = pdfView else { return }
            isUpdatingScale = true
            DispatchQueue.main.async {
                self.parent.scaleFactor = pdfView.scaleFactor
                self.parent.onScaleChange?(pdfView.scaleFactor)
                self.isUpdatingScale = false
            }
        }

        @objc func editCommitted(_ notification: Notification) {
            DispatchQueue.main.async {
                self.parent.onEditCommitted?()
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

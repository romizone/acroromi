import SwiftUI
import PDFKit

struct CompareToolbarView: View {
    @Environment(AppState.self) var appState
    @State private var compareDocument: PDFDocument?
    @State private var compareMode: CompareMode = .sideBySide
    @State private var showDifferences = false
    @State private var differences: [PageDifference] = []
    @State private var isComparing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: openCompareDocument) {
                    Label("Open Second PDF", systemImage: "doc.badge.plus")
                }

                if compareDocument != nil {
                    Divider().frame(height: 20)

                    Picker("Mode", selection: $compareMode) {
                        Text("Side by Side").tag(CompareMode.sideBySide)
                        Text("Overlay").tag(CompareMode.overlay)
                        Text("Text Diff").tag(CompareMode.textDiff)
                    }
                    .frame(width: 160)

                    Button(action: { Task { await runComparison() } }) {
                        Label("Compare", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isComparing)

                    if isComparing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                Spacer()

                if !differences.isEmpty {
                    Text("\(differences.count) differences found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func openCompareDocument() {
        guard let url = PDFDocumentManager.openPanel() else { return }
        compareDocument = PDFDocument(url: url)
    }

    @MainActor
    private func runComparison() async {
        guard let doc1 = appState.documentState.pdfDocument,
              let doc2 = compareDocument else { return }

        isComparing = true
        differences = []

        let maxPages = max(doc1.pageCount, doc2.pageCount)

        for i in 0..<maxPages {
            let page1 = i < doc1.pageCount ? doc1.page(at: i) : nil
            let page2 = i < doc2.pageCount ? doc2.page(at: i) : nil

            if page1 == nil || page2 == nil {
                differences.append(PageDifference(
                    pageIndex: i,
                    type: page1 == nil ? .addedPage : .removedPage,
                    description: page1 == nil ? "Page added in document 2" : "Page removed in document 2"
                ))
                continue
            }

            // Text comparison
            let text1 = page1?.string ?? ""
            let text2 = page2?.string ?? ""

            if text1 != text2 {
                differences.append(PageDifference(
                    pageIndex: i,
                    type: .textChanged,
                    description: "Text content differs on page \(i + 1)"
                ))
            }
        }

        isComparing = false
    }
}

struct CompareContentView: View {
    @Environment(AppState.self) var appState
    let compareDocument: PDFDocument?

    var body: some View {
        HSplitView {
            // Document 1
            VStack(spacing: 0) {
                Text("Document 1: \(appState.documentState.fileName)")
                    .font(.caption)
                    .padding(4)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))

                if let doc = appState.documentState.pdfDocument {
                    CompareDocumentView(document: doc)
                }
            }

            // Document 2
            VStack(spacing: 0) {
                Text("Document 2")
                    .font(.caption)
                    .padding(4)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))

                if let doc = compareDocument {
                    CompareDocumentView(document: doc)
                } else {
                    VStack {
                        Spacer()
                        Text("No comparison document selected")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }
}

struct CompareDocumentView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
    }
}

enum CompareMode {
    case sideBySide
    case overlay
    case textDiff
}

struct PageDifference {
    let pageIndex: Int
    let type: DifferenceType
    let description: String
}

enum DifferenceType {
    case addedPage
    case removedPage
    case textChanged
    case visualChanged
}

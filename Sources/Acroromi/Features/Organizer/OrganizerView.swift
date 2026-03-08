import SwiftUI
import PDFKit

struct OrganizerView: View {
    @Environment(AppState.self) var appState
    @State private var selectedPages: Set<Int> = []
    @State private var showMergeSheet = false
    @State private var showSplitSheet = false
    @State private var showExtractSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Organizer toolbar
            HStack(spacing: 12) {
                Button(action: { showMergeSheet = true }) {
                    Label("Merge Files", systemImage: "doc.on.doc.fill")
                }

                Button(action: { showSplitSheet = true }) {
                    Label("Split", systemImage: "scissors")
                }
                .disabled(!appState.hasDocument)

                Button(action: { showExtractSheet = true }) {
                    Label("Extract", systemImage: "arrow.up.doc")
                }
                .disabled(selectedPages.isEmpty)

                Divider().frame(height: 20)

                Button(action: rotateSelected) {
                    Label("Rotate", systemImage: "rotate.right")
                }
                .disabled(selectedPages.isEmpty)

                Button(action: deleteSelected) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedPages.isEmpty)
                .foregroundColor(.red)

                Spacer()

                Text("\(selectedPages.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Page grid
            if let doc = appState.documentState.pdfDocument {
                ScrollView {
                    PageGridContent(
                        document: doc,
                        selectedPages: $selectedPages
                    )
                }
            }
        }
        .sheet(isPresented: $showMergeSheet) {
            MergeFilesSheet()
        }
        .sheet(isPresented: $showSplitSheet) {
            SplitDocumentSheet()
        }
        .sheet(isPresented: $showExtractSheet) {
            ExtractPagesSheet(selectedPages: Array(selectedPages).sorted())
        }
    }

    private func rotateSelected() {
        guard let doc = appState.documentState.pdfDocument else { return }
        for index in selectedPages {
            PDFDocumentManager.rotatePage(doc, at: index, by: 90)
        }
        appState.documentState.hasUnsavedChanges = true
    }

    private func deleteSelected() {
        guard let doc = appState.documentState.pdfDocument else { return }
        for index in selectedPages.sorted().reversed() {
            PDFDocumentManager.deletePage(doc, at: index)
        }
        // FIX: Clamp currentPageIndex after deletion (totalPages is now computed)
        appState.documentState.clampCurrentPage()
        selectedPages.removeAll()
        appState.documentState.hasUnsavedChanges = true
    }
}

struct PageGridContent: View {
    let document: PDFDocument
    @Binding var selectedPages: Set<Int>

    let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<document.pageCount, id: \.self) { index in
                PageGridItem(
                    document: document,
                    index: index,
                    isSelected: selectedPages.contains(index)
                )
                .onTapGesture {
                    if selectedPages.contains(index) {
                        selectedPages.remove(index)
                    } else {
                        selectedPages.insert(index)
                    }
                }
            }
        }
        .padding(16)
    }
}

struct PageGridItem: View {
    let document: PDFDocument
    let index: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let page = document.page(at: index) {
                Image(nsImage: page.thumbnail(of: CGSize(width: 130, height: 180), for: .mediaBox))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 170)
                    .border(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                           width: isSelected ? 3 : 1)
                    .shadow(color: .black.opacity(0.15), radius: 3)
            }
            Text("Page \(index + 1)")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct MergeFilesSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var fileURLs: [URL] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Merge PDF Files")
                .font(.headline)

            List {
                ForEach(fileURLs, id: \.self) { url in
                    HStack {
                        Image(systemName: "doc.fill")
                        Text(url.lastPathComponent)
                        Spacer()
                    }
                }
                .onMove { from, to in
                    fileURLs.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    fileURLs.remove(atOffsets: offsets)
                }
            }
            .frame(height: 200)

            HStack {
                Button("Add Files...") {
                    let urls = PDFDocumentManager.openMultiplePanel()
                    fileURLs.append(contentsOf: urls)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Merge") {
                    mergeFiles()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(fileURLs.count < 2)
            }
        }
        .padding()
        .frame(width: 500, height: 350)
    }

    private func mergeFiles() {
        if let merged = PDFDocumentManager.mergeDocuments(fileURLs) {
            appState.documentState.pdfDocument = merged
            appState.documentState.currentPageIndex = 0
            appState.documentState.fileName = "Merged.pdf"
            appState.documentState.hasUnsavedChanges = true
        }
    }
}

struct SplitDocumentSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var splitMode = 0 // 0: by range, 1: every N pages
    @State private var rangeText = ""
    @State private var pagesPerSplit = 1

    var body: some View {
        VStack(spacing: 16) {
            Text("Split Document")
                .font(.headline)

            Picker("Split Mode", selection: $splitMode) {
                Text("By Page Range").tag(0)
                Text("Every N Pages").tag(1)
            }
            .pickerStyle(.segmented)

            if splitMode == 0 {
                VStack(alignment: .leading) {
                    Text("Enter page ranges (e.g., 1-3, 5-7, 8-10):")
                        .font(.caption)
                    TextField("1-3, 5-7", text: $rangeText)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                Stepper("Pages per file: \(pagesPerSplit)",
                       value: $pagesPerSplit, in: 1...100)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Split & Save") {
                    splitDocument()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func splitDocument() {
        guard let doc = appState.documentState.pdfDocument else { return }
        guard let folder = PDFDocumentManager.saveFolderPanel() else { return }

        var ranges: [ClosedRange<Int>] = []
        if splitMode == 0 {
            ranges = parseRanges(rangeText, maxPage: doc.pageCount)
        } else {
            var start = 0
            while start < doc.pageCount {
                let end = min(start + pagesPerSplit - 1, doc.pageCount - 1)
                ranges.append(start...end)
                start += pagesPerSplit
            }
        }

        let documents = PDFDocumentManager.splitDocument(doc, ranges: ranges)
        for (i, splitDoc) in documents.enumerated() {
            let url = folder.appendingPathComponent("split_\(i + 1).pdf")
            splitDoc.write(to: url)
        }
    }

    private func parseRanges(_ text: String, maxPage: Int) -> [ClosedRange<Int>] {
        var ranges: [ClosedRange<Int>] = []
        let parts = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts {
            let bounds = part.components(separatedBy: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if bounds.count == 2 {
                let start = max(0, bounds[0] - 1)
                let end = min(maxPage - 1, bounds[1] - 1)
                if start <= end { ranges.append(start...end) }
            } else if bounds.count == 1 {
                let page = bounds[0] - 1
                if page >= 0 && page < maxPage { ranges.append(page...page) }
            }
        }
        return ranges
    }
}

struct ExtractPagesSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    let selectedPages: [Int]

    var body: some View {
        VStack(spacing: 16) {
            Text("Extract Pages")
                .font(.headline)

            Text("Extract \(selectedPages.count) selected page(s) to a new PDF file.")
                .foregroundColor(.secondary)

            Text("Pages: \(selectedPages.map { "\($0 + 1)" }.joined(separator: ", "))")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Extract & Save") {
                    extractPages()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func extractPages() {
        guard let doc = appState.documentState.pdfDocument,
              let extracted = PDFDocumentManager.extractPages(doc, indices: selectedPages),
              let url = PDFDocumentManager.savePanel(defaultName: "extracted_pages.pdf") else { return }
        extracted.write(to: url)
    }
}

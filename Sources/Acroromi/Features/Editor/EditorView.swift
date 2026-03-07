import SwiftUI
import PDFKit

struct EditorToolbarView: View {
    @Environment(AppState.self) var appState
    @State private var editText = ""
    @State private var fontSize: CGFloat = 14
    @State private var fontFamily: String = "Helvetica"
    @State private var fontColor: Color = .black
    @State private var showAddTextSheet = false
    @State private var showAddImageSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Edit existing text indicator
                Label("Click text on PDF to edit", systemImage: "cursorarrow.click.2")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)

                Divider().frame(height: 20)

                Button(action: { showAddTextSheet = true }) {
                    Label("Add New Text", systemImage: "textformat.abc")
                }

                Button(action: { showAddImageSheet = true }) {
                    Label("Add Image", systemImage: "photo")
                }

                Divider().frame(height: 20)

                Button(action: undoLastEdit) {
                    Label("Undo Edit", systemImage: "arrow.uturn.backward")
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Click a line of text to edit in-place")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Enter = apply, Esc = cancel")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showAddTextSheet) {
            AddTextSheet(
                text: $editText,
                fontSize: $fontSize,
                fontFamily: $fontFamily,
                fontColor: $fontColor,
                onAdd: { addTextAnnotation() }
            )
        }
        .sheet(isPresented: $showAddImageSheet) {
            AddImageSheet { url in
                addImageToPage(url)
            }
        }
    }

    private func addTextAnnotation() {
        guard let doc = appState.documentState.pdfDocument,
              let page = doc.page(at: appState.documentState.currentPageIndex),
              !editText.isEmpty else { return }

        let pageBounds = page.bounds(for: .mediaBox)
        let textWidth: CGFloat = 200
        let textHeight: CGFloat = fontSize * 2
        let bounds = CGRect(
            x: pageBounds.midX - textWidth / 2,
            y: pageBounds.midY - textHeight / 2,
            width: textWidth,
            height: textHeight
        )

        AnnotationViewModel.addFreeText(
            to: page,
            bounds: bounds,
            text: editText,
            color: NSColor(fontColor),
            fontSize: fontSize,
            fontName: fontFamily
        )
        appState.documentState.hasUnsavedChanges = true
        editText = ""
    }

    private func addImageToPage(_ url: URL) {
        guard let doc = appState.documentState.pdfDocument,
              let page = doc.page(at: appState.documentState.currentPageIndex),
              let image = NSImage(contentsOf: url) else { return }

        let pageBounds = page.bounds(for: .mediaBox)
        let imageSize = image.size
        let scale = min(pageBounds.width * 0.5 / imageSize.width,
                       pageBounds.height * 0.5 / imageSize.height,
                       1.0)
        let stampWidth = imageSize.width * scale
        let stampHeight = imageSize.height * scale
        let bounds = CGRect(
            x: pageBounds.midX - stampWidth / 2,
            y: pageBounds.midY - stampHeight / 2,
            width: stampWidth,
            height: stampHeight
        )

        let imgAnnotation = ImageStampAnnotation(bounds: bounds, image: image)
        page.addAnnotation(imgAnnotation)
        appState.documentState.hasUnsavedChanges = true
    }

    private func undoLastEdit() {
        guard let doc = appState.documentState.pdfDocument,
              let page = doc.page(at: appState.documentState.currentPageIndex) else { return }

        // Find and remove the last __EDIT_COVER__ annotation and the freeText that follows
        let annotations = page.annotations
        if let lastCoverIdx = annotations.lastIndex(where: { $0.contents == "__EDIT_COVER__" }) {
            let cover = annotations[lastCoverIdx]
            page.removeAnnotation(cover)
            // The freeText replacement is the next annotation (now at same index after removal)
            let remaining = page.annotations
            if lastCoverIdx < remaining.count {
                let next = remaining[lastCoverIdx]
                if next.type == "FreeText" {
                    page.removeAnnotation(next)
                }
            }
            appState.documentState.hasUnsavedChanges = true
        }
    }
}

struct AddTextSheet: View {
    @Binding var text: String
    @Binding var fontSize: CGFloat
    @Binding var fontFamily: String
    @Binding var fontColor: Color
    let onAdd: () -> Void
    @Environment(\.dismiss) var dismiss

    static let fontFamilies: [(String, String)] = [
        ("Helvetica", "Helvetica"),
        ("Helvetica-Bold", "Helvetica Bold"),
        ("Times-Roman", "Times New Roman"),
        ("Times-Bold", "Times Bold"),
        ("Courier", "Courier"),
        ("Courier-Bold", "Courier Bold"),
        ("Arial", "Arial"),
        ("Georgia", "Georgia"),
        ("Verdana", "Verdana"),
        ("Futura-Medium", "Futura"),
        ("Avenir-Medium", "Avenir"),
        ("Menlo-Regular", "Menlo"),
        ("AmericanTypewriter", "American Typewriter"),
        ("Palatino-Roman", "Palatino"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Text to PDF")
                .font(.headline)

            TextEditor(text: $text)
                .frame(height: 80)
                .border(Color.gray.opacity(0.3))

            // Font family picker
            HStack {
                Text("Font:")
                    .frame(width: 60, alignment: .leading)
                Picker("", selection: $fontFamily) {
                    ForEach(Self.fontFamilies, id: \.0) { name, label in
                        Text(label)
                            .font(.custom(name, size: 13))
                            .tag(name)
                    }
                }
                .labelsHidden()
            }

            // Font size
            HStack {
                Text("Size:")
                    .frame(width: 60, alignment: .leading)
                Slider(value: $fontSize, in: 8...72, step: 1)
                Text("\(Int(fontSize)) pt")
                    .frame(width: 40)
                    .monospacedDigit()
            }

            // Font color
            HStack {
                Text("Color:")
                    .frame(width: 60, alignment: .leading)
                ColorPicker("", selection: $fontColor, supportsOpacity: false)
                    .labelsHidden()
                Spacer()
            }

            // Preview
            GroupBox("Preview") {
                Text(text.isEmpty ? "Sample Text" : text)
                    .font(.custom(fontFamily, size: fontSize > 32 ? 32 : fontSize))
                    .foregroundColor(fontColor)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .padding(4)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    onAdd()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }
}

struct AddImageSheet: View {
    let onImageSelected: (URL) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Image to PDF")
                .font(.headline)

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Button("Select Image...") {
                let urls = PDFDocumentManager.openImagePanel()
                if let url = urls.first {
                    onImageSelected(url)
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

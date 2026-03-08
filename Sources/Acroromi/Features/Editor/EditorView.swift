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
            // Sejda-style editor toolbar with grouped buttons
            HStack(spacing: 8) {
                // Edit mode indicator
                HStack(spacing: 5) {
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 12))
                        .foregroundColor(SejdaTheme.primary)
                    Text("Click text to edit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(SejdaTheme.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(SejdaTheme.primary.opacity(0.08))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(SejdaTheme.primary.opacity(0.2), lineWidth: 1)
                )

                Divider().frame(height: 20)

                // Add Text button
                Button(action: { showAddTextSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "textformat.abc")
                            .font(.system(size: 12))
                        Text("Text")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(SejdaToolbarButton())

                // Add Image button
                Button(action: { showAddImageSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                        Text("Image")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(SejdaToolbarButton())

                Divider().frame(height: 20)

                // Undo button
                Button(action: undoLastEdit) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12))
                        Text("Undo")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(SejdaToolbarButton())

                Spacer()

                // Keyboard hints
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Text("Enter")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(SejdaTheme.controlBg)
                            .cornerRadius(3)
                        Text("apply")
                            .font(.system(size: 9))
                    }
                    HStack(spacing: 3) {
                        Text("Esc")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(SejdaTheme.controlBg)
                            .cornerRadius(3)
                        Text("cancel")
                            .font(.system(size: 9))
                    }
                }
                .foregroundColor(SejdaTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
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

        let annotations = page.annotations
        if let lastCoverIdx = annotations.lastIndex(where: { $0.contents == "__EDIT_COVER__" }) {
            let cover = annotations[lastCoverIdx]
            page.removeAnnotation(cover)
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

// MARK: - Sejda-style Add Text Sheet
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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Text")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SejdaTheme.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SejdaTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(SejdaTheme.controlBg)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            VStack(spacing: 14) {
                // Text input
                TextEditor(text: $text)
                    .frame(height: 80)
                    .font(.system(size: 13))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(SejdaTheme.controlBg, lineWidth: 1)
                    )

                // Font properties row
                HStack(spacing: 12) {
                    // Font family
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Font")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(SejdaTheme.textSecondary)
                        Picker("", selection: $fontFamily) {
                            ForEach(Self.fontFamilies, id: \.0) { name, label in
                                Text(label)
                                    .font(.custom(name, size: 12))
                                    .tag(name)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }

                    // Font size
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Size")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(SejdaTheme.textSecondary)
                        HStack(spacing: 4) {
                            Slider(value: $fontSize, in: 8...72, step: 1)
                            Text("\(Int(fontSize))")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .frame(width: 24)
                        }
                    }
                    .frame(width: 130)

                    // Color
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Color")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(SejdaTheme.textSecondary)
                        ColorPicker("", selection: $fontColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                    .frame(width: 50)
                }

                // Preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(SejdaTheme.textSecondary)
                    Text(text.isEmpty ? "Sample Text" : text)
                        .font(.custom(fontFamily, size: fontSize > 28 ? 28 : fontSize))
                        .foregroundColor(fontColor)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(SejdaTheme.controlBg, lineWidth: 1)
                        )
                }
            }
            .padding(20)

            Divider()

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(action: {
                    onAdd()
                    dismiss()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("Add Text")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(SejdaTheme.primary)
                .keyboardShortcut(.defaultAction)
                .disabled(text.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 460)
    }
}

// MARK: - Sejda-style Add Image Sheet
struct AddImageSheet: View {
    let onImageSelected: (URL) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Image")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SejdaTheme.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SejdaTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(SejdaTheme.controlBg)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundColor(SejdaTheme.textSecondary.opacity(0.4))
                        .frame(height: 100)

                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 28))
                            .foregroundColor(SejdaTheme.textSecondary)
                        Text("Select an image to add")
                            .font(.system(size: 12))
                            .foregroundColor(SejdaTheme.textSecondary)
                    }
                }

                Button(action: {
                    let urls = PDFDocumentManager.openImagePanel()
                    if let url = urls.first {
                        onImageSelected(url)
                        dismiss()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12))
                        Text("Browse Files...")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(SejdaTheme.primary)
            }
            .padding(20)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 360)
    }
}

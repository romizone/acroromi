import SwiftUI
import PDFKit

struct FormSignToolbarView: View {
    @Environment(AppState.self) var appState
    @State private var showSignaturePad = false
    @State private var savedSignatures: [NSImage] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: detectFormFields) {
                    Label("Detect Fields", systemImage: "rectangle.and.pencil.and.ellipsis")
                }

                Divider().frame(height: 20)

                Button(action: { showSignaturePad = true }) {
                    Label("Add Signature", systemImage: "signature")
                }

                if !savedSignatures.isEmpty {
                    Menu {
                        ForEach(Array(savedSignatures.enumerated()), id: \.offset) { idx, img in
                            Button("Signature \(idx + 1)") {
                                placeSignature(img)
                            }
                        }
                    } label: {
                        Label("Saved Signatures", systemImage: "list.bullet")
                    }
                }

                Spacer()

                Text("Click form fields to fill them")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showSignaturePad) {
            SignaturePadSheet { image in
                savedSignatures.append(image)
                placeSignature(image)
            }
        }
    }

    private func detectFormFields() {
        guard let doc = appState.documentState.pdfDocument else { return }
        var fieldCount = 0
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            for annotation in page.annotations where annotation.type == "Widget" {
                annotation.color = NSColor.systemBlue.withAlphaComponent(0.1)
                fieldCount += 1
            }
        }
        if fieldCount == 0 {
            // No form fields found
        }
    }

    private func placeSignature(_ image: NSImage) {
        guard let doc = appState.documentState.pdfDocument,
              let page = doc.page(at: appState.documentState.currentPageIndex) else { return }

        let pageBounds = page.bounds(for: .mediaBox)
        let sigWidth: CGFloat = 200
        let sigHeight: CGFloat = 80
        let bounds = CGRect(
            x: pageBounds.midX - sigWidth / 2,
            y: pageBounds.height * 0.15,
            width: sigWidth,
            height: sigHeight
        )

        let imgAnnotation = ImageStampAnnotation(bounds: bounds, image: image)
        page.addAnnotation(imgAnnotation)
        appState.documentState.hasUnsavedChanges = true
    }
}

class ImageStampAnnotation: PDFAnnotation {
    let stampImage: NSImage

    init(bounds: CGRect, image: NSImage) {
        self.stampImage = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }

    required init?(coder: NSCoder) {
        // FIX: Return nil instead of fatalError to prevent crashes on decode
        return nil
    }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = stampImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            super.draw(with: box, in: context)
            return
        }
        context.saveGState()
        context.draw(cgImage, in: bounds)
        context.restoreGState()
    }
}

struct SignaturePadSheet: View {
    let onSignatureCreated: (NSImage) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var signatureMode = 0 // 0: draw, 1: type
    @State private var typedName = ""
    @State private var paths: [[CGPoint]] = []
    @State private var currentPath: [CGPoint] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Signature")
                .font(.headline)

            Picker("Mode", selection: $signatureMode) {
                Text("Draw").tag(0)
                Text("Type").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            if signatureMode == 0 {
                // Drawing canvas
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 400, height: 150)

                    Canvas { context, size in
                        for path in paths {
                            drawPath(path, in: &context)
                        }
                        if !currentPath.isEmpty {
                            drawPath(currentPath, in: &context)
                        }
                    }
                    .frame(width: 400, height: 150)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                currentPath.append(value.location)
                            }
                            .onEnded { _ in
                                paths.append(currentPath)
                                currentPath = []
                            }
                    )
                }
                .border(Color.gray.opacity(0.3))

                Button("Clear") {
                    paths.removeAll()
                    currentPath.removeAll()
                }
            } else {
                TextField("Type your name", text: $typedName)
                    .textFieldStyle(.roundedBorder)
                    .font(.custom("Snell Roundhand", size: 32))
                    .frame(width: 400)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Use Signature") {
                    if let image = createSignatureImage() {
                        onSignatureCreated(image)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(signatureMode == 0 ? paths.isEmpty : typedName.isEmpty)
            }
        }
        .padding()
        .frame(width: 450)
    }

    private func drawPath(_ points: [CGPoint], in context: inout GraphicsContext) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(.black), lineWidth: 2)
    }

    private func createSignatureImage() -> NSImage? {
        let size = NSSize(width: 400, height: 150)
        let image = NSImage(size: size)
        image.lockFocus()

        if signatureMode == 0 {
            NSColor.clear.set()
            NSBezierPath.fill(NSRect(origin: .zero, size: size))

            NSColor.black.set()
            for pathPoints in paths {
                let bezier = NSBezierPath()
                bezier.lineWidth = 2
                if let first = pathPoints.first {
                    // FIX: Flip Y coordinates — SwiftUI Canvas (top-left origin) → NSImage (bottom-left origin)
                    bezier.move(to: NSPoint(x: first.x, y: size.height - first.y))
                    for point in pathPoints.dropFirst() {
                        bezier.line(to: NSPoint(x: point.x, y: size.height - point.y))
                    }
                    bezier.stroke()
                }
            }
        } else {
            let font = NSFont(name: "Snell Roundhand", size: 36) ?? NSFont.systemFont(ofSize: 36)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let attrString = NSAttributedString(string: typedName, attributes: attrs)
            let textSize = attrString.size()
            let point = NSPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            attrString.draw(at: point)
        }

        image.unlockFocus()
        return image
    }
}

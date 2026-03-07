import SwiftUI
import PDFKit

struct ESignatureToolbarView: View {
    @Environment(AppState.self) var appState
    @State private var requests: [SignatureRequest] = []
    @State private var showNewRequestSheet = false
    @State private var showRequestList = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { showNewRequestSheet = true }) {
                    Label("New Request", systemImage: "plus.circle")
                }
                .disabled(!appState.hasDocument)

                Button(action: { showRequestList = true }) {
                    Label("View Requests", systemImage: "list.clipboard")
                }

                Divider().frame(height: 20)

                Button(action: placeSignatureField) {
                    Label("Place Sign Here", systemImage: "signature")
                }
                .disabled(!appState.hasDocument)

                Spacer()

                Text("\(requests.count) active requests")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showNewRequestSheet) {
            NewSignatureRequestSheet(requests: $requests)
        }
        .sheet(isPresented: $showRequestList) {
            SignatureRequestListSheet(requests: $requests)
        }
    }

    private func placeSignatureField() {
        guard let doc = appState.documentState.pdfDocument,
              let page = doc.page(at: appState.documentState.currentPageIndex) else { return }

        let pageBounds = page.bounds(for: .mediaBox)
        let bounds = CGRect(
            x: pageBounds.midX - 100,
            y: pageBounds.height * 0.15,
            width: 200,
            height: 60
        )

        let annotation = PDFAnnotation(bounds: bounds, forType: .square, withProperties: nil)
        annotation.color = NSColor.systemBlue.withAlphaComponent(0.3)
        annotation.interiorColor = NSColor.systemBlue.withAlphaComponent(0.05)
        annotation.contents = "SIGN HERE"
        let border = PDFBorder()
        border.lineWidth = 2
        border.style = .dashed
        annotation.border = border
        page.addAnnotation(annotation)

        // Add label
        let labelBounds = CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y + bounds.height,
            width: bounds.width,
            height: 16
        )
        let label = PDFAnnotation(bounds: labelBounds, forType: .freeText, withProperties: nil)
        label.contents = "Sign Here"
        label.font = NSFont.systemFont(ofSize: 10)
        label.fontColor = NSColor.systemBlue
        label.color = .clear
        page.addAnnotation(label)

        appState.documentState.hasUnsavedChanges = true
    }
}

struct SignatureRequest: Identifiable {
    let id = UUID()
    var signerName: String
    var signerEmail: String
    var status: SignatureStatus
    var createdDate: Date
    var signedDate: Date?
    var pageIndex: Int
}

enum SignatureStatus: String {
    case pending = "Pending"
    case sent = "Sent"
    case signed = "Signed"
    case expired = "Expired"

    var color: Color {
        switch self {
        case .pending: return .orange
        case .sent: return .blue
        case .signed: return .green
        case .expired: return .red
        }
    }
}

struct NewSignatureRequestSheet: View {
    @Binding var requests: [SignatureRequest]
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var signerName = ""
    @State private var signerEmail = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Request E-Signature")
                .font(.headline)

            TextField("Signer Name", text: $signerName)
                .textFieldStyle(.roundedBorder)

            TextField("Signer Email", text: $signerEmail)
                .textFieldStyle(.roundedBorder)

            Text("The PDF will be exported with signature fields. Send the exported PDF to the signer for them to sign and return.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create & Export") {
                    createRequest()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(signerName.isEmpty || signerEmail.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func createRequest() {
        let request = SignatureRequest(
            signerName: signerName,
            signerEmail: signerEmail,
            status: .pending,
            createdDate: Date(),
            pageIndex: appState.documentState.currentPageIndex
        )
        requests.append(request)

        // Export the PDF with signature fields
        if let url = PDFDocumentManager.savePanel(
            defaultName: "sign_request_\(signerName).pdf"
        ) {
            _ = appState.documentState.pdfDocument?.write(to: url)
        }
    }
}

struct SignatureRequestListSheet: View {
    @Binding var requests: [SignatureRequest]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Signature Requests")
                .font(.headline)

            if requests.isEmpty {
                Text("No signature requests yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(requests) { request in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(request.signerName)
                                    .fontWeight(.medium)
                                Text(request.signerEmail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Created: \(request.createdDate.formatted())")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(request.status.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(request.status.color.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .onDelete { offsets in
                        requests.remove(atOffsets: offsets)
                    }
                }
                .frame(height: 250)
            }

            Button("Close") { dismiss() }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

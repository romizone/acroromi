import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @Environment(AppState.self) var appState
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor.opacity(0.6))

            Text("Acroromi")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("PDF Viewer & Editor")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Button(action: { appState.openDocument() }) {
                    Label("Open PDF", systemImage: "folder")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .foregroundColor(isTargeted ? .accentColor : .gray.opacity(0.4))
                    .frame(width: 300, height: 120)

                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Drop PDF here")
                        .foregroundColor(.secondary)
                }
            }
            .onDrop(of: [UTType.pdf], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }

            if !appState.recentDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Documents")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ForEach(appState.recentDocuments, id: \.self) { url in
                        Button(action: { appState.openDocument(at: url) }) {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.accentColor)
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 300)
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async { appState.openDocument(at: url) }
                } else if let url = item as? URL {
                    DispatchQueue.main.async { appState.openDocument(at: url) }
                }
            }
        }
        return true
    }
}

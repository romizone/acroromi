import SwiftUI
import PDFKit

struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            if appState.hasDocument {
                SidebarView()
            }
        } detail: {
            VStack(spacing: 0) {
                // Feature toolbar (context-sensitive)
                if appState.hasDocument {
                    featureToolbar
                }

                // Search bar
                if appState.showSearchBar {
                    SearchBarView()
                    Divider()
                }

                // Main content
                if appState.hasDocument {
                    mainContent
                } else {
                    WelcomeView()
                }

                // Status bar
                if appState.hasDocument {
                    Divider()
                    StatusBarView()
                }
            }
        }
        .navigationSplitViewColumnWidth(min: AppConstants.sidebarMinWidth,
                                         ideal: 200,
                                         max: AppConstants.sidebarMaxWidth)
        .toolbar {
            MainToolbar()
        }
        .sheet(isPresented: $state.showPasswordPrompt) {
            PasswordPromptView()
        }
        .sheet(isPresented: $state.showProtectionSheet) {
            SecurityView()
        }
        .onDrop(of: [.pdf], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    @ViewBuilder
    private var featureToolbar: some View {
        switch appState.activeToolMode {
        case .annotate:
            AnnotationToolbarView()
            Divider()
        case .edit:
            EditorToolbarView()
            Divider()
        case .organize:
            EmptyView() // Organizer replaces the main content
        case .formSign:
            FormSignToolbarView()
            Divider()
        case .redact:
            RedactionToolbarView()
            Divider()
        case .ocr:
            OCRToolbarView()
            Divider()
        case .convert:
            ConverterToolbarView()
            Divider()
        case .compare:
            CompareToolbarView()
            Divider()
        case .protect:
            HStack {
                Button(action: { appState.showProtectionSheet = true }) {
                    Label("Set Password & Permissions", systemImage: "lock.shield")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                if appState.documentState.isEncrypted {
                    Label("Document is encrypted", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            Divider()
        case .eSignature:
            ESignatureToolbarView()
            Divider()
        case .viewer:
            EmptyView()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch appState.activeToolMode {
        case .organize:
            OrganizerView()
        case .compare:
            CompareContentView(compareDocument: appState.compareDocumentState?.pdfDocument)
        default:
            ViewerView()
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { item, _ in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        appState.openDocument(at: url)
                    }
                }
            }
        }
        return true
    }
}

import SwiftUI
import PDFKit

struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 0) {
            // Sejda-style horizontal tool mode tabs (only when doc is open)
            if appState.hasDocument {
                SejdaToolModeTabs()
                Divider()
            }

            // Feature toolbar (context-sensitive)
            if appState.hasDocument {
                featureToolbar
            }

            // Search bar
            if appState.showSearchBar {
                SearchBarView()
                Divider()
            }

            // Main content area
            HStack(spacing: 0) {
                // Left sidebar (thumbnails) — Sejda puts it left
                if appState.hasDocument && appState.showSidebar {
                    SidebarView()
                    Divider()
                }

                // Main content
                if appState.hasDocument {
                    mainContent
                } else {
                    WelcomeView()
                }
            }

            // Status bar
            if appState.hasDocument {
                Divider()
                StatusBarView()
            }
        }
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
        .frame(minWidth: 900, minHeight: 650)
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
            EmptyView()
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
            HStack(spacing: 12) {
                Button(action: { appState.showProtectionSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                        Text("Set Password & Permissions")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(SejdaTheme.primary)
                Spacer()
                if appState.documentState.isEncrypted {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(SejdaTheme.teal)
                        Text("Encrypted")
                            .font(.system(size: 12))
                            .foregroundColor(SejdaTheme.teal)
                    }
                }
            }
            .padding(.horizontal, 14)
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

// MARK: - Sejda-style Horizontal Tool Mode Tabs
struct SejdaToolModeTabs: View {
    @Environment(AppState.self) var appState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(ToolMode.allCases) { mode in
                    Button(action: { appState.activeToolMode = mode }) {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 12))
                            Text(mode.label)
                        }
                    }
                    .buttonStyle(SejdaTabButton(isSelected: appState.activeToolMode == mode))
                }
            }
            .padding(.horizontal, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

import SwiftUI
import PDFKit

class AcroromiAppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState = appState,
              appState.hasDocument,
              appState.documentState.hasUnsavedChanges else {
            return .terminateNow
        }
        let result = appState.showUnsavedChangesAlert()
        switch result {
        case .save:
            appState.saveDocument()
            return .terminateNow
        case .discard:
            return .terminateNow
        case .cancel:
            return .terminateCancel
        }
    }
}

@main
struct AcroromiApp: App {
    @NSApplicationDelegateAdaptor(AcroromiAppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    appDelegate.appState = appState
                }
                .onOpenURL { url in
                    appState.openDocument(at: url)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    appState.openDocument()
                }
                .keyboardShortcut("o")

                Divider()

                Button("Save") {
                    appState.saveDocument()
                }
                .keyboardShortcut("s")
                .disabled(!appState.hasDocument)

                Button("Save As...") {
                    appState.saveDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!appState.hasDocument)

                Divider()

                Button("Close") {
                    appState.closeDocument(promptSave: true)
                }
                .keyboardShortcut("w")
                .disabled(!appState.hasDocument)

                Divider()

                Button("Print...") {
                    if let doc = appState.documentState.pdfDocument {
                        PrintManager.printDocument(doc)
                    }
                }
                .keyboardShortcut("p")
                .disabled(!appState.hasDocument)
            }

            // Edit menu additions
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Find...") {
                    appState.showSearchBar.toggle()
                }
                .keyboardShortcut("f")
                .disabled(!appState.hasDocument)
            }

            // View menu
            CommandGroup(after: .toolbar) {
                Divider()

                Button("Zoom In") {
                    appState.documentState.scaleFactor = min(
                        AppConstants.maxZoom,
                        appState.documentState.scaleFactor + 0.25
                    )
                }
                .keyboardShortcut("+")
                .disabled(!appState.hasDocument)

                Button("Zoom Out") {
                    appState.documentState.scaleFactor = max(
                        AppConstants.minZoom,
                        appState.documentState.scaleFactor - 0.25
                    )
                }
                .keyboardShortcut("-")
                .disabled(!appState.hasDocument)

                Button("Actual Size") {
                    appState.documentState.scaleFactor = 1.0
                }
                .keyboardShortcut("0")
                .disabled(!appState.hasDocument)

                Divider()

                Button("Previous Page") {
                    if appState.documentState.currentPageIndex > 0 {
                        appState.documentState.currentPageIndex -= 1
                    }
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(!appState.hasDocument || appState.documentState.currentPageIndex <= 0)

                Button("Next Page") {
                    if appState.documentState.currentPageIndex < appState.documentState.totalPages - 1 {
                        appState.documentState.currentPageIndex += 1
                    }
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .disabled(!appState.hasDocument || appState.documentState.currentPageIndex >= appState.documentState.totalPages - 1)
            }

            // Tools menu
            CommandMenu("Tools") {
                ForEach(ToolMode.allCases) { mode in
                    Button(mode.label) {
                        appState.activeToolMode = mode
                    }
                }

                Divider()

                Button("Merge Files...") {
                    appState.activeToolMode = .organize
                    appState.showMergeSheet = true
                }

                Button("Protect Document...") {
                    appState.showProtectionSheet = true
                }
                .disabled(!appState.hasDocument)
            }
        }
    }
}

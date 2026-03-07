import SwiftUI
import PDFKit

struct MainToolbar: ToolbarContent {
    @Environment(AppState.self) var appState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { appState.showSidebar.toggle() }) {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle Sidebar")
        }

        ToolbarItemGroup(placement: .principal) {
            if appState.hasDocument {
                ToolModePicker()
            }
        }

        ToolbarItemGroup(placement: .automatic) {
            if appState.hasDocument {
                ZoomControls()
                DisplayModePicker()
            }
        }
    }
}

struct ToolModePicker: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState
        Picker("Mode", selection: $state.activeToolMode) {
            ForEach(ToolMode.allCases) { mode in
                Label(mode.label, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 160)
    }
}

struct ZoomControls: View {
    @Environment(AppState.self) var appState

    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                appState.documentState.scaleFactor = max(
                    AppConstants.minZoom,
                    appState.documentState.scaleFactor - 0.25
                )
            }) {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")

            Text(appState.documentState.zoomPercentage)
                .font(.caption)
                .frame(width: 45)

            Button(action: {
                appState.documentState.scaleFactor = min(
                    AppConstants.maxZoom,
                    appState.documentState.scaleFactor + 0.25
                )
            }) {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")
        }
    }
}

struct DisplayModePicker: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var docState = appState.documentState
        Picker("Display", selection: $docState.displayMode) {
            ForEach(PDFDisplayModeOption.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 140)
    }
}

struct PageNavigationBar: View {
    @Environment(AppState.self) var appState
    @State private var pageInputText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Button(action: goToPreviousPage) {
                Image(systemName: "chevron.left")
            }
            .disabled(appState.documentState.currentPageIndex <= 0)

            TextField("Page", text: $pageInputText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .onSubmit { goToPage() }

            Text("/ \(appState.documentState.totalPages)")
                .foregroundColor(.secondary)

            Button(action: goToNextPage) {
                Image(systemName: "chevron.right")
            }
            .disabled(appState.documentState.currentPageIndex >= appState.documentState.totalPages - 1)
        }
        .onChange(of: appState.documentState.currentPageIndex) { _, newValue in
            pageInputText = "\(newValue + 1)"
        }
        .onAppear {
            pageInputText = "\(appState.documentState.currentPageIndex + 1)"
        }
    }

    private func goToPage() {
        if let page = Int(pageInputText), page >= 1, page <= appState.documentState.totalPages {
            appState.documentState.currentPageIndex = page - 1
        } else {
            pageInputText = "\(appState.documentState.currentPageIndex + 1)"
        }
    }

    private func goToPreviousPage() {
        if appState.documentState.currentPageIndex > 0 {
            appState.documentState.currentPageIndex -= 1
        }
    }

    private func goToNextPage() {
        if appState.documentState.currentPageIndex < appState.documentState.totalPages - 1 {
            appState.documentState.currentPageIndex += 1
        }
    }
}

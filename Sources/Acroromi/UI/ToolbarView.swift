import SwiftUI
import PDFKit

struct MainToolbar: ToolbarContent {
    @Environment(AppState.self) var appState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { appState.showSidebar.toggle() }) {
                Image(systemName: appState.showSidebar ? "sidebar.leading" : "sidebar.left")
                    .foregroundColor(appState.showSidebar ? SejdaTheme.primary : .secondary)
            }
            .help("Toggle Pages Panel")
        }

        ToolbarItemGroup(placement: .principal) {
            if appState.hasDocument {
                HStack(spacing: 12) {
                    PageNavigationBar()
                    Divider().frame(height: 18)
                    ZoomControls()
                    Divider().frame(height: 18)
                    DisplayModePicker()
                }
            }
        }
    }
}

struct ZoomControls: View {
    @Environment(AppState.self) var appState

    var body: some View {
        HStack(spacing: 2) {
            Button(action: {
                appState.documentState.scaleFactor = max(
                    AppConstants.minZoom,
                    appState.documentState.scaleFactor - 0.25
                )
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .help("Zoom Out")

            Text(appState.documentState.zoomPercentage)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(SejdaTheme.textSecondary)
                .frame(width: 42)

            Button(action: {
                appState.documentState.scaleFactor = min(
                    AppConstants.maxZoom,
                    appState.documentState.scaleFactor + 0.25
                )
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .help("Zoom In")
        }
    }
}

struct DisplayModePicker: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var docState = appState.documentState
        Picker("", selection: $docState.displayMode) {
            ForEach(PDFDisplayModeOption.allCases) { mode in
                Label(mode.label, systemImage: mode.icon).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 150)
    }
}

struct PageNavigationBar: View {
    @Environment(AppState.self) var appState
    @State private var pageInputText: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Button(action: goToPreviousPage) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(appState.documentState.currentPageIndex <= 0)

            HStack(spacing: 2) {
                TextField("", text: $pageInputText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 36)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 11))
                    .onSubmit { goToPage() }

                Text("/")
                    .font(.system(size: 11))
                    .foregroundColor(SejdaTheme.textSecondary)

                Text("\(appState.documentState.totalPages)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SejdaTheme.textSecondary)
            }

            Button(action: goToNextPage) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
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

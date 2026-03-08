import SwiftUI

struct SearchBarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var docState = appState.documentState
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(SejdaTheme.textSecondary)

            TextField("Find in document...", text: $docState.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit {
                    appState.documentState.performSearch()
                }

            if !appState.documentState.searchResults.isEmpty {
                Text("\(appState.documentState.currentSearchIndex + 1)/\(appState.documentState.searchResults.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(SejdaTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SejdaTheme.controlBg)
                    .cornerRadius(4)

                Button(action: { _ = appState.documentState.previousSearchResult() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderless)

                Button(action: { _ = appState.documentState.nextSearchResult() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderless)
            }

            Button(action: {
                appState.showSearchBar = false
                appState.documentState.searchText = ""
                appState.documentState.searchResults = []
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(SejdaTheme.textSecondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

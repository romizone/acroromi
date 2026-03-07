import SwiftUI

struct SearchBarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var docState = appState.documentState
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Find in document...", text: $docState.searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    appState.documentState.performSearch()
                }

            if !appState.documentState.searchResults.isEmpty {
                Text("\(appState.documentState.currentSearchIndex + 1)/\(appState.documentState.searchResults.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: { _ = appState.documentState.previousSearchResult() }) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)

                Button(action: { _ = appState.documentState.nextSearchResult() }) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
            }

            Button(action: {
                appState.showSearchBar = false
                appState.documentState.searchText = ""
                appState.documentState.searchResults = []
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

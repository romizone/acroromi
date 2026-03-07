import SwiftUI

struct StatusBarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        HStack {
            if appState.hasDocument {
                PageNavigationBar()

                Spacer()

                Text(appState.documentState.zoomPercentage)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider().frame(height: 14)

                Text(appState.documentState.fileName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Spacer()
                Text("No document open")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

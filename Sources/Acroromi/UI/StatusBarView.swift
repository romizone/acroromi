import SwiftUI

struct StatusBarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        HStack(spacing: 12) {
            if appState.hasDocument {
                HStack(spacing: 5) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 9))
                        .foregroundColor(SejdaTheme.primary)
                    Text(appState.documentState.fileName)
                        .font(.system(size: 11))
                        .foregroundColor(SejdaTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if appState.documentState.hasUnsavedChanges {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(SejdaTheme.warning)
                            .frame(width: 6, height: 6)
                        Text("Modified")
                            .font(.system(size: 10))
                            .foregroundColor(SejdaTheme.warning)
                    }
                }

                Divider().frame(height: 12)

                Text(appState.documentState.zoomPercentage)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(SejdaTheme.textSecondary)

                Divider().frame(height: 12)

                Text("Page \(appState.documentState.currentPageIndex + 1) of \(appState.documentState.totalPages)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(SejdaTheme.textSecondary)
            } else {
                Spacer()
                Text("No document open")
                    .font(.system(size: 11))
                    .foregroundColor(SejdaTheme.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

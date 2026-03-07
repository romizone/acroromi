import SwiftUI

enum AppConstants {
    static let appName = "Acroromi"
    static let appVersion = "1.0.0"
    static let sidebarMinWidth: CGFloat = 180
    static let sidebarMaxWidth: CGFloat = 300
    static let thumbnailSize = CGSize(width: 150, height: 200)
    static let minZoom: CGFloat = 0.25
    static let maxZoom: CGFloat = 8.0
    static let defaultZoom: CGFloat = 1.0
    static let maxRecentDocuments = 10

    enum Colors {
        static let highlight = Color.yellow.opacity(0.4)
        static let redaction = Color.black
        static let annotationDefault = Color.yellow
        static let stickyNote = Color.yellow
        static let ink = Color.red
        static let searchHighlight = Color.green.opacity(0.3)
    }
}

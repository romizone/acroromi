import SwiftUI

struct SidebarButtonStyle: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(configuration.isPressed ? Color.gray.opacity(0.2) : Color.clear)
            .cornerRadius(6)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

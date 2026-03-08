import SwiftUI

// MARK: - Sejda-inspired Color Theme
enum SejdaTheme {
    static let primary = Color(red: 0.016, green: 0.510, blue: 0.898)
    static let primaryDark = Color(red: 0.012, green: 0.400, blue: 0.750)
    static let primaryLight = Color(red: 0.255, green: 0.631, blue: 0.941)

    static let toolbarBg = Color(nsColor: .windowBackgroundColor)
    static let sidebarBg = Color(red: 0.976, green: 0.957, blue: 0.930).opacity(0.97)
    static let canvasBg = Color(red: 0.545, green: 0.573, blue: 0.600)
    static let controlBg = Color(red: 0.910, green: 0.910, blue: 0.910)
    static let hoverBg = Color(red: 0.910, green: 0.910, blue: 0.910).opacity(0.6)

    static let teal = Color(red: 0.0, green: 0.733, blue: 0.533)
    static let danger = Color(red: 0.898, green: 0.224, blue: 0.208)
    static let warning = Color(red: 0.976, green: 0.659, blue: 0.145)

    static let textPrimary = Color(red: 0.180, green: 0.204, blue: 0.231)
    static let textSecondary = Color(red: 0.467, green: 0.498, blue: 0.529)

    static let editGradient = LinearGradient(colors: [
        Color(red: 0.922, green: 0.961, blue: 0.996), Color.white
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let convertGradient = LinearGradient(colors: [
        Color(red: 1.0, green: 0.949, blue: 0.922), Color.white
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let organizeGradient = LinearGradient(colors: [
        Color(red: 0.914, green: 0.976, blue: 0.941), Color.white
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let securityGradient = LinearGradient(colors: [
        Color(red: 0.961, green: 0.922, blue: 0.996), Color.white
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Sejda Toolbar Button
struct SejdaToolbarButton: ButtonStyle {
    var isSelected: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? SejdaTheme.primary : SejdaTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? SejdaTheme.primary.opacity(0.12) :
                          configuration.isPressed ? SejdaTheme.hoverBg : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? SejdaTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
    }
}

// MARK: - Sejda Card
struct SejdaCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Sejda Tool Card (Welcome grid)
struct SejdaToolCard: ButtonStyle {
    var iconColor: Color = SejdaTheme.primary
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.12 : 0.06),
                            radius: configuration.isPressed ? 2 : 6,
                            x: 0, y: configuration.isPressed ? 1 : 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Sejda Tab Button (horizontal top tabs)
struct SejdaTabButton: ButtonStyle {
    var isSelected: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? SejdaTheme.primary : SejdaTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            Rectangle()
                .fill(isSelected ? SejdaTheme.primary : Color.clear)
                .frame(height: 2)
        }
        .background(isSelected ? SejdaTheme.primary.opacity(0.06) :
                     (configuration.isPressed ? SejdaTheme.hoverBg : Color.clear))
    }
}

// MARK: - Compat Styles
struct SidebarButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? SejdaTheme.primary.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .foregroundColor(isSelected ? SejdaTheme.primary : .primary)
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(configuration.isPressed ? SejdaTheme.hoverBg : Color.clear)
            .cornerRadius(6)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(SejdaCardStyle())
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
    func sejdaCard() -> some View { modifier(SejdaCardStyle()) }
}

import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @Environment(AppState.self) var appState
    @State private var isTargeted = false
    @State private var hoveredTool: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(SejdaTheme.primary)
                        Text("Acroromi")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(SejdaTheme.textPrimary)
                    }
                    Text("Your PDF tasks, simplified.")
                        .font(.system(size: 15))
                        .foregroundColor(SejdaTheme.textSecondary)
                }
                .padding(.top, 32)

                // Open / Drop zone
                HStack(spacing: 16) {
                    Button(action: { appState.openDocument() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16))
                            Text("Open PDF File")
                                .fontWeight(.semibold)
                        }
                        .frame(width: 180, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SejdaTheme.primary)
                    .controlSize(.large)

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                            .foregroundColor(isTargeted ? SejdaTheme.primary : SejdaTheme.textSecondary.opacity(0.4))
                            .frame(width: 220, height: 44)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc")
                                .foregroundColor(SejdaTheme.textSecondary)
                            Text("or drop PDF here")
                                .font(.system(size: 13))
                                .foregroundColor(SejdaTheme.textSecondary)
                        }
                    }
                    .onDrop(of: [UTType.pdf], isTargeted: $isTargeted) { providers in
                        handleDrop(providers)
                    }
                }

                // Tool categories grid — Sejda style
                VStack(alignment: .leading, spacing: 20) {
                    // EDIT & SIGN
                    toolSection(
                        title: "EDIT & SIGN",
                        icon: "pencil.and.outline",
                        color: SejdaTheme.primary,
                        tools: [
                            ("pencil", "Edit Text", "Edit existing text", { setModeAndOpen(.edit) }),
                            ("pencil.and.outline", "Annotate", "Highlight, draw, notes", { setModeAndOpen(.annotate) }),
                            ("signature", "Fill & Sign", "Fill forms, sign", { setModeAndOpen(.formSign) }),
                            ("pencil.and.list.clipboard", "E-Signature", "Digital signatures", { setModeAndOpen(.eSignature) }),
                        ]
                    )

                    // ORGANIZE
                    toolSection(
                        title: "ORGANIZE PAGES",
                        icon: "rectangle.stack",
                        color: SejdaTheme.teal,
                        tools: [
                            ("rectangle.stack", "Organize", "Merge, split, rotate", { setModeAndOpen(.organize) }),
                            ("doc.on.doc", "Compare", "Diff two PDFs", { setModeAndOpen(.compare) }),
                        ]
                    )

                    // CONVERT
                    toolSection(
                        title: "CONVERT",
                        icon: "arrow.triangle.2.circlepath",
                        color: SejdaTheme.warning,
                        tools: [
                            ("arrow.triangle.2.circlepath", "Convert", "PDF ↔ Images, Text", { setModeAndOpen(.convert) }),
                            ("text.viewfinder", "OCR", "Scan & recognize text", { setModeAndOpen(.ocr) }),
                        ]
                    )

                    // SECURITY
                    toolSection(
                        title: "SECURITY",
                        icon: "lock.shield",
                        color: Color.purple,
                        tools: [
                            ("lock.shield", "Protect", "Password & permissions", { setModeAndOpen(.protect) }),
                            ("eye.slash", "Redact", "Hide sensitive info", { setModeAndOpen(.redact) }),
                        ]
                    )
                }
                .padding(.horizontal, 40)

                // Recent Documents
                if !appState.recentDocuments.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(SejdaTheme.textSecondary)
                            Text("RECENT DOCUMENTS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(SejdaTheme.textSecondary)
                                .tracking(0.5)
                        }

                        ForEach(appState.recentDocuments, id: \.self) { url in
                            Button(action: { appState.openDocument(at: url) }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(SejdaTheme.primary)
                                        .frame(width: 20)
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 13))
                                        .foregroundColor(SejdaTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(SejdaTheme.textSecondary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 40)
                }

                Spacer(minLength: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Tool Section
    @ViewBuilder
    private func toolSection(title: String, icon: String, color: Color, tools: [(String, String, String, () -> Void)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SejdaTheme.textSecondary)
                    .tracking(0.5)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(tools, id: \.1) { iconName, label, desc, action in
                    Button(action: action) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(color.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: iconName)
                                    .font(.system(size: 16))
                                    .foregroundColor(color)
                            }
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(SejdaTheme.textPrimary)
                            Text(desc)
                                .font(.system(size: 10))
                                .foregroundColor(SejdaTheme.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(SejdaToolCard(iconColor: color))
                }
            }
        }
    }

    private func setModeAndOpen(_ mode: ToolMode) {
        if appState.hasDocument {
            appState.activeToolMode = mode
        } else {
            appState.openDocument()
            // After opening, set the mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if appState.hasDocument {
                    appState.activeToolMode = mode
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async { appState.openDocument(at: url) }
                } else if let url = item as? URL {
                    DispatchQueue.main.async { appState.openDocument(at: url) }
                }
            }
        }
        return true
    }
}

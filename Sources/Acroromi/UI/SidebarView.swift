import SwiftUI
import PDFKit

struct SidebarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 0) {
            // Sejda-style tab icons row
            HStack(spacing: 0) {
                ForEach(SidebarTab.allCases) { tab in
                    Button(action: { appState.activeSidebarTab = tab }) {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                            Text(tab.label)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundColor(appState.activeSidebarTab == tab ?
                                        SejdaTheme.primary : SejdaTheme.textSecondary)
                        .background(appState.activeSidebarTab == tab ?
                                   SejdaTheme.primary.opacity(0.08) : Color.clear)
                        .overlay(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(appState.activeSidebarTab == tab ? SejdaTheme.primary : Color.clear)
                                    .frame(height: 2)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Tab content
            switch appState.activeSidebarTab {
            case .thumbnails:
                ThumbnailListView()
            case .bookmarks:
                BookmarkListView()
            case .annotations:
                AnnotationListView()
            case .search:
                SearchSidebarView()
            }
        }
        .frame(width: 190)
        .background(SejdaTheme.sidebarBg)
    }
}

struct ThumbnailListView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if let doc = appState.documentState.pdfDocument {
                        ForEach(0..<doc.pageCount, id: \.self) { index in
                            ThumbnailItemView(
                                document: doc,
                                pageIndex: index,
                                isSelected: appState.documentState.currentPageIndex == index
                            )
                            .id(index)
                            .onTapGesture {
                                appState.documentState.currentPageIndex = index
                            }
                        }
                    }
                }
                .padding(8)
            }
            .onChange(of: appState.documentState.currentPageIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

struct ThumbnailItemView: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let page = document.page(at: pageIndex) {
                let thumb = page.thumbnail(of: CGSize(width: 140, height: 190), for: .mediaBox)
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 160, maxHeight: 180)
                    .background(Color.white)
                    .cornerRadius(3)
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isSelected ? SejdaTheme.primary : Color.clear, lineWidth: 2.5)
                    )
            }
            Text("\(pageIndex + 1)")
                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? SejdaTheme.primary : SejdaTheme.textSecondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? SejdaTheme.primary.opacity(0.08) : Color.clear)
        )
    }
}

struct BookmarkListView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if let outline = appState.documentState.pdfDocument?.outlineRoot {
                    OutlineNodeView(outline: outline, level: 0)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "bookmark.slash")
                            .font(.title3)
                            .foregroundColor(SejdaTheme.textSecondary)
                        Text("No bookmarks")
                            .font(.system(size: 12))
                            .foregroundColor(SejdaTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(8)
        }
    }
}

struct OutlineNodeView: View {
    let outline: PDFOutline
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<outline.numberOfChildren, id: \.self) { index in
                if let child = outline.child(at: index) {
                    OutlineItemView(item: child, level: level)
                }
            }
        }
    }
}

struct OutlineItemView: View {
    let item: PDFOutline
    let level: Int
    @Environment(AppState.self) var appState
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if item.numberOfChildren > 0 {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(SejdaTheme.textSecondary)
                        .frame(width: 12)
                        .onTapGesture { isExpanded.toggle() }
                }
                Button(action: {
                    if let dest = item.destination,
                       let page = dest.page,
                       let doc = appState.documentState.pdfDocument {
                        appState.documentState.currentPageIndex = doc.index(for: page)
                    }
                }) {
                    Text(item.label ?? "Untitled")
                        .font(.system(size: 11))
                        .foregroundColor(SejdaTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, CGFloat(level * 14))

            if isExpanded && item.numberOfChildren > 0 {
                OutlineNodeView(outline: item, level: level + 1)
            }
        }
    }
}

struct AnnotationListView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                if let doc = appState.documentState.pdfDocument {
                    let allAnnotations = collectAnnotations(from: doc)
                    if allAnnotations.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "text.bubble")
                                .font(.title3)
                                .foregroundColor(SejdaTheme.textSecondary)
                            Text("No annotations")
                                .font(.system(size: 12))
                                .foregroundColor(SejdaTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(Array(allAnnotations.enumerated()), id: \.offset) { _, item in
                            AnnotationItemView(annotation: item.annotation, pageIndex: item.pageIndex)
                                .onTapGesture {
                                    appState.documentState.currentPageIndex = item.pageIndex
                                }
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    struct AnnotationItem {
        let annotation: PDFAnnotation
        let pageIndex: Int
    }

    func collectAnnotations(from doc: PDFDocument) -> [AnnotationItem] {
        var items: [AnnotationItem] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            for annotation in page.annotations {
                if annotation.type == "Link" || annotation.type == "Widget" { continue }
                items.append(AnnotationItem(annotation: annotation, pageIndex: i))
            }
        }
        return items
    }
}

struct AnnotationItemView: View {
    let annotation: PDFAnnotation
    let pageIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForAnnotation(annotation))
                .font(.system(size: 11))
                .foregroundColor(SejdaTheme.primary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(annotation.type ?? "Annotation")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(SejdaTheme.textPrimary)
                if let contents = annotation.contents, !contents.isEmpty {
                    Text(contents)
                        .font(.system(size: 9))
                        .foregroundColor(SejdaTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text("p.\(pageIndex + 1)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(SejdaTheme.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(SejdaTheme.controlBg)
                .cornerRadius(4)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    func iconForAnnotation(_ annotation: PDFAnnotation) -> String {
        switch annotation.type {
        case "Highlight": return "highlighter"
        case "Underline": return "underline"
        case "StrikeOut": return "strikethrough"
        case "Text": return "note.text"
        case "FreeText": return "textformat"
        case "Ink": return "scribble"
        case "Square": return "rectangle"
        case "Circle": return "circle"
        case "Line": return "line.diagonal"
        default: return "square.and.pencil"
        }
    }
}

struct SearchSidebarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var docState = appState.documentState
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(SejdaTheme.textSecondary)
                TextField("Search...", text: $docState.searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .onSubmit {
                        appState.documentState.performSearch()
                    }
            }
            .padding(.horizontal, 8)

            if !appState.documentState.searchResults.isEmpty {
                HStack {
                    Text("\(appState.documentState.searchResults.count) results")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(SejdaTheme.textSecondary)
                    Spacer()
                    Button(action: { _ = appState.documentState.previousSearchResult() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    Button(action: { _ = appState.documentState.nextSearchResult() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 8)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(appState.documentState.searchResults.enumerated()), id: \.offset) { idx, selection in
                        Button(action: {
                            appState.documentState.currentSearchIndex = idx
                            if let page = selection.pages.first,
                               let doc = appState.documentState.pdfDocument {
                                appState.documentState.currentPageIndex = doc.index(for: page)
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selection.string ?? "")
                                    .font(.system(size: 10))
                                    .foregroundColor(SejdaTheme.textPrimary)
                                    .lineLimit(2)
                                if let page = selection.pages.first,
                                   let doc = appState.documentState.pdfDocument {
                                    Text("Page \(doc.index(for: page) + 1)")
                                        .font(.system(size: 9))
                                        .foregroundColor(SejdaTheme.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(idx == appState.documentState.currentSearchIndex ?
                                        SejdaTheme.primary.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.top, 8)
    }
}

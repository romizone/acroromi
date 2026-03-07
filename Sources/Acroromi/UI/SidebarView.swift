import SwiftUI
import PDFKit

struct SidebarView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $state.activeSidebarTab) {
                ForEach(SidebarTab.allCases) { tab in
                    Image(systemName: tab.icon)
                        .tag(tab)
                        .help(tab.label)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

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
        .frame(minWidth: AppConstants.sidebarMinWidth, maxWidth: AppConstants.sidebarMaxWidth)
    }
}

struct ThumbnailListView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
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
                let thumb = page.thumbnail(of: AppConstants.thumbnailSize, for: .mediaBox)
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .border(isSelected ? Color.accentColor : Color.gray.opacity(0.3), width: isSelected ? 3 : 1)
                    .shadow(color: .black.opacity(0.1), radius: 2)
            }
            Text("\(pageIndex + 1)")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .padding(4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
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
                    Text("No bookmarks")
                        .foregroundColor(.secondary)
                        .padding()
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

/// Each outline item manages its own expand/collapse state independently
struct OutlineItemView: View {
    let item: PDFOutline
    let level: Int
    @Environment(AppState.self) var appState
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if item.numberOfChildren > 0 {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                        .font(.callout)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, CGFloat(level * 16))

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
            LazyVStack(alignment: .leading, spacing: 8) {
                if let doc = appState.documentState.pdfDocument {
                    let allAnnotations = collectAnnotations(from: doc)
                    if allAnnotations.isEmpty {
                        Text("No annotations")
                            .foregroundColor(.secondary)
                            .padding()
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
        HStack {
            Image(systemName: iconForAnnotation(annotation))
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(annotation.type ?? "Annotation")
                    .font(.caption)
                    .fontWeight(.medium)
                if let contents = annotation.contents, !contents.isEmpty {
                    Text(contents)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text("p.\(pageIndex + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
            HStack {
                TextField("Search...", text: $docState.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        appState.documentState.performSearch()
                    }
                Button(action: { appState.documentState.performSearch() }) {
                    Image(systemName: "magnifyingglass")
                }
            }
            .padding(.horizontal, 8)

            if !appState.documentState.searchResults.isEmpty {
                HStack {
                    Text("\(appState.documentState.searchResults.count) results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { _ = appState.documentState.previousSearchResult() }) {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    Button(action: { _ = appState.documentState.nextSearchResult() }) {
                        Image(systemName: "chevron.down")
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
                                    .font(.caption)
                                    .lineLimit(2)
                                if let page = selection.pages.first,
                                   let doc = appState.documentState.pdfDocument {
                                    Text("Page \(doc.index(for: page) + 1)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(idx == appState.documentState.currentSearchIndex ?
                                        Color.accentColor.opacity(0.1) : Color.clear)
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

import SwiftUI
import PDFKit

struct ThumbnailStripView: View {
    let document: PDFDocument
    @Binding var currentPage: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        ThumbnailStripItem(
                            document: document,
                            pageIndex: index,
                            isSelected: currentPage == index
                        )
                        .id(index)
                        .onTapGesture {
                            currentPage = index
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 80)
            .onChange(of: currentPage) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

struct ThumbnailStripItem: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            if let page = document.page(at: pageIndex) {
                let thumb = page.thumbnail(of: CGSize(width: 50, height: 65), for: .mediaBox)
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 65)
                    .border(isSelected ? Color.accentColor : Color.clear, width: 2)
            }
            Text("\(pageIndex + 1)")
                .font(.system(size: 9))
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
    }
}

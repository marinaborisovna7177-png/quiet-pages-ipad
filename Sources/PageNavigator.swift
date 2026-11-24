import SwiftUI
import PencilKit

// Page grid inspired by professional note apps; works with local PencilKit data.
struct PageNavigator: View {
    let book: Notebook
    @Binding var currentPage: Int
    let library: NotebookLibrary
    let duplicate: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 18)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(Array(book.pages.enumerated()), id: \.element.id) { index, page in
                        VStack(spacing: 8) {
                            Button {
                                currentPage = index
                                dismiss()
                            } label: {
                                PagePreview(page: page, library: library)
                                    .aspectRatio(0.73, contentMode: .fit)
                                    .overlay(RoundedRectangle(cornerRadius: 9)
                                        .stroke(index == currentPage ? AppPalette.rose : .clear, lineWidth: 3))
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                    .shadow(color: .black.opacity(0.11), radius: 6, y: 3)
                            }.buttonStyle(.plain)
                            HStack {
                                Text("Страница \(index + 1)")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer(minLength: 4)
                                Button {
                                    library.shiftPage(book: book.id, page: page.id, delta: -1)
                                    if currentPage == index { currentPage = max(0, index - 1) }
                                    else if currentPage == index - 1 { currentPage += 1 }
                                } label: { Image(systemName: "arrow.left") }
                                    .disabled(index == 0)
                                Button {
                                    library.shiftPage(book: book.id, page: page.id, delta: 1)
                                    if currentPage == index { currentPage = index + 1 }
                                    else if currentPage == index + 1 { currentPage -= 1 }
                                } label: { Image(systemName: "arrow.right") }
                                    .disabled(index >= book.pages.count - 1)
                                Button { duplicate(page.id); dismiss() } label: {
                                    Image(systemName: "plus.square.on.square")
                                        .foregroundStyle(AppPalette.rose)
                                }
                                .accessibilityLabel("Дублировать страницу")
                            }.foregroundStyle(AppPalette.midnight)
                        }
                    }
                }.padding(22)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Все страницы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Готово") { dismiss() }
            } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PagePreview: View {
    let page: NotebookPage
    let library: NotebookLibrary
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                PaperBackground(style: page.paper, customHex: page.customPaperHex,
                                decorationOpacity: page.decorationOpacity ?? 1)
                if let background = page.backgroundFile, let img = library.photo(named: background) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                }
                let drawing = library.drawing(for: page.id)
                if !drawing.strokes.isEmpty {
                    Image(uiImage: drawing.image(from: CGRect(x: 0, y: 0, width: 650, height: 880), scale: 0.4))
                        .resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height)
                }
                ForEach(page.items) { item in
                    if !item.hidden {
                    Group {
                        switch item.kind {
                        case .sticker:
                            Image("Sticker_\(item.value)").resizable().scaledToFit()
                        case .customSticker, .photo:
                            if let image = library.photo(named: item.value) {
                                Image(uiImage: image).resizable().scaledToFit()
                            }
                        case .text:
                            Text(item.value).font(.system(size: 7))
                        case .shape:
                            Image(systemName: item.value == "circle" ? "circle" : item.value == "rectangle" ? "rectangle" : item.value == "arrow" ? "arrow.right" : "line.diagonal")
                                .resizable().scaledToFit()
                        }
                    }
                    .frame(width: geo.size.width * (item.kind == .sticker && item.value.hasPrefix("Frame") ? 0.90 : 0.22),
                           height: item.kind == .sticker && item.value.hasPrefix("Frame") ? geo.size.height * 0.93 : geo.size.width * 0.22)
                    .position(x: geo.size.width * item.x, y: geo.size.height * item.y)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

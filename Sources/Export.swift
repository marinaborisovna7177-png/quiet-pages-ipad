import SwiftUI
import PencilKit

struct SharedDocument: Identifiable {
    var id: UUID = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

@MainActor
enum PDFNotebookExporter {
    static let pageSize = CGSize(width: 700, height: 700 / 0.735)
    static func image(page: NotebookPage, store: NotebookLibrary) throws -> UIImage {
        let renderer = ImageRenderer(content: ExportPage(page: page, store: store).frame(width: pageSize.width, height: pageSize.height))
        renderer.scale = 2
        guard let image = renderer.uiImage else {
            throw NSError(domain: "QuietPages.Export", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось подготовить изображение страницы"])
        }
        return image
    }
    static func export(book: Notebook, store: NotebookLibrary) throws -> URL {
        let bounds = CGRect(origin: .zero, size: pageSize)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("QuietPages-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        var renderError: Error?
        try renderer.writePDF(to: url) { context in
            for page in book.pages {
                autoreleasepool {
                    do {
                        let image = try image(page: page, store: store)
                        context.beginPage()
                        image.draw(in: bounds)
                    } catch { renderError = error }
                }
                if renderError != nil { break }
            }
        }
        if let renderError {
            try? FileManager.default.removeItem(at: url)
            throw renderError
        }
        return url
    }
    static func exportPNG(page: NotebookPage, store: NotebookLibrary) throws -> URL {
        let output = try image(page: page, store: store)
        guard let data = output.pngData() else {
            throw NSError(domain: "QuietPages.Export", code: 2, userInfo: [NSLocalizedDescriptionKey: "Ошибка PNG"])
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("QuietPages-\(UUID().uuidString).png")
        try data.write(to: url, options: .atomic)
        return url
    }
}

private struct ExportPage: View {
    let page: NotebookPage
    let store: NotebookLibrary
    private let size = PDFNotebookExporter.pageSize
    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground(style: page.paper, customHex: page.customPaperHex,
                            decorationOpacity: page.decorationOpacity ?? 1)
                .overlay { Image("PaperGrain").resizable().scaledToFill().opacity(0.48) }
            if let file = page.backgroundFile, let image = store.photo(named: file) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
            }
            ForEach(page.items.filter { !$0.hidden }) { item in
                PageObjectContent(item: item, library: store, width: size.width, height: size.height)
                    .scaleEffect(item.scale)
                    .rotationEffect(.degrees(item.angle))
                    .shadow(color: .black.opacity(0.13), radius: 3, y: 2)
                    .opacity(item.opacity)
                    .scaleEffect(x: item.flipped ? -1 : 1, y: 1)
                    .position(x: size.width * item.x, y: size.height * item.y)
            }
            let storedSize = store.inkCanvasSize(page: page.id) ?? size
            let drawing = store.drawing(for: page.id)
            if !drawing.bounds.isNull {
                Image(uiImage: drawing.image(from: CGRect(origin: .zero, size: storedSize), scale: 2))
                    .resizable().frame(width: size.width, height: size.height)
            }
        }
        .frame(width: size.width, height: size.height).clipped()
    }
}

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
    static func export(book: Notebook, store: NotebookLibrary) throws -> URL {
        let bounds = CGRect(x: 0, y: 0, width: 816, height: 1118)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let safeName = book.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(6)).pdf")
        try renderer.writePDF(to: url) { context in
            for (number, page) in book.pages.enumerated() {
                context.beginPage()
                render(page: page, book: book, store: store, pageNumber: number + 1, bounds: bounds)
            }
        }
        return url
    }

    private static func render(page: NotebookPage, book: Notebook, store: NotebookLibrary, pageNumber: Int, bounds: CGRect) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        // Экспортирует те же шаблоны, что пользователь видит на страницах iPad.
        let paperRenderer = ImageRenderer(content: PaperBackground(style: page.paper, customHex: page.customPaperHex)
            .frame(width: bounds.width, height: bounds.height))
        paperRenderer.scale = 1
        if let image = paperRenderer.uiImage {
            image.draw(in: bounds)
        } else {
            UIColor(Color(hex: page.customPaperHex ?? PaperCatalog.find(page.paper)?.background ?? 0xFFFDF7)).setFill()
            cg.fill(bounds)
        }
        if let background = page.backgroundFile, let image = store.photo(named: background) {
            image.draw(in: bounds)
        }

        for item in page.items {
            let center = CGPoint(x: bounds.width * item.x, y: bounds.height * item.y)
            cg.saveGState()
            cg.translateBy(x: center.x, y: center.y)
            cg.rotate(by: item.angle * .pi / 180.0)
            cg.scaleBy(x: item.scale, y: item.scale)
            switch item.kind {
            case .sticker:
                if let image = UIImage(named: "Sticker_\(item.value)") {
                    if item.value.hasPrefix("Frame") {
                        image.draw(in: CGRect(x: -375, y: -524, width: 750, height: 1048))
                    } else {
                        image.draw(in: CGRect(x: -91, y: -91, width: 182, height: 182))
                    }
                }
            case .customSticker:
                if let image = store.photo(named: item.value) {
                    image.draw(in: CGRect(x: -105, y: -105, width: 210, height: 210))
                }
            case .photo:
                if let img = store.photo(named: item.value) {
                    UIColor.white.setFill(); cg.fill(CGRect(x: -149, y: -149, width: 298, height: 298))
                    img.draw(in: CGRect(x: -138, y: -138, width: 276, height: 276))
                }
            case .text:
                let textStyle = item.textStyle ?? PageTextStyle()
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = textStyle.alignment == "left" ? .left : textStyle.alignment == "right" ? .right : .center
                let fontSize = CGFloat(textStyle.fontSize) * bounds.width / 650
                let fieldFactor = CGFloat(item.textWidthFactor ?? 0.66)
                let textRect = CGRect(x: -bounds.width * fieldFactor / 2, y: -105,
                                      width: bounds.width * fieldFactor, height: 210)
                if let background = textStyle.backgroundHex {
                    UIColor(Color(hex: background)).withAlphaComponent(0.90).setFill()
                    UIBezierPath(roundedRect: textRect.insetBy(dx: -10, dy: -5), cornerRadius: 10).fill()
                }
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: textStyle.fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize),
                    .foregroundColor: UIColor(Color(hex: textStyle.colorHex)).withAlphaComponent(CGFloat(textStyle.opacity)),
                    .paragraphStyle: paragraph,
                    .kern: textStyle.letterSpacing * bounds.width / 650
                ]
                (item.value as NSString).draw(in: textRect, withAttributes: attrs)
            }
            cg.restoreGState()
        }

        // PDF: рукописный слой поверх наклеек, как на экране iPad.
        let drawing = store.drawing(for: page.id)
        if !drawing.bounds.isNull {
            let fitted = drawing.image(from: CGRect(origin: .zero,
                size: CGSize(width: bounds.width, height: bounds.height)), scale: 1.0)
            fitted.draw(in: bounds)
        }

        let footer: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Georgia", size: 13) ?? UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor(red: 0.58, green: 0.52, blue: 0.55, alpha: 0.8)
        ]
        if page.backgroundFile == nil {
            ("quiet pages · \(pageNumber)" as NSString).draw(at: CGPoint(x: 40, y: bounds.height - 34), withAttributes: footer)
        }
    }
}

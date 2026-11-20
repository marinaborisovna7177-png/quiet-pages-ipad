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
        let mainColor: UIColor
        switch page.paper {
        case "Rose Lines", "Blush": mainColor = UIColor(red: 1, green: 0.94, blue: 0.94, alpha: 1)
        case "Lilac": mainColor = UIColor(red: 0.96, green: 0.94, blue: 0.99, alpha: 1)
        case "Vintage", "Cream Grid", "Daily Plan", "Checklist", "Cornell": mainColor = UIColor(red: 1, green: 0.966, blue: 0.916, alpha: 1)
        case "Sage": mainColor = UIColor(red: 0.95, green: 0.97, blue: 0.93, alpha: 1)
        case "Dark": mainColor = UIColor(red: 0.2, green: 0.22, blue: 0.26, alpha: 1)
        default: mainColor = UIColor(red: 1, green: 0.992, blue: 0.97, alpha: 1)
        }
        mainColor.setFill(); cg.fill(bounds)
        if let background = page.backgroundFile, let image = store.photo(named: background) {
            image.draw(in: bounds)
        }
        if ["Lines", "Grid", "Rose Lines", "Cream Grid", "Cornell"].contains(page.paper) {
            cg.setStrokeColor(UIColor(red: 0.72, green: 0.77, blue: 0.84, alpha: 0.36).cgColor)
            cg.setLineWidth(0.7)
            for y in stride(from: CGFloat(74), through: bounds.height - 40, by: 36) {
                cg.move(to: CGPoint(x: 28, y: y)); cg.addLine(to: CGPoint(x: bounds.width - 28, y: y))
            }
            if ["Grid", "Cream Grid"].contains(page.paper) {
                for x in stride(from: CGFloat(30), through: bounds.width - 28, by: 36) {
                    cg.move(to: CGPoint(x: x, y: 25)); cg.addLine(to: CGPoint(x: x, y: bounds.height - 30))
                }
            }
            cg.strokePath()
        } else if page.paper == "Dots" {
            cg.setFillColor(UIColor(red: 0.67, green: 0.65, blue: 0.72, alpha: 0.3).cgColor)
            for y in stride(from: CGFloat(30), through: bounds.height - 20, by: 33) {
                for x in stride(from: CGFloat(30), through: bounds.width - 20, by: 33) {
                    cg.fillEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                }
            }
        }

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 22),
            .foregroundColor: UIColor(red: 0.64, green: 0.40, blue: 0.51, alpha: 0.7)
        ]
        if page.backgroundFile == nil {
            ("dear diary," as NSString).draw(at: CGPoint(x: 40, y: 30), withAttributes: headerAttrs)
        }

        let drawing = store.drawing(for: page.id)
        if drawing.bounds.isNull == false {
            let fitted = drawing.image(from: CGRect(origin: .zero, size: CGSize(width: bounds.width, height: bounds.height)), scale: 1.0)
            fitted.draw(in: bounds)
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
                    image.draw(in: CGRect(x: -91, y: -91, width: 182, height: 182))
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
                let style = NSMutableParagraphStyle(); style.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont(name: "Georgia", size: 26) ?? UIFont.systemFont(ofSize: 26),
                    .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.27, alpha: 1),
                    .paragraphStyle: style
                ]
                (item.value as NSString).draw(in: CGRect(x: -240, y: -60, width: 480, height: 120), withAttributes: attrs)
            }
            cg.restoreGState()
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

import Foundation
import UIKit
import PencilKit

struct Notebook: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var cover: String = "Rose"
    var created: Date = Date()
    var pages: [NotebookPage] = [NotebookPage()]
}

struct NotebookPage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var paper: String = "Ivory"
    var backgroundFile: String? = nil
    var customPaperHex: UInt32? = nil
    var items: [PageItem] = []
}

struct PageTextStyle: Codable, Equatable {
    // Optional on PageItem, so notebooks saved by older versions still decode.
    var fontName: String = "Georgia"
    var fontSize: Double = 32
    var colorHex: UInt32 = 0x302E36
    var backgroundHex: UInt32? = nil
    var alignment: String = "center"
    var letterSpacing: Double = 0
    var opacity: Double = 1
}

struct PageItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case sticker, text, photo, customSticker }
    var id: UUID = UUID()
    var kind: Kind
    var value: String
    var x: Double = 0.5
    var y: Double = 0.5
    var scale: Double = 1.0
    var angle: Double = 0
    var textStyle: PageTextStyle? = nil
}

@MainActor
final class NotebookLibrary: ObservableObject {
    @Published private(set) var notebooks: [Notebook] = []
    private let manager = FileManager.default
    private let directory: URL
    private var jsonFile: URL { directory.appendingPathComponent("notebooks.json") }

    init() {
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("QuietPages", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        if let data = try? Data(contentsOf: jsonFile),
           let saved = try? JSONDecoder().decode([Notebook].self, from: data) {
            notebooks = saved
        } else {
            notebooks = [Notebook(title: "Мои тихие страницы", cover: "Rose", pages: [NotebookPage(), NotebookPage(paper: "Dots")])]
            save()
        }
    }

    private func save() {
        guard let json = try? JSONEncoder().encode(notebooks) else { return }
        try? json.write(to: jsonFile, options: .atomic)
    }

    func createNotebook(title: String, cover: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        notebooks.insert(Notebook(title: title.isEmpty ? "Новый блокнот" : title, cover: cover), at: 0)
        save()
    }

    func deleteNotebook(_ id: UUID) {
        guard let book = notebooks.first(where: { $0.id == id }) else { return }
        for page in book.pages {
            try? manager.removeItem(at: inkURL(page.id))
            if let background = page.backgroundFile { try? manager.removeItem(at: directory.appendingPathComponent(background)) }
            for item in page.items where item.kind == .photo || item.kind == .customSticker {
                try? manager.removeItem(at: directory.appendingPathComponent(item.value))
            }
        }
        notebooks.removeAll { $0.id == id }
        save()
    }

    func notebook(_ id: UUID) -> Notebook? { notebooks.first { $0.id == id } }

    func setPaper(book: UUID, page: UUID, style: String) {
        edit(book: book, page: page) {
            $0.paper = style
            $0.customPaperHex = nil
        }
    }

    func addPage(book id: UUID, after current: UUID? = nil) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { return }
        let new = NotebookPage()
        if let current, let at = notebooks[index].pages.firstIndex(where: { $0.id == current }) {
            notebooks[index].pages.insert(new, at: at + 1)
        } else {
            notebooks[index].pages.append(new)
        }
        save()
    }

    // Copies images and ink into new files so edits/deletion of either page stay independent.
    func duplicatePage(book id: UUID, page: UUID) -> Int? {
        guard let b = notebooks.firstIndex(where: { $0.id == id }),
              let p = notebooks[b].pages.firstIndex(where: { $0.id == page }) else { return nil }
        var copy = notebooks[b].pages[p]
        copy.id = UUID()
        copy.items = copy.items.map { old in
            var item = old
            item.id = UUID()
            if item.kind == .photo || item.kind == .customSticker {
                item.value = copyLocalFile(named: item.value) ?? item.value
            }
            return item
        }
        if let background = copy.backgroundFile {
            copy.backgroundFile = copyLocalFile(named: background)
        }
        let strokes = drawing(for: page)
        notebooks[b].pages.insert(copy, at: p + 1)
        saveDrawing(strokes, for: copy.id)
        save()
        return p + 1
    }

    func addPDFPages(book id: UUID, backgrounds: [String]) -> Int? {
        guard let b = notebooks.firstIndex(where: { $0.id == id }), !backgrounds.isEmpty else { return nil }
        let start = notebooks[b].pages.count
        notebooks[b].pages.append(contentsOf: backgrounds.map {
            NotebookPage(paper: "Ivory", backgroundFile: $0)
        })
        save()
        return start
    }

    func resizeItem(book: UUID, page: UUID, item: UUID, scale: Double, angle: Double) {
        edit(book: book, page: page) { p in
            if let i = p.items.firstIndex(where: { $0.id == item }) {
                p.items[i].scale = min(max(scale, 0.3), 3.5)
                p.items[i].angle = angle.truncatingRemainder(dividingBy: 360)
            }
        }
    }

    func duplicateItem(book: UUID, page: UUID, item: UUID) {
        edit(book: book, page: page) { p in
            guard let old = p.items.first(where: { $0.id == item }) else { return }
            var copy = old
            copy.id = UUID()
            copy.x = min(0.92, old.x + 0.07)
            copy.y = min(0.93, old.y + 0.06)
            if old.kind == .photo || old.kind == .customSticker {
                copy.value = copyLocalFile(named: old.value) ?? old.value
            }
            p.items.append(copy)
        }
    }

    private func copyLocalFile(named filename: String) -> String? {
        let original = directory.appendingPathComponent(filename)
        let copy = UUID().uuidString + "." + original.pathExtension
        do {
            try manager.copyItem(at: original, to: directory.appendingPathComponent(copy))
            return copy
        } catch { return nil }
    }

    func deletePage(book id: UUID, page: UUID) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }), notebooks[index].pages.count > 1,
              let pageIndex = notebooks[index].pages.firstIndex(where: { $0.id == page }) else { return }
        if let background = notebooks[index].pages[pageIndex].backgroundFile {
            try? manager.removeItem(at: directory.appendingPathComponent(background))
        }
        for item in notebooks[index].pages[pageIndex].items where item.kind == .photo || item.kind == .customSticker {
            try? manager.removeItem(at: directory.appendingPathComponent(item.value))
        }
        notebooks[index].pages.remove(at: pageIndex)
        try? manager.removeItem(at: inkURL(page))
        save()
    }

    func addItem(book: UUID, page: UUID, item: PageItem) {
        edit(book: book, page: page) { $0.items.append(item) }
    }

    func updateText(book: UUID, page: UUID, item: UUID, value: String, style: PageTextStyle) {
        edit(book: book, page: page) { p in
            guard let index = p.items.firstIndex(where: { $0.id == item }),
                  p.items[index].kind == .text else { return }
            p.items[index].value = value
            p.items[index].textStyle = style
        }
    }

    func setPaperColor(book: UUID, page: UUID, hex: UInt32) {
        edit(book: book, page: page) { p in
            p.paper = "Custom"
            p.customPaperHex = hex
        }
    }

    func moveItem(book: UUID, page: UUID, item: UUID, x: Double, y: Double) {
        edit(book: book, page: page) { p in
            if let i = p.items.firstIndex(where: { $0.id == item }) {
                p.items[i].x = min(max(x, 0.08), 0.92)
                p.items[i].y = min(max(y, 0.07), 0.93)
            }
        }
    }

    func deleteItem(book: UUID, page: UUID, item: UUID) {
        edit(book: book, page: page) { p in
            if let element = p.items.first(where: { $0.id == item }),
               element.kind == .photo || element.kind == .customSticker {
                try? manager.removeItem(at: directory.appendingPathComponent(element.value))
            }
            p.items.removeAll { $0.id == item }
        }
    }

    func savePhoto(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        // Keep transparency: imported PNG stickers must not receive a white rectangle.
        let hasAlpha = image.cgImage.map { cg -> Bool in
            switch cg.alphaInfo {
            case .first, .last, .premultipliedFirst, .premultipliedLast: return true
            default: return false
            }
        } ?? false
        guard let imageData = hasAlpha ? image.pngData() : image.jpegData(compressionQuality: 0.88) else { return nil }
        let filename = UUID().uuidString + (hasAlpha ? ".png" : ".jpg")
        do { try imageData.write(to: directory.appendingPathComponent(filename), options: .atomic); return filename }
        catch { return nil }
    }

    func photo(named: String) -> UIImage? { UIImage(contentsOfFile: directory.appendingPathComponent(named).path) }

    private func edit(book: UUID, page: UUID, action: (inout NotebookPage) -> Void) {
        guard let b = notebooks.firstIndex(where: { $0.id == book }),
              let p = notebooks[b].pages.firstIndex(where: { $0.id == page }) else { return }
        action(&notebooks[b].pages[p])
        save()
    }

    private func inkURL(_ id: UUID) -> URL { directory.appendingPathComponent("ink-\(id.uuidString).drawing") }

    func drawing(for page: UUID) -> PKDrawing {
        guard let data = try? Data(contentsOf: inkURL(page)), let drawing = try? PKDrawing(data: data) else { return PKDrawing() }
        return drawing
    }

    func saveDrawing(_ drawing: PKDrawing, for page: UUID) {
        try? drawing.dataRepresentation().write(to: inkURL(page), options: .atomic)
    }
}

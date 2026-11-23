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
    // Связанная текстовая надпись перемещается вместе с исходным стикером.
    var attachedStickerID: UUID? = nil
    // Для записей прямо на маленьких стикерах текстовое поле уже обычного.
    var textWidthFactor: Double? = nil
}

@MainActor
final class NotebookLibrary: ObservableObject {
    @Published private(set) var notebooks: [Notebook] = []
    private let manager = FileManager.default
    private let directory: URL
    private struct PageRevision {
        let page: NotebookPage
        let ink: Data?
    }
    private var undoHistory: [UUID: [PageRevision]] = [:]
    private var redoHistory: [UUID: [PageRevision]] = [:]
    // Published counter makes the SwiftUI undo/redo buttons and PencilKit refresh together.
    @Published private(set) var historyRevision = 0
    @Published private(set) var inkRevision = 0
    private var lastInkEdit: [UUID: Date] = [:]
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

    private func snapshot(book: UUID, page: UUID) -> PageRevision? {
        guard let b = notebooks.firstIndex(where: { $0.id == book }),
              let p = notebooks[b].pages.firstIndex(where: { $0.id == page }) else { return nil }
        return PageRevision(page: notebooks[b].pages[p], ink: try? Data(contentsOf: inkURL(page)))
    }

    private func noteUndo(book: UUID, page: UUID, forInk: Bool = false) {
        guard let snap = snapshot(book: book, page: page) else { return }
        // Debounced ink saves belonging to the same pen gesture become one undo step.
        let now = Date()
        let grouped = forInk && now.timeIntervalSince(lastInkEdit[page] ?? .distantPast) < 0.6
        if !grouped {
            undoHistory[page, default: []].append(snap)
            if undoHistory[page, default: []].count > 70 { undoHistory[page]?.removeFirst() }
        }
        lastInkEdit[page] = now
        redoHistory[page] = []
        historyRevision += 1
    }

    func canUndo(page: UUID) -> Bool { !(undoHistory[page] ?? []).isEmpty }
    func canRedo(page: UUID) -> Bool { !(redoHistory[page] ?? []).isEmpty }

    func undo(book: UUID, page: UUID) {
        guard var stack = undoHistory[page], let previous = stack.popLast(),
              let current = snapshot(book: book, page: page) else { return }
        undoHistory[page] = stack
        redoHistory[page, default: []].append(current)
        restore(book: book, page: page, snapshot: previous)
    }

    func redo(book: UUID, page: UUID) {
        guard var stack = redoHistory[page], let next = stack.popLast(),
              let current = snapshot(book: book, page: page) else { return }
        redoHistory[page] = stack
        undoHistory[page, default: []].append(current)
        restore(book: book, page: page, snapshot: next)
    }

    private func restore(book: UUID, page: UUID, snapshot: PageRevision) {
        guard let b = notebooks.firstIndex(where: { $0.id == book }),
              let p = notebooks[b].pages.firstIndex(where: { $0.id == page }) else { return }
        notebooks[b].pages[p] = snapshot.page
        if let ink = snapshot.ink { try? ink.write(to: inkURL(page), options: .atomic) }
        else { try? manager.removeItem(at: inkURL(page)) }
        save()
        lastInkEdit.removeValue(forKey: page)
        historyRevision += 1
        inkRevision += 1
    }

    func createNotebook(title: String, cover: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        notebooks.insert(Notebook(title: title.isEmpty ? "Новый блокнот" : title, cover: cover), at: 0)
        save()
    }

    func setCover(book id: UUID, cover: String) {
        guard let idx = notebooks.firstIndex(where: { $0.id == id }), CoverCatalog.find(cover) != nil else { return }
        notebooks[idx].cover = cover
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
        let idMap = Dictionary(uniqueKeysWithValues: copy.items.map { ($0.id, UUID()) })
        copy.items = copy.items.map { old in
            var item = old
            item.id = idMap[old.id] ?? UUID()
            if let linked = old.attachedStickerID { item.attachedStickerID = idMap[linked] }
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
        saveDrawing(strokes, for: copy.id, recordHistory: false)
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
                let original = p.items[i]
                let newScale = min(max(scale, 0.3), 3.5)
                let delta = (angle - original.angle) * .pi / 180.0
                p.items[i].scale = newScale
                p.items[i].angle = angle.truncatingRemainder(dividingBy: 360)
                // Keep typed text fixed to its sticker when the sticker rotates or scales.
                let scaleFactor = newScale / max(original.scale, 0.001)
                let aspect = 0.735  // page width / page height
                for j in p.items.indices where p.items[j].attachedStickerID == item {
                    let dx = (p.items[j].x - original.x) * aspect * scaleFactor
                    let dy = (p.items[j].y - original.y) * scaleFactor
                    p.items[j].x = min(max(original.x + (dx * cos(delta) - dy * sin(delta)) / aspect, 0.04), 0.96)
                    p.items[j].y = min(max(original.y + dx * sin(delta) + dy * cos(delta), 0.04), 0.96)
                    p.items[j].angle = (p.items[j].angle + angle - original.angle).truncatingRemainder(dividingBy: 360)
                    p.items[j].scale = newScale
                }
            }
        }
    }

    func rotateItem(book: UUID, page: UUID, item: UUID, degrees: Double) {
        guard let notebook = notebook(book),
              let pg = notebook.pages.first(where: { $0.id == page }),
              let sticker = pg.items.first(where: { $0.id == item }) else { return }
        resizeItem(book: book, page: page, item: item, scale: sticker.scale, angle: sticker.angle + degrees)
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
            // Если на наклейке есть набранный текст, дублируем комплект вместе.
            if old.kind == .sticker || old.kind == .customSticker || old.kind == .photo {
                for label in p.items.filter({ $0.attachedStickerID == old.id }) {
                    var duplicateLabel = label
                    duplicateLabel.id = UUID()
                    duplicateLabel.attachedStickerID = copy.id
                    duplicateLabel.x = min(0.97, label.x + 0.07)
                    duplicateLabel.y = min(0.97, label.y + 0.06)
                    p.items.append(duplicateLabel)
                }
            }
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

    func bringForward(book: UUID, page: UUID, item: UUID) {
        edit(book: book, page: page) { p in
            guard let index = p.items.firstIndex(where: { $0.id == item }) else { return }
            let element = p.items.remove(at: index)
            p.items.append(element)
        }
    }
    func sendBackward(book: UUID, page: UUID, item: UUID) {
        edit(book: book, page: page) { p in
            guard let index = p.items.firstIndex(where: { $0.id == item }) else { return }
            let element = p.items.remove(at: index)
            p.items.insert(element, at: 0)
        }
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
                let dx = x - p.items[i].x
                let dy = y - p.items[i].y
                p.items[i].x = min(max(x, 0.08), 0.92)
                p.items[i].y = min(max(y, 0.07), 0.93)
                let stickerID = p.items[i].id
                for j in p.items.indices where p.items[j].attachedStickerID == stickerID {
                    p.items[j].x = min(max(p.items[j].x + dx, 0.03), 0.97)
                    p.items[j].y = min(max(p.items[j].y + dy, 0.03), 0.97)
                }
            }
        }
    }

    func deleteItem(book: UUID, page: UUID, item: UUID) {
        edit(book: book, page: page) { p in
            // Retain local picture bytes while this page is open: Undo may need them.
            p.items.removeAll { $0.id == item || $0.attachedStickerID == item }
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
        noteUndo(book: book, page: page)
        action(&notebooks[b].pages[p])
        save()
    }

    private func inkURL(_ id: UUID) -> URL { directory.appendingPathComponent("ink-\(id.uuidString).drawing") }

    func drawing(for page: UUID) -> PKDrawing {
        guard let data = try? Data(contentsOf: inkURL(page)), let drawing = try? PKDrawing(data: data) else { return PKDrawing() }
        return drawing
    }

    func saveDrawing(_ drawing: PKDrawing, for page: UUID, recordHistory: Bool = true) {
        let bytes = drawing.dataRepresentation()
        if let old = try? Data(contentsOf: inkURL(page)), old == bytes { return }
        if recordHistory, let book = notebooks.first(where: { $0.pages.contains(where: { $0.id == page }) }) {
            noteUndo(book: book.id, page: page, forInk: true)
        }
        try? bytes.write(to: inkURL(page), options: .atomic)
    }
}

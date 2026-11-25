import Foundation
import Combine
import UIKit
import PencilKit
import ImageIO
import UniformTypeIdentifiers

struct Notebook: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var cover: String = "Rose"
    var created: Date = Date()
    var pages: [NotebookPage] = [NotebookPage()]
    var mood: String? = nil
    // Optional for backwards compatibility with notebooks saved before STUDIO 5.
    var favorite: Bool? = nil
    var folder: String? = nil
}

struct NotebookPage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var paper: String = "Ivory"
    var backgroundFile: String? = nil
    var customPaperHex: UInt32? = nil
    var decorationOpacity: Double? = nil
    var items: [PageItem] = []
    var inkCanvasWidth: Double? = nil
    var inkCanvasHeight: Double? = nil
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
    enum Kind: String, Codable { case sticker, text, photo, customSticker, shape }
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
    var opacity: Double = 1.0
    var locked: Bool = false
    var flipped: Bool = false
    var groupID: UUID? = nil
    var hidden: Bool = false

    // Earlier saved notebooks did not have these settings; decode safely.
    private enum CodingKeys: String, CodingKey {
        case id, kind, value, x, y, scale, angle, textStyle, attachedStickerID, textWidthFactor, opacity, locked, flipped, groupID, hidden
    }
    init(id: UUID = UUID(), kind: Kind, value: String, x: Double = 0.5, y: Double = 0.5,
         scale: Double = 1.0, angle: Double = 0, textStyle: PageTextStyle? = nil,
         attachedStickerID: UUID? = nil, textWidthFactor: Double? = nil,
         opacity: Double = 1.0, locked: Bool = false, flipped: Bool = false, groupID: UUID? = nil, hidden: Bool = false) {
        self.id = id; self.kind = kind; self.value = value; self.x = x; self.y = y
        self.scale = scale; self.angle = angle; self.textStyle = textStyle
        self.attachedStickerID = attachedStickerID; self.textWidthFactor = textWidthFactor
        self.opacity = opacity; self.locked = locked; self.flipped = flipped; self.groupID = groupID; self.hidden = hidden
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decode(Kind.self, forKey: .kind)
        value = try c.decode(String.self, forKey: .value)
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 0.5
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 0.5
        scale = try c.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        angle = try c.decodeIfPresent(Double.self, forKey: .angle) ?? 0
        textStyle = try c.decodeIfPresent(PageTextStyle.self, forKey: .textStyle)
        attachedStickerID = try c.decodeIfPresent(UUID.self, forKey: .attachedStickerID)
        textWidthFactor = try c.decodeIfPresent(Double.self, forKey: .textWidthFactor)
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        flipped = try c.decodeIfPresent(Bool.self, forKey: .flipped) ?? false
        groupID = try c.decodeIfPresent(UUID.self, forKey: .groupID)
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
    }
}

struct UserComposition: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var items: [PageItem]
}

// Portable offline backup: notebook metadata, attached pictures, and PencilKit drawings.
struct QuietPagesBackup: Codable {
    let formatVersion: Int
    let notebook: Notebook
    let files: [String: Data]
}

@MainActor
final class NotebookLibrary: ObservableObject {
    @Published private(set) var notebooks: [Notebook] = []
    @Published private(set) var userCompositions: [UserComposition] = []
    @Published var storageError: String?
    private var savingBlocked = false
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
    private var compositionFile: URL { directory.appendingPathComponent("compositions.json") }

    init(directory overrideDirectory: URL? = nil) {
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = overrideDirectory ?? base.appendingPathComponent("QuietPages", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        if manager.fileExists(atPath: jsonFile.path) {
            do {
                let data = try Data(contentsOf: jsonFile)
                notebooks = try JSONDecoder().decode([Notebook].self, from: data)
                let checkpoint = directory.appendingPathComponent("notebooks-before-studio6.json")
                if !manager.fileExists(atPath: checkpoint.path) { try manager.copyItem(at: jsonFile, to: checkpoint) }
            } catch {
                // Never overwrite an unreadable library with a starter notebook.
                savingBlocked = true
                storageError = "Не удалось прочитать библиотеку. Исходные файлы сохранены без изменений. Восстановите данные из резервной копии или обратитесь за помощью. \(error.localizedDescription)"
            }
        } else {
            notebooks = [Notebook(title: "Мои тихие страницы", cover: "Painted_Spring_01",
                                  pages: [NotebookPage(paper: "Studio6_Spring_blank")])]
            save()
        }
        if let data = try? Data(contentsOf: compositionFile),
           let saved = try? JSONDecoder().decode([UserComposition].self, from: data) {
            userCompositions = saved
        }
    }

    private func save() {
        guard !savingBlocked else { return }
        do {
            let json = try JSONEncoder().encode(notebooks)
            if let previous = try? Data(contentsOf: jsonFile),
               (try? JSONDecoder().decode([Notebook].self, from: previous)) != nil {
                try previous.write(to: directory.appendingPathComponent("notebooks-previous.json"), options: .atomic)
            }
            try json.write(to: jsonFile, options: .atomic)
        } catch { storageError = "Не удалось сохранить блокноты: \(error.localizedDescription)" }
    }

    func setInkCanvasSize(_ size: CGSize, page: UUID) {
        guard !savingBlocked,
              let b = notebooks.firstIndex(where: { $0.pages.contains { $0.id == page } }),
              let p = notebooks[b].pages.firstIndex(where: { $0.id == page }),
              notebooks[b].pages[p].inkCanvasWidth == nil else { return }
        notebooks[b].pages[p].inkCanvasWidth = Double(size.width)
        notebooks[b].pages[p].inkCanvasHeight = Double(size.height)
        save()
    }

    func inkCanvasSize(page: UUID) -> CGSize? {
        guard let p = notebooks.flatMap(\.pages).first(where: { $0.id == page }),
              let w = p.inkCanvasWidth, let h = p.inkCanvasHeight, w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
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
            if undoHistory[page, default: []].count > 30 { undoHistory[page]?.removeFirst() }
            while undoHistory.values.flatMap({ $0 }).reduce(0, { $0 + ($1.ink?.count ?? 0) }) > 24 * 1024 * 1024 {
                guard let key = undoHistory.keys.sorted(by: { $0.uuidString < $1.uuidString })
                    .first(where: { !(undoHistory[$0] ?? []).isEmpty }) else { break }
                undoHistory[key]?.removeFirst()
            }
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

    func createNotebook(title: String, cover: String, paper: String = "Ivory", mood: String? = nil) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        notebooks.insert(Notebook(title: title.isEmpty ? "Новый блокнот" : title, cover: cover,
                                  pages: [NotebookPage(paper: paper)], mood: mood), at: 0)
        save()
    }

    func setCover(book id: UUID, cover: String) {
        guard let idx = notebooks.firstIndex(where: { $0.id == id }), CoverCatalog.find(cover) != nil else { return }
        notebooks[idx].cover = cover
        save()
    }

    func saveComposition(name: String, items: [PageItem]) {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !items.isEmpty else { return }
        let preserved = items.map { original -> PageItem in
            var item = original
            if item.kind == .photo || item.kind == .customSticker {
                item.value = copyLocalFile(named: item.value) ?? item.value
            }
            return item
        }
        userCompositions.insert(UserComposition(title: title, items: preserved), at: 0)
        if let data = try? JSONEncoder().encode(userCompositions) {
            try? data.write(to: compositionFile, options: .atomic)
        }
    }

    func addSavedComposition(_ id: UUID, book: UUID, page: UUID) {
        guard let composition = userCompositions.first(where: { $0.id == id }),
              !composition.items.isEmpty else { return }
        let ids = Dictionary(uniqueKeysWithValues: composition.items.map { ($0.id, UUID()) })
        let group = UUID()
        let xMin = composition.items.map(\.x).min() ?? 0.25
        let xMax = composition.items.map(\.x).max() ?? 0.75
        let yMin = composition.items.map(\.y).min() ?? 0.25
        let yMax = composition.items.map(\.y).max() ?? 0.75
        let centerX = (xMin + xMax) / 2, centerY = (yMin + yMax) / 2
        let pasted = composition.items.map { old -> PageItem in
            var copy = old
            copy.id = ids[old.id] ?? UUID()
            copy.groupID = group
            copy.x = min(max(0.5 + old.x - centerX, 0.04), 0.96)
            copy.y = min(max(0.5 + old.y - centerY, 0.04), 0.96)
            copy.locked = false
            if copy.kind == .photo || copy.kind == .customSticker {
                copy.value = copyLocalFile(named: old.value) ?? old.value
            }
            if let linked = old.attachedStickerID { copy.attachedStickerID = ids[linked] }
            return copy
        }
        addItems(book: book, page: page, items: pasted)
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { return }
        notebooks[index].favorite = !(notebooks[index].favorite ?? false)
        save()
    }

    func setNotebookFolder(_ id: UUID, folder: String?) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { return }
        notebooks[index].folder = folder
        save()
    }

    func renameNotebook(_ id: UUID, title: String) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        notebooks[index].title = title
        save()
    }

    func duplicateNotebook(_ id: UUID) {
        guard let original = notebook(id) else { return }
        var copy = original
        copy.id = UUID()
        copy.title = original.title + " · копия"
        copy.favorite = false
        copy.created = Date()
        for i in copy.pages.indices {
            let originalPage = copy.pages[i].id
            copy.pages[i].id = UUID()
            if let data = try? Data(contentsOf: inkURL(originalPage)) {
                try? data.write(to: inkURL(copy.pages[i].id), options: .atomic)
            }
            if let bg = copy.pages[i].backgroundFile {
                copy.pages[i].backgroundFile = copyLocalFile(named: bg)
            }
            let idMap = Dictionary(uniqueKeysWithValues: copy.pages[i].items.map { ($0.id, UUID()) })
            for j in copy.pages[i].items.indices {
                copy.pages[i].items[j].id = idMap[copy.pages[i].items[j].id] ?? UUID()
                if let linked = copy.pages[i].items[j].attachedStickerID {
                    copy.pages[i].items[j].attachedStickerID = idMap[linked]
                }
                if copy.pages[i].items[j].kind == .photo || copy.pages[i].items[j].kind == .customSticker {
                    copy.pages[i].items[j].value = copyLocalFile(named: copy.pages[i].items[j].value) ?? ""
                }
            }
        }
        notebooks.insert(copy, at: 0)
        save()
    }

    func updateItemImage(book: UUID, page: UUID, item: UUID, filename: String) {
        edit(book: book, page: page) { p in
            if let index = p.items.firstIndex(where: { $0.id == item }) {
                p.items[index].value = filename
            }
        }
    }

    func deleteNotebook(_ id: UUID) {
        guard let book = notebooks.first(where: { $0.id == id }) else { return }
        for page in book.pages {
            try? manager.removeItem(at: inkURL(page.id))
            if let background = page.backgroundFile { try? manager.removeItem(at: directory.appendingPathComponent(background)) }
            for item in page.items where item.kind == .photo {
                try? manager.removeItem(at: directory.appendingPathComponent(item.value))
            }
        }
        notebooks.removeAll { $0.id == id }
        save()
    }

    func notebook(_ id: UUID) -> Notebook? { notebooks.first { $0.id == id } }

    func exportNotebookBackup(_ bookID: UUID) -> URL? {
        guard let book = notebook(bookID) else { return nil }
        var files: [String: Data] = [:]
        for page in book.pages {
            let inkName = "ink-\(page.id.uuidString).drawing"
            if let ink = try? Data(contentsOf: inkURL(page.id)) { files[inkName] = ink }
            if let background = page.backgroundFile,
               let bytes = try? Data(contentsOf: directory.appendingPathComponent(background)) {
                files[background] = bytes
            }
            for item in page.items where item.kind == .photo || item.kind == .customSticker {
                if let bytes = try? Data(contentsOf: directory.appendingPathComponent(item.value)) {
                    files[item.value] = bytes
                }
            }
        }
        let backup = QuietPagesBackup(formatVersion: 1, notebook: book, files: files)
        guard let encoded = try? JSONEncoder().encode(backup) else { return nil }
        let dest = manager.temporaryDirectory.appendingPathComponent("QuietPages-\(book.id.uuidString.prefix(8)).quietpages")
        do { try encoded.write(to: dest, options: .atomic); return dest }
        catch { return nil }
    }

    func importNotebookBackup(from url: URL) throws {
        func failure(_ message: String) -> NSError {
            NSError(domain: "QuietPages.Backup", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        guard !savingBlocked else { throw failure("Сначала восстановите исходную библиотеку: запись заблокирована, чтобы сохранить данные.") }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 150_000_000 else { throw failure("Резервная копия больше 150 МБ. На этом iPad импорт такого файла пока не поддерживается.") }
        let backup = try JSONDecoder().decode(QuietPagesBackup.self, from: Data(contentsOf: url))
        guard backup.formatVersion == 1, !backup.notebook.pages.isEmpty,
              backup.notebook.pages.count <= 1000,
              Set(backup.notebook.pages.map(\.id)).count == backup.notebook.pages.count else {
            throw failure("Неподдерживаемая или повреждённая резервная копия")
        }
        let staging = directory.appendingPathComponent("import-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        var remap: [String: String] = [:]
        var staged: [String] = []
        func importPicture(_ name: String?) throws -> String? {
            guard let name else { return nil }
            if let old = remap[name] { return old }
            guard let bytes = backup.files[name], bytes.count < 25_000_000,
                  UIImage(data: bytes) != nil else { throw failure("В копии отсутствует или повреждено изображение: \(name)") }
            let ext = (name as NSString).pathExtension.lowercased()
            guard ["png", "jpg", "jpeg"].contains(ext) else { throw failure("Неподдерживаемое изображение") }
            let newName = UUID().uuidString + "." + ext
            try bytes.write(to: staging.appendingPathComponent(newName), options: .atomic)
            staged.append(newName); remap[name] = newName
            return newName
        }
        var copy = backup.notebook
        copy.id = UUID()
        for index in copy.pages.indices {
            let old = copy.pages[index].id
            copy.pages[index].id = UUID()
            if let strokes = backup.files["ink-\(old.uuidString).drawing"] {
                _ = try PKDrawing(data: strokes)
                let name = "ink-\(copy.pages[index].id.uuidString).drawing"
                try strokes.write(to: staging.appendingPathComponent(name), options: .atomic)
                staged.append(name)
            }
            copy.pages[index].backgroundFile = try importPicture(copy.pages[index].backgroundFile)
            guard Set(copy.pages[index].items.map(\.id)).count == copy.pages[index].items.count else {
                throw failure("В копии повторяются идентификаторы объектов")
            }
            for j in copy.pages[index].items.indices {
                if copy.pages[index].items[j].kind == .photo || copy.pages[index].items[j].kind == .customSticker {
                    copy.pages[index].items[j].value = try importPicture(copy.pages[index].items[j].value) ?? ""
                }
            }
        }
        var moved: [String] = []
        do {
            for name in staged {
                try manager.moveItem(at: staging.appendingPathComponent(name), to: directory.appendingPathComponent(name))
                moved.append(name)
            }
            let updated = [copy] + notebooks
            let json = try JSONEncoder().encode(updated)
            try json.write(to: jsonFile, options: .atomic)
            notebooks = updated
        } catch {
            for name in moved { try? manager.removeItem(at: directory.appendingPathComponent(name)) }
            throw error
        }
    }

    func setPaper(book: UUID, page: UUID, style: String) {
        edit(book: book, page: page) {
            $0.paper = style
            $0.customPaperHex = nil
        }
    }

    func setDecorationOpacity(book: UUID, page: UUID, opacity: Double) {
        edit(book: book, page: page) {
            $0.decorationOpacity = min(max(opacity, 0.25), 1)
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

    func shiftPage(book id: UUID, page: UUID, delta: Int) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }),
              let from = notebooks[index].pages.firstIndex(where: { $0.id == page }) else { return }
        let destination = from + delta
        guard notebooks[index].pages.indices.contains(destination) else { return }
        notebooks[index].pages.swapAt(from, destination)
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
            copy.groupID = nil
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
        for item in notebooks[index].pages[pageIndex].items where item.kind == .photo {
            try? manager.removeItem(at: directory.appendingPathComponent(item.value))
        }
        notebooks[index].pages.remove(at: pageIndex)
        try? manager.removeItem(at: inkURL(page))
        save()
    }

    func addItems(book: UUID, page: UUID, items: [PageItem]) {
        edit(book: book, page: page) { $0.items.append(contentsOf: items) }
    }

    func ungroupItem(book: UUID, page: UUID, item: UUID) {
        edit(book: book, page: page) { p in
            guard let groupID = p.items.first(where: { $0.id == item })?.groupID else { return }
            for i in p.items.indices where p.items[i].groupID == groupID { p.items[i].groupID = nil }
        }
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

    func toggleItemLock(book: UUID, page: UUID, item: UUID) {
        edit(book: book, page: page) { p in
            guard let i = p.items.firstIndex(where: { $0.id == item }) else { return }
            p.items[i].locked.toggle()
        }
    }

    func toggleItemVisibility(book: UUID, page: UUID, item: UUID) {
        edit(book: book, page: page) { p in
            guard let i = p.items.firstIndex(where: { $0.id == item }) else { return }
            p.items[i].hidden.toggle()
        }
    }

    func toggleItemFlip(book: UUID, page: UUID, item: UUID) {
        edit(book: book, page: page) { p in
            guard let i = p.items.firstIndex(where: { $0.id == item }) else { return }
            p.items[i].flipped.toggle()
        }
    }

    func setItemOpacity(book: UUID, page: UUID, item: UUID, opacity: Double) {
        edit(book: book, page: page) { p in
            guard let i = p.items.firstIndex(where: { $0.id == item }) else { return }
            p.items[i].opacity = min(max(opacity, 0.1), 1)
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
                if let groupID = p.items[i].groupID {
                    for j in p.items.indices where j != i && p.items[j].groupID == groupID {
                        p.items[j].x = min(max(p.items[j].x + dx, 0.03), 0.97)
                        p.items[j].y = min(max(p.items[j].y + dy, 0.03), 0.97)
                    }
                }
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
        // Preserve original bytes and alpha; validate with a small decode, not a full bitmap.
        guard data.count <= 25 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData,
                  [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source),
              let ext = UTType(type as String)?.preferredFilenameExtension,
              CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 64,
                  kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) != nil else {
            storageError = "Не удалось открыть изображение. Проверьте файл; максимальный размер — 25 МБ."
            return nil
        }
        let filename = UUID().uuidString + "." + ext
        do {
            try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch {
            storageError = "Не удалось сохранить изображение: \(error.localizedDescription)"
            return nil
        }
    }

    func photo(named: String, pixels: Int = 1536) -> UIImage? {
        guard !named.contains("/"), !named.contains("..") else { return nil }
        return StudioImageStore.local(directory.appendingPathComponent(named), pixels: pixels)
    }

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
        guard !savingBlocked else { return }
        let bytes = drawing.dataRepresentation()
        if let old = try? Data(contentsOf: inkURL(page)), old == bytes { return }
        if recordHistory, let book = notebooks.first(where: { $0.pages.contains(where: { $0.id == page }) }) {
            noteUndo(book: book.id, page: page, forInk: true)
        }
        do { try bytes.write(to: inkURL(page), options: .atomic) }
        catch { storageError = "Не удалось сохранить рисунок: \(error.localizedDescription)" }
    }
}

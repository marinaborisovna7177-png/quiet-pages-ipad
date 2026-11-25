import XCTest
import PencilKit
@testable import QuietPages

@MainActor final class Studio6Tests: XCTestCase {
    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    func testLegacyItemUsesSafeDefaults() throws {
        let old = Data(#"{"kind":"sticker","value":"Mega_0001","x":0.3,"y":0.7}"#.utf8)
        let item = try JSONDecoder().decode(PageItem.self, from: old)
        XCTAssertEqual(item.scale, 1)
        XCTAssertFalse(item.locked)
        XCTAssertFalse(item.hidden)
        XCTAssertEqual(item.value, "Mega_0001")
    }
    func testCorruptLibraryIsNeverReplaced() throws {
        let dir = try temporaryFolder()
        let original = Data("{broken-but-valuable".utf8)
        let path = dir.appendingPathComponent("notebooks.json")
        try original.write(to: path)
        let store = NotebookLibrary(directory: dir)
        XCTAssertNotNil(store.storageError)
        store.createNotebook(title: "test", cover: "Rose")
        XCTAssertEqual(try Data(contentsOf: path), original)
    }
    func testMigrationAndObjectRoundTrip() throws {
        let dir = try temporaryFolder()
        let store = NotebookLibrary(directory: dir)
        let book = try XCTUnwrap(store.notebooks.first)
        let page = try XCTUnwrap(book.pages.first)
        let item = PageItem(kind: .sticker, value: "Mega_0001", x: 0.2, y: 0.6,
                            scale: 1.4, angle: 33, opacity: 0.5, locked: true, flipped: true)
        store.addItem(book: book.id, page: page.id, item: item)
        store.setInkCanvasSize(CGSize(width: 420,height: 571.43), page: page.id)
        let reopened = NotebookLibrary(directory: dir)
        XCTAssertEqual(reopened.notebooks.first?.pages.first?.items.first, item)
        XCTAssertEqual(reopened.inkCanvasSize(page: page.id)?.width, 420)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("notebooks-before-studio6.json").path))
    }
    func testBackupRestoresEditableObjects() throws {
        let first = NotebookLibrary(directory: try temporaryFolder())
        let book = try XCTUnwrap(first.notebooks.first)
        let page = try XCTUnwrap(book.pages.first)
        first.addItem(book: book.id, page: page.id, item: PageItem(kind: .text, value: "Мои заметки"))
        let backup = try XCTUnwrap(first.exportNotebookBackup(book.id))
        defer { try? FileManager.default.removeItem(at: backup) }
        let other = NotebookLibrary(directory: try temporaryFolder())
        try other.importNotebookBackup(from: backup)
        XCTAssertEqual(other.notebooks.first?.pages.first?.items.first?.value, "Мои заметки")
        XCTAssertNotEqual(other.notebooks.first?.id, book.id)
        XCTAssertNotEqual(other.notebooks.first?.pages.first?.id, page.id)
    }
    func testPaperCatalogStableAndComplete() {
        XCTAssertEqual(Set(PaperCatalog.all.map(\.id)).count, PaperCatalog.all.count)
        XCTAssertEqual(Studio6Catalog.themes.count,16)
        XCTAssertEqual(Studio6Catalog.papers.count,304)
        XCTAssertNotNil(PaperCatalog.find("Ivory"))
        XCTAssertNotNil(PaperCatalog.find("Paper_Winter_01"))
    }
    func testAllStickerThumbnailsExist() {
        for item in StickerCatalog.all where StudioCompositionCatalog.components(for: item.id) == nil {
            XCTAssertNotNil(StudioImageStore.url(item.id,thumbnail:true), item.id)
        }
    }
    func testUndoRedoPreservesItem() throws {
        let store=NotebookLibrary(directory:try temporaryFolder())
        let book=try XCTUnwrap(store.notebooks.first), page=try XCTUnwrap(book.pages.first)
        let item=PageItem(kind:.sticker,value:"Mega_2000")
        store.addItem(book:book.id,page:page.id,item:item)
        store.undo(book:book.id,page:page.id)
        XCTAssertTrue(store.notebooks.first!.pages.first!.items.isEmpty)
        store.redo(book:book.id,page:page.id)
        XCTAssertEqual(store.notebooks.first!.pages.first!.items,[item])
    }
    func testToolIsNotReassignedWhileWriting() throws {
        let store = NotebookLibrary(directory: try temporaryFolder())
        let page = try XCTUnwrap(store.notebooks.first?.pages.first)
        let view = PenCanvas(pageID: page.id, library: store, ink: .pen,
            color: .black, strokeWidth: 3, isEnabled: true, revision: 0)
        let coordinator = view.makeCoordinator()
        let canvas = PKCanvasView()
        coordinator.canvas = canvas
        coordinator.load(into: canvas)
        coordinator.applyConfiguration()
        coordinator.canvasViewDidBeginUsingTool(canvas)
        coordinator.parent = PenCanvas(pageID: page.id, library: store, ink: .marker,
            color: .red, strokeWidth: 8, isEnabled: true, revision: 0)
        coordinator.applyConfiguration()
        XCTAssertEqual((canvas.tool as? PKInkingTool)?.inkType, .pen)
        coordinator.canvasViewDrawingDidChange(canvas)
        XCTAssertNil(coordinator.pendingSave, "No disk debounce while the stylus is down")
        coordinator.canvasViewDidEndUsingTool(canvas)
        XCTAssertEqual((canvas.tool as? PKInkingTool)?.inkType, .marker)
    }
    func testInputPolicyAndConstantWidthAreExplicit() throws {
        let store = NotebookLibrary(directory: try temporaryFolder())
        let page = try XCTUnwrap(store.notebooks.first?.pages.first)
        let view = PenCanvas(pageID: page.id, library: store, ink: .fountainPen,
            color: .black, strokeWidth: 3, isEnabled: true, revision: 0,
            pencilOnly: false, constantWidth: true)
        let coordinator = view.makeCoordinator()
        let canvas = PKCanvasView()
        coordinator.canvas = canvas
        coordinator.applyConfiguration()
        XCTAssertEqual(canvas.drawingPolicy, .anyInput)
        XCTAssertEqual((canvas.tool as? PKInkingTool)?.inkType, .monoline)
        coordinator.parent.pencilOnly = true
        coordinator.applyConfiguration()
        XCTAssertEqual(canvas.drawingPolicy, .pencilOnly)
    }
    func testBrokenStickerFailsSafely() throws {
        let url = try temporaryFolder().appendingPathComponent("bad.png")
        try Data("broken image".utf8).write(to: url)
        XCTAssertNil(StudioImageStore.decode(url, pixels: 192))
        XCTAssertNil(StudioImageStore.url("../outside", thumbnail: true))
    }

    func testPhotoImportPreservesOriginalPNG() throws {
        let dir = try temporaryFolder()
        let store = NotebookLibrary(directory: dir)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 4, y: 4, width: 20, height: 20))
        }
        let bytes = try XCTUnwrap(image.pngData())
        let name = try XCTUnwrap(store.savePhoto(bytes))
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(name)), bytes)
        XCTAssertNotNil(store.photo(named: name, pixels: 192))
        XCTAssertNil(store.photo(named: "../outside.png"))
    }

}

import SwiftUI
import PencilKit
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

private enum EditorPanel: String, Identifiable {
    case stickers, paper, pages, inkColors
    var id: String { rawValue }
}

enum InkChoice: String, CaseIterable, Identifiable {
    // PencilKit на iPadOS 17 поддерживает все эти настоящие виды чернил.
    case pen = "Ручка"
    case fountainPen = "Перо"
    case monoline = "Линер"
    case pencil = "Карандаш"
    case marker = "Фломастер"
    case watercolor = "Акварель"
    case crayon = "Мелок"
    case eraser = "Ластик"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .fountainPen: "pencil.tip.crop.circle"
        case .monoline: "line.diagonal"
        case .pencil: "pencil"
        case .marker: "highlighter"
        case .watercolor: "paintbrush.pointed"
        case .crayon: "paintbrush"
        case .eraser: "eraser"
        }
    }
}

struct NotebookEditor: View {
    let bookID: UUID
    @EnvironmentObject private var library: NotebookLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var ink: InkChoice = .pen
    @State private var penColor: Color = AppPalette.midnight
    @State private var strokeWidth: Double = 3
    @State private var editingTextItem: PageItem?
    // При письме рисуем ПОВЕРХ наклеек; при расстановке наклейки получают жесты.
    @State private var arrangingDecor = false
    @State private var textOnSticker: PageItem?
    @State private var addingText = false
    @State private var pickedSticker: PhotosPickerItem?
    @State private var showingPDFImporter = false
    @State private var importError: String?
    @State private var panel: EditorPanel?
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var exportItem: SharedDocument?
    @State private var showDeletePage = false
    @State private var isExporting = false

    var body: some View {
        Group {
            if let book = library.notebook(bookID), !book.pages.isEmpty {
                editor(book)
            } else {
                ContentUnavailableView("Блокнот не найден", systemImage: "book.closed")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $panel) { panel in
            if let book = library.notebook(bookID), let page = safePage(book) {
                switch panel {
                case .stickers: StickerPalette { stickerName in
                    arrangingDecor = true
                    library.addItem(book: bookID, page: page.id,
                                    item: PageItem(kind: .sticker, value: stickerName, x: 0.5, y: 0.5))
                    self.panel = nil
                }
                case .paper:
                    PaperPalette(current: page.paper, customHex: page.customPaperHex) { paper in
                        library.setPaper(book: bookID, page: page.id, style: paper)
                        self.panel = nil
                    } chooseCustom: { hex in
                        library.setPaperColor(book: bookID, page: page.id, hex: hex)
                        self.panel = nil
                    }
                case .inkColors:
                    InkColorPalette(color: $penColor)
                case .pages:
                    PageNavigator(book: book, currentPage: $currentPage, library: library) { pageID in
                        if let newIndex = library.duplicatePage(book: bookID, page: pageID) {
                            currentPage = newIndex
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $addingText) {
            if let book = library.notebook(bookID), let page = safePage(book) {
                TextStudioSheet(existing: nil,
                                initialStyle: textOnSticker == nil ? nil : PageTextStyle(fontName: "Georgia", fontSize: 19)) { value, style in
                    var item = PageItem(kind: .text, value: value,
                                        x: textOnSticker?.x ?? 0.5,
                                        y: (textOnSticker?.y ?? 0.28) + (textOnSticker == nil ? 0 : 0.025))
                    item.textStyle = style
                    if let sticker = textOnSticker {
                        item.attachedStickerID = sticker.id
                        let note = sticker.value.hasPrefix("NoteCard") || sticker.value.hasPrefix("Label") || sticker.value == "PinkPaper"
                        item.textWidthFactor = note ? 0.31 : 0.19
                    }
                    library.addItem(book: bookID, page: page.id, item: item)
                    textOnSticker = nil
                    arrangingDecor = true
                }
            }
        }
        .sheet(item: $editingTextItem) { item in
            if let book = library.notebook(bookID), let page = safePage(book) {
                TextStudioSheet(existing: item) { value, style in
                    library.updateText(book: bookID, page: page.id, item: item.id, value: value, style: style)
                }
            }
        }
        .sheet(item: $exportItem) { item in ShareSheet(url: item.url) }
        .fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let document = PDFDocument(url: url), document.pageCount > 0 else {
                    importError = "PDF не удалось открыть."
                    return
                }
                var backgrounds: [String] = []
                for index in 0..<min(document.pageCount, 30) {
                    guard let pdfPage = document.page(at: index) else { continue }
                    let preview = pdfPage.thumbnail(of: CGSize(width: 1000, height: 1400), for: .mediaBox)
                    if let data = preview.jpegData(compressionQuality: 0.85),
                       let filename = library.savePhoto(data) { backgrounds.append(filename) }
                }
                if let firstPage = library.addPDFPages(book: bookID, backgrounds: backgrounds) {
                    currentPage = firstPage
                } else { importError = "Не удалось добавить страницы PDF." }
            } catch { importError = "Не получилось прочитать файл PDF." }
        }
        .alert("Не удалось импортировать", isPresented: Binding(
            get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("Понятно", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
        .alert("Удалить страницу?", isPresented: $showDeletePage) {
            Button("Удалить", role: .destructive) {
                if let book = library.notebook(bookID), let page = safePage(book), book.pages.count > 1 {
                    library.deletePage(book: bookID, page: page.id)
                    currentPage = min(currentPage, book.pages.count - 2)
                }
            }
            Button("Отмена", role: .cancel) { }
        } message: { Text("Рисунки и украшения на этой странице будут удалены.") }
        .onChange(of: pickedSticker) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        if let path = library.savePhoto(data),
                           let book = library.notebook(bookID), let page = safePage(book) {
                            arrangingDecor = true
                            library.addItem(book: bookID, page: page.id,
                                            item: PageItem(kind: .customSticker, value: path))
                        }
                        pickedSticker = nil
                    }
                }
            }
        }
        .onChange(of: pickedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        if let path = library.savePhoto(data),
                           let book = library.notebook(bookID), let page = safePage(book) {
                            arrangingDecor = true
                            library.addItem(book: bookID, page: page.id, item: PageItem(kind: .photo, value: path))
                        }
                        pickedPhoto = nil
                    }
                }
            }
        }
    }

    private func safePage(_ book: Notebook) -> NotebookPage? {
        guard !book.pages.isEmpty else { return nil }
        return book.pages[min(max(currentPage, 0), book.pages.count - 1)]
    }

    // Studio workspace: compact editorial chrome and a real, editable page.
    @ViewBuilder
    private func editor(_ book: Notebook) -> some View {
        if let page = safePage(book) {
            GeometryReader { geometry in
                let availableWidth = max(300, geometry.size.width - 172)
                let availableHeight = max(360, geometry.size.height - 168)
                let width = min(availableWidth * 0.90, availableHeight * 0.735, 690)
                let height = width / 0.735
                ZStack {
                    AppPalette.parchment.ignoresSafeArea()
                    Image("StudioDesk").resizable().scaledToFill()
                        .ignoresSafeArea().opacity(0.50).allowsHitTesting(false)
                    VStack(spacing: 0) {
                        topBar(book)
                        HStack(spacing: 0) {
                            studioSidebar
                            HStack(spacing: 10) {
                                Button { turnPage(-1) } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 17, weight: .medium))
                                        .frame(width: 37, height: 54)
                                        .background(Color.white.opacity(0.80), in: Capsule())
                                }
                                .disabled(currentPage == 0).opacity(currentPage == 0 ? 0.16 : 1)
                                Spacer(minLength: 0)
                                JournalPageCanvas(page: page, width: width, height: height,
                                                  library: library, bookID: bookID,
                                                  ink: ink, penColor: penColor,
                                                  strokeWidth: strokeWidth,
                                                  pageNumber: currentPage + 1,
                                                  arrangingDecor: arrangingDecor,
                                                  editText: { item in editingTextItem = item },
                                                  typeOnSticker: { item in
                                                      textOnSticker = item
                                                      addingText = true
                                                  })
                                    .id(page.id)
                                    .background(Color.white)
                                    .shadow(color: Color(hex: 0x685747).opacity(0.17), radius: 19, x: 3, y: 13)
                                    .overlay(alignment: .leading) {
                                        Rectangle().fill(.black.opacity(0.026)).frame(width: 7).allowsHitTesting(false)
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.992)))
                                Spacer(minLength: 0)
                                Button { turnPage(1) } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 17, weight: .medium))
                                        .frame(width: 37, height: 54)
                                        .background(Color.white.opacity(0.80), in: Capsule())
                                }
                                .disabled(currentPage == book.pages.count - 1)
                                .opacity(currentPage == book.pages.count - 1 ? 0.16 : 1)
                            }
                            .foregroundStyle(AppPalette.midnight)
                            .padding(.horizontal, 13)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        toolBar(book)
                    }
                }
            }
        }
    }

    private var studioSidebar: some View {
        VStack(spacing: 4) {
            Text("TOOLS")
                .font(.system(size: 8, weight: .semibold)).tracking(2.4)
                .foregroundStyle(AppPalette.muted)
                .padding(.top, 22).padding(.bottom, 12)
            Button { panel = .pages } label: { StudioSideIcon(icon: "square.grid.2x2", title: "Страницы") }
            Button { panel = .paper } label: { StudioSideIcon(icon: "square.stack", title: "Бумага") }
            Button { arrangingDecor = true; panel = .stickers } label: { StudioSideIcon(icon: "sparkles.rectangle.stack", title: "Стикеры") }
            Button { arrangingDecor = true; textOnSticker = nil; addingText = true } label: { StudioSideIcon(icon: "textformat", title: "Шрифты") }
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                StudioSideIcon(icon: "photo", title: "Фото")
            }
            PhotosPicker(selection: $pickedSticker, matching: .images) {
                StudioSideIcon(icon: "scissors", title: "Мои PNG")
            }
            Spacer(minLength: 12)
            Button { addPage() } label: { StudioSideIcon(icon: "plus.square.on.square", title: "Новый лист") }
                .padding(.bottom, 17)
        }
        .buttonStyle(.plain)
        .frame(width: 77)
        .frame(maxHeight: .infinity)
        .background(Color(hex: 0xFFFAF5).opacity(0.91))
        .overlay(alignment: .trailing) { Rectangle().fill(Color(hex: 0xE4DCD2)).frame(width: 1) }
    }

    private func topBar(_ book: Notebook) -> some View {
        HStack(spacing: 13) {
            Button { dismiss() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    Text("Библиотека").font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 15).padding(.vertical, 10)
                .background(Color(hex: 0xF3EDE6), in: Capsule())
            }
            HStack(spacing: 4) {
                Button { undoCurrentPage() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: 0xF3EDE6), in: Circle())
                }
                .disabled(!(safePage(book).map { library.canUndo(page: $0.id) } ?? false))
                .opacity((safePage(book).map { library.canUndo(page: $0.id) } ?? false) ? 1 : 0.32)
                .accessibilityLabel("Отменить действие")
                Button { redoCurrentPage() } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: 0xF3EDE6), in: Circle())
                }
                .disabled(!(safePage(book).map { library.canRedo(page: $0.id) } ?? false))
                .opacity((safePage(book).map { library.canRedo(page: $0.id) } ?? false) ? 1 : 0.32)
                .accessibilityLabel("Повторить действие")
            }
            Spacer(minLength: 0)
            VStack(spacing: 5) {
                Text(book.title)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .lineLimit(1)
                HStack(spacing: 7) {
                    Circle().fill(Color(hex: 0x8AA28C)).frame(width: 5, height: 5)
                    Text("СТРАНИЦА \(currentPage + 1) / \(book.pages.count)   ·   СОХРАНЕНО НА IPAD")
                        .font(.system(size: 8, weight: .medium)).tracking(1.2)
                }.foregroundStyle(AppPalette.muted)
            }
            Spacer(minLength: 0)
            Button { panel = .pages } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 17, weight: .light)).frame(width: 39, height: 39)
                    .background(Color(hex: 0xF3EDE6), in: Circle())
            }.accessibilityLabel("Все страницы")
            Menu {
                Button("Дублировать страницу", systemImage: "plus.square.on.square") { duplicateCurrentPage() }
                Button("Импортировать PDF", systemImage: "doc.richtext") { showingPDFImporter = true }
                Button("Добавить страницу", systemImage: "plus.rectangle.on.rectangle") { addPage() }
                Button("Удалить страницу", systemImage: "trash", role: .destructive) { showDeletePage = true }
                    .disabled(book.pages.count == 1)
                Button("Экспортировать в PDF", systemImage: "square.and.arrow.up") { exportPDF() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 39, height: 39)
                    .background(Color(hex: 0xF3EDE6), in: Circle())
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppPalette.midnight)
        .padding(.horizontal, 23).padding(.vertical, 12)
        .background(Color(hex: 0xFFFDFC).opacity(0.97))
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xE5DBD0)).frame(height: 1) }
    }

    private func toolBar(_ book: Notebook) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { undoCurrentPage() } label: {
                    ToolChip(title: "Отменить", symbol: "arrow.uturn.backward", selected: false)
                }.disabled(!(safePage(book).map { library.canUndo(page: $0.id) } ?? false))
                    .opacity((safePage(book).map { library.canUndo(page: $0.id) } ?? false) ? 1 : 0.35)
                Button { redoCurrentPage() } label: {
                    ToolChip(title: "Вернуть", symbol: "arrow.uturn.forward", selected: false)
                }.disabled(!(safePage(book).map { library.canRedo(page: $0.id) } ?? false))
                    .opacity((safePage(book).map { library.canRedo(page: $0.id) } ?? false) ? 1 : 0.35)
                Rectangle().fill(Color(hex: 0xD8D1CA)).frame(width: 1, height: 23)
                Button { arrangingDecor = false } label: {
                    ToolChip(title: "✍️ Писать сверху", symbol: "pencil.line", selected: !arrangingDecor)
                }.buttonStyle(.plain)
                Button { arrangingDecor = true } label: {
                    ToolChip(title: "↔ Двигать наклейки", symbol: "hand.draw", selected: arrangingDecor)
                }.buttonStyle(.plain)
                Rectangle().fill(Color(hex: 0xD8D1CA)).frame(width: 1, height: 23)
                Text("РИСОВАНИЕ")
                    .font(.system(size: 9, weight: .semibold)).tracking(1.6)
                    .foregroundStyle(AppPalette.muted).padding(.trailing, 4)
                ForEach(InkChoice.allCases) { t in
                    Button { arrangingDecor = false; ink = t } label: {
                        ToolChip(title: t.rawValue, symbol: t.symbol, selected: ink == t)
                    }.buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    Image(systemName: "line.diagonal").font(.system(size: 11))
                    Slider(value: $strokeWidth, in: 1...14, step: 1).tint(AppPalette.rose).frame(width: 90)
                }.foregroundStyle(AppPalette.muted).padding(.horizontal, 8)
                HStack(spacing: 6) {
                    ForEach([0x252932, 0xBC6F84, 0x8A729F, 0x6C9E92, 0xD39A4D, 0x5794C7], id: \.self) { hex in
                        Button { penColor = Color(hex: UInt32(hex)) } label: {
                            Circle().fill(Color(hex: UInt32(hex)))
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }.accessibilityLabel("Цвет чернил")
                    }
                }
                Button { panel = .inkColors } label: {
                    HStack(spacing: 6) {
                        Circle().fill(penColor).frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(color: Color.black.opacity(0.15), radius: 2)
                        Text("Палитра").font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 8)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
                Rectangle().fill(Color(hex: 0xD8D1CA)).frame(width: 1, height: 23).padding(.horizontal, 4)
                Button { arrangingDecor = true; textOnSticker = nil; addingText = true } label: {
                    ToolChip(title: "Текст и шрифты", symbol: "textformat", selected: false)
                }.buttonStyle(.plain)
                Button { arrangingDecor = true; panel = .stickers } label: {
                    ToolChip(title: "Стикеры", symbol: "sparkles", selected: false)
                }.buttonStyle(.plain)
                Button { panel = .paper } label: {
                    ToolChip(title: "Бумага", symbol: "square.stack", selected: false)
                }.buttonStyle(.plain)
                Button { showingPDFImporter = true } label: {
                    ToolChip(title: "Импорт PDF", symbol: "doc.badge.plus", selected: false)
                }.buttonStyle(.plain)
                Button { exportPDF() } label: {
                    ToolChip(title: "Экспорт", symbol: "square.and.arrow.up", selected: false)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.vertical, 15)
        }
        .background(Color(hex: 0xFFFAF6).opacity(0.98))
        .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xDFD5CC)).frame(height: 1) }
    }

    private func undoCurrentPage() {
        guard let book = library.notebook(bookID), let page = safePage(book) else { return }
        library.undo(book: bookID, page: page.id)
    }

    private func redoCurrentPage() {
        guard let book = library.notebook(bookID), let page = safePage(book) else { return }
        library.redo(book: bookID, page: page.id)
    }

    private func turnPage(_ direction: Int) {
        guard let book = library.notebook(bookID) else { return }
        let next = currentPage + direction
        guard book.pages.indices.contains(next) else { return }
        withAnimation(.easeInOut(duration: 0.26)) { currentPage = next }
    }

    private func addPage() {
        guard let book = library.notebook(bookID), let page = safePage(book) else { return }
        library.addPage(book: bookID, after: page.id)
        turnPage(1)
    }

    private func duplicateCurrentPage() {
        guard let book = library.notebook(bookID), let page = safePage(book) else { return }
        if let index = library.duplicatePage(book: bookID, page: page.id) {
            currentPage = index
        }
    }

    private func exportPDF() {
        guard let book = library.notebook(bookID),
              let url = try? PDFNotebookExporter.export(book: book, store: library) else { return }
        exportItem = SharedDocument(url: url)
    }
}

private struct StudioSideIcon: View {
    let icon: String
    let title: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 17, weight: .light))
                .frame(width: 43, height: 38)
                .background(Color(hex: 0xF2EAE4), in: RoundedRectangle(cornerRadius: 11))
            Text(title).font(.system(size: 9, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(AppPalette.midnight)
        .frame(width: 67).padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

private struct ToolChip: View {
    let title: String
    let symbol: String
    let selected: Bool
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 13).padding(.vertical, 11)
        .foregroundStyle(selected ? Color.white : AppPalette.midnight)
        .background(selected ? AppPalette.midnight : Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(selected ? Color.clear : Color(hex: 0xE4D9CF), lineWidth: 1))
    }
}

struct JournalPageCanvas: View {
    let page: NotebookPage
    let width: CGFloat
    let height: CGFloat
    let library: NotebookLibrary
    let bookID: UUID
    let ink: InkChoice
    let penColor: Color
    let strokeWidth: Double
    let pageNumber: Int
    let arrangingDecor: Bool
    let editText: (PageItem) -> Void
    let typeOnSticker: (PageItem) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground(style: page.paper, customHex: page.customPaperHex)
                .overlay {
                    Image("PaperGrain").resizable().scaledToFill().opacity(0.48)
                        .frame(width: width, height: height).clipped().allowsHitTesting(false)
                }
            if let background = page.backgroundFile, let image = library.photo(named: background) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: width, height: height).clipped()
                    .allowsHitTesting(false)
            }
            // Декор на бумаге. В режиме расстановки можно двигать элементы.
            ForEach(page.items) { item in
                DraggablePageItem(item: item, pageID: page.id, bookID: bookID,
                                  library: library, width: width, height: height,
                                  editText: editText, typeOnSticker: typeOnSticker)
                    .position(x: width * item.x, y: height * item.y)
                    .allowsHitTesting(arrangingDecor)
            }
            // Слой PencilKit теперь НАД декором: рукописные слова видны на стикерах.
            PenCanvas(pageID: page.id, library: library, ink: ink,
                      color: UIColor(penColor), strokeWidth: CGFloat(strokeWidth),
                      isEnabled: !arrangingDecor,
                      revision: library.inkRevision)
                .allowsHitTesting(!arrangingDecor)
            VStack {
                HStack {
                    if page.backgroundFile == nil {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("THE JOURNAL")
                            .font(.system(size: 10, weight: .medium)).tracking(2.6)
                        Rectangle().fill(AppPalette.rose.opacity(0.42)).frame(width: 35, height: 1)
                    }
                    .foregroundStyle(AppPalette.rose.opacity(0.63))
                    }
                    Spacer()
                    if page.backgroundFile == nil {
                    Text("PRIVATE NOTES").font(.system(size: 8, weight: .medium))
                        .tracking(2).foregroundStyle(AppPalette.muted.opacity(0.65))
                    }
                }
                Spacer()
                HStack {
                    if page.backgroundFile == nil { Text("little moments, beautifully kept")
                        .font(.system(size: 9, design: .serif)).italic() }
                    Spacer()
                    Text(String(format: "%02d", pageNumber))
                        .font(.system(size: 11, design: .serif))
                }
                .foregroundStyle(AppPalette.muted.opacity(0.7))
            }
            .padding(.horizontal, 31).padding(.vertical, 27)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .clipped()
        .overlay(Rectangle().stroke(Color(hex: 0xA58B83).opacity(0.25), lineWidth: 1))
    }
}

struct DraggablePageItem: View {
    let item: PageItem
    let pageID: UUID
    let bookID: UUID
    let library: NotebookLibrary
    let width: CGFloat
    let height: CGFloat
    let editText: (PageItem) -> Void
    let typeOnSticker: (PageItem) -> Void
    @State private var drag: CGSize = .zero
    @State private var pinch: CGFloat = 1
    @State private var twist: Angle = .zero

    var body: some View {
        itemContent
            .scaleEffect(item.scale * Double(pinch))
            .rotationEffect(.degrees(item.angle) + twist)
            .offset(drag)
            .shadow(color: .black.opacity(0.13), radius: 3, y: 2)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { drag = $0.translation }
                    .onEnded { value in
                        library.moveItem(book: bookID, page: pageID, item: item.id,
                                         x: item.x + value.translation.width / width,
                                         y: item.y + value.translation.height / height)
                        drag = .zero
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { pinch = $0 }
                    .onEnded { value in
                        library.resizeItem(book: bookID, page: pageID, item: item.id,
                                           scale: item.scale * Double(value), angle: item.angle)
                        pinch = 1
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { twist = $0 }
                    .onEnded { value in
                        library.resizeItem(book: bookID, page: pageID, item: item.id,
                                           scale: item.scale, angle: item.angle + value.degrees)
                        twist = .zero
                    }
            )
            .onTapGesture(count: 2) {
                if item.kind == .text { editText(item) }
                else { typeOnSticker(item) }
            }
            .contextMenu {
                if item.kind == .text {
                    Button("Изменить текст и шрифт", systemImage: "character.cursor.ibeam") { editText(item) }
                } else {
                    Button("Напечатать на наклейке", systemImage: "textformat") { typeOnSticker(item) }
                }
                Button("На передний план", systemImage: "square.3.layers.3d.top.filled") {
                    library.bringForward(book: bookID, page: pageID, item: item.id)
                }
                Button("На задний план", systemImage: "square.3.layers.3d.bottom.filled") {
                    library.sendBackward(book: bookID, page: pageID, item: item.id)
                }
                if item.kind != .text {
                    Menu("Повернуть наклейку", systemImage: "rotate.right") {
                        Button("↶ На 15° влево") { library.rotateItem(book: bookID, page: pageID, item: item.id, degrees: -15) }
                        Button("↷ На 15° вправо") { library.rotateItem(book: bookID, page: pageID, item: item.id, degrees: 15) }
                        Button("↶ На 90° влево") { library.rotateItem(book: bookID, page: pageID, item: item.id, degrees: -90) }
                        Button("↷ На 90° вправо") { library.rotateItem(book: bookID, page: pageID, item: item.id, degrees: 90) }
                    }
                }
                Button("Копировать украшение", systemImage: "plus.square.on.square") {
                    library.duplicateItem(book: bookID, page: pageID, item: item.id)
                }
                Button("Убрать", systemImage: "trash", role: .destructive) {
                    library.deleteItem(book: bookID, page: pageID, item: item.id)
                }
            }
    }

    @ViewBuilder
    private var itemContent: some View {
        switch item.kind {
        case .sticker:
            Image("Sticker_\(item.value)")
                .resizable().scaledToFit()
                .frame(width: width * (item.value.hasPrefix("Frame") ? 0.92 : 0.22),
                       height: item.value.hasPrefix("Frame") ? height * 0.94 : width * 0.22)
        case .customSticker:
            if let image = library.photo(named: item.value) {
                Image(uiImage: image)
                    .resizable().scaledToFit().frame(width: width * 0.27, height: width * 0.27)
            }
        case .photo:
            if let image = library.photo(named: item.value) {
                Image(uiImage: image)
                    .resizable().scaledToFill().frame(width: width * 0.34, height: width * 0.33)
                    .clipped().padding(7).background(.white)
                    .shadow(color: .black.opacity(0.17), radius: 4, y: 3)
            }
        case .text:
            let style = item.textStyle ?? PageTextStyle()
            Text(item.value)
                .font(.custom(style.fontName, size: CGFloat(style.fontSize) * width / 650))
                .tracking(style.letterSpacing * width / 650)
                .foregroundStyle(Color(hex: style.colorHex).opacity(style.opacity))
                .multilineTextAlignment(style.alignment == "left" ? .leading : style.alignment == "right" ? .trailing : .center)
                .frame(width: width * (item.textWidthFactor ?? 0.66))
                .lineLimit(item.attachedStickerID == nil ? nil : 6)
                .minimumScaleFactor(0.60)
                .padding(style.backgroundHex == nil ? 2 : 11)
                .background {
                    if let hex = style.backgroundHex {
                        RoundedRectangle(cornerRadius: 8).fill(Color(hex: hex).opacity(0.90))
                    }
                }
        }
    }
}

// Paper is drawn locally on the iPad so all patterns work offline and stay sharp at any zoom.
struct PaperBackground: View {
    let style: String
    var customHex: UInt32? = nil

    var body: some View {
        Canvas { ctx, size in
            let preset = PaperCatalog.find(style)
            let bg = customHex ?? preset?.background ?? 0xFFFDF7
            let accent = preset?.accent ?? 0xBFB6AF
            let ink = Color(hex: accent)
            let pattern = preset?.pattern ?? "blank"
            let k = max(CGFloat(0.15), size.width / 700)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: bg)))
            let w = size.width; let h = size.height
            let left = 38*k; let right = w - 38*k
            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ alpha: Double = 0.43, _ thickness: CGFloat = 0.75) {
                var path = Path()
                path.move(to: CGPoint(x: x1, y: y1))
                path.addLine(to: CGPoint(x: x2, y: y2))
                ctx.stroke(path, with: .color(ink.opacity(alpha)), lineWidth: thickness*k)
            }
            func frame(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ alpha: Double = 0.62, _ radius: CGFloat = 9) {
                guard width > 0, height > 0 else { return }
                ctx.stroke(Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius*k),
                           with: .color(ink.opacity(alpha)), lineWidth: 1*k)
            }
            func title(_ value: String, _ x: CGFloat, _ y: CGFloat, _ fontSize: CGFloat = 14) {
                let text = Text(value).font(.system(size: fontSize*k, weight: .semibold, design: .rounded))
                    .foregroundColor(ink.opacity(0.82))
                ctx.draw(ctx.resolve(text), at: CGPoint(x: x, y: y), anchor: .leading)
            }
            func lines(_ gap: CGFloat = 34, _ start: CGFloat = 102) {
                for y in stride(from: start*k, through: h - 40*k, by: gap*k) {
                    line(left, y, right, y)
                }
            }
            func grid(_ gap: CGFloat = 32, _ alpha: Double = 0.30) {
                for y in stride(from: 22*k, through: h-22*k, by: gap*k) { line(24*k,y,w-24*k,y,alpha) }
                for x in stride(from: 24*k, through: w-24*k, by: gap*k) { line(x,24*k,x,h-24*k,alpha) }
            }
            func dots() {
                let step: CGFloat = 31*k
                for y in stride(from: 26*k, through: h-25*k, by: step) {
                    for x in stride(from: 27*k, through: w-25*k, by: step) {
                        let r: CGFloat = 2.0*k
                        ctx.fill(Path(ellipseIn: CGRect(x: x-r/2,y:y-r/2,width:r,height:r)),
                                 with: .color(ink.opacity(0.50)))
                    }
                }
            }
            func rectangleGrid(_ cols: Int, _ rows: Int, _ x: CGFloat, _ y: CGFloat, _ bw: CGFloat, _ bh: CGFloat) {
                frame(x,y,bw,bh,0.52)
                for c in 1..<cols { let pos=x+bw*CGFloat(c)/CGFloat(cols);line(pos,y,pos,y+bh,0.50) }
                for r in 1..<rows { let pos=y+bh*CGFloat(r)/CGFloat(rows);line(x,pos,x+bw,pos,0.50) }
            }
            func tinyFlower(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat = 1) {
                let rad: CGFloat = 5.6*k*scale
                for n in 0..<5 {
                    let a = CGFloat(n)*(.pi*2/5)
                    let p = CGRect(x:x+cos(a)*rad-rad*0.49,y:y+sin(a)*rad-rad*0.49,
                                   width:rad*0.98,height:rad*0.98)
                    ctx.fill(Path(ellipseIn:p),with:.color(ink.opacity(0.27)))
                }
                ctx.fill(Path(ellipseIn:CGRect(x:x-2.5*k,y:y-2.5*k,width:5*k,height:5*k)),
                         with:.color(Color(hex:0xE8CC9F).opacity(0.65)))
            }
            func heart(_ x: CGFloat, _ y: CGFloat) {
                ctx.fill(Path(ellipseIn: CGRect(x:x-4*k,y:y-2*k,width:7*k,height:7*k)),with:.color(ink.opacity(0.32)))
                ctx.fill(Path(ellipseIn: CGRect(x:x+1*k,y:y-2*k,width:7*k,height:7*k)),with:.color(ink.opacity(0.32)))
                var t = Path();t.move(to:CGPoint(x:x-4*k,y:y+2*k));t.addLine(to:CGPoint(x:x+4*k,y:y+10*k));t.addLine(to:CGPoint(x:x+9*k,y:y+2*k));t.closeSubpath()
                ctx.fill(t,with:.color(ink.opacity(0.32)))
            }
            switch pattern {
            case "lines", "thinlines", "doublelines", "margin", "rainbowlines":
                let step: CGFloat = pattern == "thinlines" ? 24 : 34
                lines(step)
                if pattern == "doublelines" {
                    for y in stride(from: 102*k, through:h-40*k, by:step*k) { line(left,y+5*k,right,y+5*k,0.21) }
                }
                if pattern == "margin" { line(100*k,56*k,100*k,h-46*k,0.6,1.3) }
                if pattern == "rainbowlines" {
                    for i in 0..<4 { line(26*k,CGFloat(28+i*9)*k,right,CGFloat(28+i*9)*k,0.23,2.5) }
                }
            case "grid", "finegrid": grid(pattern == "finegrid" ? 16 : 34)
            case "dots": dots()
            case "gingham":
                for x in stride(from: 0.0, through:w, by:42*k) {
                    let r=CGRect(x:x,y:0,width:17*k,height:h)
                    ctx.fill(Path(r),with:.color(ink.opacity(0.095)))
                    line(x,0,x,h,0.15)
                }
                for y in stride(from: 0.0, through:h, by:42*k) {
                    ctx.fill(Path(CGRect(x:0,y:y,width:w,height:17*k)),with:.color(ink.opacity(0.095)))
                    line(0,y,w,y,0.15)
                }
            case "stripes":
                for y in stride(from: 0.0, through:h, by:48*k) {
                    ctx.fill(Path(CGRect(x:0,y:y,width:w,height:9*k)),with:.color(ink.opacity(0.13)))
                }
            case "waves", "rain":
                for row in 0..<22 {
                    let y=CGFloat(row)*47*k+26*k
                    var path=Path();path.move(to:CGPoint(x:25*k,y:y))
                    for i in 0...60 {
                        let x=25*k+(w-50*k)*CGFloat(i)/60
                        path.addLine(to:CGPoint(x:x,y:y+sin(CGFloat(i)*0.38)*4*k))
                    }
                    ctx.stroke(path,with:.color(ink.opacity(pattern == "rain" ? 0.18 : 0.27)),lineWidth:1*k)
                }
            case "confetti", "hearts", "stars", "bows", "clouds":
                for y in stride(from: 64*k, through:h-40*k, by:125*k) {
                    for x in stride(from: 62*k, through:w-40*k, by:125*k) {
                        if pattern == "hearts" { heart(x,y) }
                        else if pattern == "stars" {
                            for i in 0..<4 { let a=CGFloat(i)*CGFloat.pi/2;line(x-cos(a)*5*k,y-sin(a)*5*k,x+cos(a)*5*k,y+sin(a)*5*k,0.35) }
                        } else if pattern == "bows" {
                            ctx.stroke(Path(ellipseIn:CGRect(x:x-12*k,y:y-4*k,width:12*k,height:9*k)),with:.color(ink.opacity(0.36)),lineWidth:2*k)
                            ctx.stroke(Path(ellipseIn:CGRect(x:x+1*k,y:y-4*k,width:12*k,height:9*k)),with:.color(ink.opacity(0.36)),lineWidth:2*k)
                        } else if pattern == "clouds" {
                            for n in 0..<3 { ctx.fill(Path(ellipseIn:CGRect(x:x+CGFloat(n*8)*k,y:y-6*k,width:15*k,height:11*k)),with:.color(ink.opacity(0.16))) }
                        } else { tinyFlower(x,y,0.50) }
                    }
                }
            case "flowers", "leaves", "botanical", "lace":
                frame(29*k,32*k,w-58*k,h-64*k,0.32,18)
                for i in 0..<14 {
                    let y=(50+CGFloat(i)*57)*k
                    if y>h-26*k { break }
                    if pattern == "leaves" || pattern == "botanical" {
                        ctx.fill(Path(ellipseIn:CGRect(x:27*k,y:y,width:12*k,height:21*k)),with:.color(ink.opacity(0.25)))
                        ctx.fill(Path(ellipseIn:CGRect(x:w-39*k,y:y,width:12*k,height:21*k)),with:.color(ink.opacity(0.25)))
                    } else {
                        tinyFlower(37*k,y,0.72);tinyFlower(w-37*k,y,0.72)
                    }
                }
                if pattern == "botanical" { title("BOTANICAL NOTES",66*k,76*k,13) }
            case "vintage", "postcard", "kraft", "torn":
                frame(27*k,30*k,w-54*k,h-60*k,0.46)
                frame(39*k,42*k,w-78*k,h-84*k,0.27)
                if pattern == "postcard" { title("POSTCARD  •  MEMORIES",70*k,80*k);line(left,112*k,right,112*k,0.34) }
                if pattern == "torn" {
                    for n in 0..<24 { let x=(24+CGFloat(n)*26)*k;line(x,22*k,x+11*k,30*k,0.21) }
                }
            case "washi", "tabs", "photo", "polaroids", "memory":
                if pattern == "tabs" {
                    for i in 0..<6 {
                        let y=CGFloat(120+i*95)*k
                        ctx.fill(Path(roundedRect:CGRect(x:w-46*k,y:y,width:46*k,height:55*k),cornerRadius:5*k),with:.color(ink.opacity(Double(0.14+0.05*Double(i%3)))))
                    }
                    lines(38)
                } else if pattern == "washi" {
                    for row in 0..<4 {
                        let y=CGFloat(100+row*195)*k
                        ctx.fill(Path(CGRect(x:52*k,y:y,width:w-104*k,height:14*k)),with:.color(ink.opacity(0.20)))
                        frame(58*k,y+31*k,w-116*k,135*k,0.35)
                    }
                } else {
                    for row in 0..<3 {
                        let y=(85+CGFloat(row)*260)*k
                        let margin=58*k;let gap=22*k;let bw=(w-2*margin-gap)/2
                        for col in 0..<2 {
                            let x=margin+CGFloat(col)*(bw+gap)
                            frame(x,y,bw,210*k,0.55,7)
                            frame(x+12*k,y+12*k,bw-24*k,145*k,0.25,5)
                            line(x+13*k,y+172*k,x+bw-13*k,y+172*k,0.34)
                        }
                    }
                }
            case "cornell", "study", "class", "reading", "recipe", "morning", "gratitude", "dream":
                title(pattern == "recipe" ? "РЕЦЕПТ" : pattern == "reading" ? "МОИ КНИГИ" : pattern == "dream" ? "ДНЕВНИК СНОВ" : "МОИ ЗАМЕТКИ", 58*k,75*k)
                line(left,106*k,right,106*k,0.60)
                lines(37,150)
                if pattern == "cornell" || pattern == "study" || pattern == "class" {
                    line(180*k,126*k,180*k,h-150*k,0.48,1.3)
                    line(left,h-142*k,right,h-142*k,0.45,1.3)
                }
                if pattern == "gratitude" { for n in 0..<8 { heart(56*k,CGFloat(166+n*75)*k) } }
            case "daily", "checklist", "schedule", "goals", "meal", "project":
                title(pattern == "meal" ? "ПЛАН ПИТАНИЯ" : pattern == "goals" ? "МОИ ЦЕЛИ" : pattern == "project" ? "ПРОЕКТ" : "ПЛАН НА ДЕНЬ",60*k,77*k)
                line(left,108*k,right,108*k,0.6)
                for i in 0..<15 {
                    let y=CGFloat(158+i*45)*k
                    line(84*k,y,right,y,0.43)
                    if pattern != "daily" {
                        frame(51*k,y-21*k,18*k,18*k,0.5,3)
                    }
                }
            case "calendar", "weekly", "tracker", "mood", "budget":
                title(pattern == "calendar" ? "КАЛЕНДАРЬ МЕСЯЦА" : pattern == "tracker" ? "ТРЕКЕР ПРИВЫЧЕК" : pattern == "mood" ? "НАСТРОЕНИЕ" : pattern == "budget" ? "МОЙ БЮДЖЕТ" : "МОЯ НЕДЕЛЯ", 46*k,70*k)
                line(left,105*k,right,105*k,0.48)
                if pattern == "calendar" { rectangleGrid(7,6,39*k,168*k,w-78*k,520*k) }
                else if pattern == "weekly" { rectangleGrid(2,4,39*k,148*k,w-78*k,h-206*k) }
                else if pattern == "tracker" { rectangleGrid(8,11,40*k,163*k,w-80*k,580*k) }
                else if pattern == "mood" {
                    for row in 0..<5 {
                        for col in 0..<6 {
                            let x=(92+CGFloat(col)*104)*k;let y=(192+CGFloat(row)*115)*k
                            ctx.stroke(Path(ellipseIn:CGRect(x:x,y:y,width:44*k,height:44*k)),with:.color(ink.opacity(0.5)),lineWidth:1*k)
                        }
                    }
                } else { rectangleGrid(3,12,40*k,156*k,w-80*k,620*k) }
            case "mindmap":
                frame(w*0.34,h*0.40,w*0.32,h*0.15,0.62,20)
                for i in 0..<6 {
                    let a=CGFloat(i)*CGFloat.pi/3
                    let x=w*0.5+cos(a)*w*0.34;let y=h*0.48+sin(a)*h*0.31
                    line(w*0.5,h*0.47,x,y,0.3)
                    frame(x-60*k,y-40*k,120*k,80*k,0.45,14)
                }
            case "storyboard":
                for row in 0..<4 {
                    for col in 0..<2 {
                        let x=(50+CGFloat(col)*325)*k;let y=(130+CGFloat(row)*190)*k
                        frame(x,y,290*k,156*k,0.50,7)
                    }
                }
            case "music":
                for group in 0..<9 {
                    let y=CGFloat(95+group*88)*k
                    for j in 0..<5 {line(left,y+CGFloat(j*11)*k,right,y+CGFloat(j*11)*k,0.52)}
                }
            default: break
            }
        }
        .accessibilityLabel(PaperCatalog.find(style)?.title ?? "Бумага")
    }
}

struct StickerPalette: View {
    let add: (String) -> Void
    @State private var category = "Все"
    @State private var search = ""
    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 12)]
    private var filtered: [StickerEntry] {
        StickerCatalog.all.filter { entry in
            (category == "Все" || entry.category == category) &&
            (search.isEmpty || entry.title.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Коллекция украшений")
                            .font(.system(size: 28, design: .serif)).foregroundStyle(AppPalette.midnight)
                        Text("\(StickerCatalog.all.count) бесплатных украшений · работают без интернета")
                            .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    }
                    TextField("Найти тему: осень, зима, книги, горы…", text: $search)
                        .textFieldStyle(.roundedBorder)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(StickerCatalog.categories, id: \.self) { section in
                                Button { category = section } label: {
                                    Text(section)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(category == section ? .white : AppPalette.midnight)
                                        .padding(.horizontal, 13).padding(.vertical, 9)
                                        .background(category == section ? AppPalette.rose : Color.white.opacity(0.87), in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if filtered.isEmpty {
                        ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass")
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filtered) { sticker in
                                Button { add(sticker.id) } label: {
                                    VStack(spacing: 6) {
                                        Image("Sticker_\(sticker.id)")
                                            .resizable().scaledToFit()
                                            .frame(height: 100)
                                            .padding(.horizontal, 6)
                                        Text(sticker.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(AppPalette.midnight)
                                            .frame(height: 30)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xE8DED4)))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if category == "Рамки" || category == "Все" {
                        Text("Нажми на наклейку дважды, чтобы набрать текст. Удерживай для поворота, копирования и слоёв. Двигай пальцем, крути двумя пальцами.")
                            .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    }
                }.padding(24)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Украшения")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

struct PaperPalette: View {
    let current: String
    let customHex: UInt32?
    let select: (String) -> Void
    let chooseCustom: (UInt32) -> Void
    @State private var customColor: Color
    @State private var category = "Все"
    @State private var search = ""
    private let columns = [GridItem(.adaptive(minimum: 128, maximum: 190), spacing: 14)]
    private var papers: [PaperPreset] {
        PaperCatalog.all.filter { item in
            (category == "Все" || item.category == category) &&
            (search.isEmpty || item.title.localizedCaseInsensitiveContains(search))
        }
    }

    init(current: String, customHex: UInt32?, select: @escaping (String) -> Void,
         chooseCustom: @escaping (UInt32) -> Void) {
        self.current = current
        self.customHex = customHex
        self.select = select
        self.chooseCustom = chooseCustom
        _customColor = State(initialValue: Color(hex: customHex ?? 0xFAE5EC))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("93 вида бумаги и шаблонов")
                            .font(.system(size: 21, design: .serif))
                        Spacer()
                        Text("Бесплатно · офлайн")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(AppPalette.rose)
                    }
                    TextField("Найти бумагу или шаблон...", text: $search)
                        .textFieldStyle(.roundedBorder)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(PaperCatalog.categories, id: \.self) { cat in
                                Button { category = cat } label: {
                                    Text(cat).font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 13).padding(.vertical, 10)
                                        .foregroundStyle(category == cat ? Color.white : AppPalette.midnight)
                                        .background(category == cat ? AppPalette.rose : Color(hex: 0xEEE5DE), in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        ColorPicker("Свой оттенок", selection: $customColor, supportsOpacity: false)
                        Button("Применить") { chooseCustom(customColor.hexValue) }
                            .buttonStyle(.borderedProminent).tint(AppPalette.rose)
                    }
                    .font(.system(size: 13))
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(papers) { option in
                            Button { select(option.id) } label: {
                                VStack(spacing: 8) {
                                    PaperBackground(style: option.id)
                                        .aspectRatio(0.74, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(current == option.id ? AppPalette.rose : Color(hex: 0xE3D8D1), lineWidth: current == option.id ? 3 : 1))
                                        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                                        .overlay(alignment: .topTrailing) {
                                            if current == option.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(AppPalette.rose).padding(5)
                                            }
                                        }
                                    Text(option.title).font(.system(size: 12, design: .serif))
                                        .foregroundStyle(AppPalette.midnight)
                                        .lineLimit(2).multilineTextAlignment(.center)
                                    Text(option.category).font(.system(size: 9))
                                        .foregroundStyle(AppPalette.muted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Бумага и шаблоны")
            .navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.large])
    }
}

import SwiftUI
import PencilKit
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

private enum EditorPanel: String, Identifiable {
    case stickers, paper, pages, inkColors, layers, shapes, myMaterials, compositions
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
    case eraser = "Ластик-штрих"
    case pixelEraser = "Ластик-часть"
    case lasso = "Лассо"
    case decorative = "Узоры"
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
        case .pixelEraser: "eraser.fill"
        case .lasso: "lasso"
        case .decorative: "sparkles"
        }
    }
}

struct NotebookEditor: View {
    let bookID: UUID
    @EnvironmentObject private var library: NotebookLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var focusMode = false
    @State private var pageZoom: CGFloat = 1
    @State private var showFilmstrip = true
    @State private var ink: InkChoice = .pen
    @State private var penColor: Color = AppPalette.midnight
    @State private var strokeWidth: Double = 3
    @State private var strokeOpacity: Double = 1
    @AppStorage("qpPencilOnly") private var pencilOnly = false
    @AppStorage("qpConstantInkWidth") private var constantWidth = true
    @State private var editingTextItem: PageItem?
    @State private var editingPhotoItem: PageItem?
    @State private var stickerDraft: WorkshopPhoto?
    @AppStorage("qpMyPNGCollection") private var myPNGCollection = ""
    private func rememberSticker(_ name: String) {
        var items = myPNGCollection.split(separator: "|").map(String.init)
        items.removeAll { $0 == name }
        items.insert(name, at: 0)
        myPNGCollection = Array(items.prefix(300)).joined(separator: "|")
    }
    // ТОЛЬКО явное нажатие «Двигать наклейки» отключает PencilKit.
    // После вставки стикера, фото или текста редактор возвращается к рисованию.
    @State private var arrangingDecor = false
    @State private var decorativeSticker = "Goldstar"
    @AppStorage("qpFavoritePens") private var favoritePensJSON = ""
    private var favoritePens: [SavedPen] {
        guard let data = favoritePensJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SavedPen].self, from: data)) ?? []
    }
    private func saveFavoritePen() {
        var list = favoritePens
        let value = SavedPen(tool: ink.rawValue, color: penColor.hexValue, width: strokeWidth)
        list.removeAll { $0.tool == value.tool && $0.color == value.color && $0.width == value.width }
        list.insert(value, at: 0)
        if let data = try? JSONEncoder().encode(Array(list.prefix(8))),
           let json = String(data: data, encoding: .utf8) { favoritePensJSON = json }
    }
    @State private var showFloatingTools = true
    @AppStorage("qpFloatingX") private var floatingX = -4.0
    @AppStorage("qpFloatingY") private var floatingY = 102.0
    @AppStorage("qpStickerPanelX") private var stickerPanelX = 0.0
    @AppStorage("qpStickerPanelY") private var stickerPanelY = 0.0
    @State private var stickerPanelPinned = true
    @State private var textOnSticker: PageItem?
    @State private var addingText = false
    @State private var pickedSticker: PhotosPickerItem?
    @State private var showingPDFImporter = false
    @State private var showingOwnPNGImporter = false
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
        .onChange(of: currentPage) { _, _ in pageZoom = 1 }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: Binding(
            get: { panel == .stickers ? nil : panel },
            set: { panel = $0 }
        )) { panel in
            if let book = library.notebook(bookID), let page = safePage(book) {
                switch panel {
                case .stickers: EmptyView()
                case .paper:
                    PaperPalette(current: page.paper, customHex: page.customPaperHex,
                                 decorationOpacity: page.decorationOpacity ?? 1) { paper in
                        library.setPaper(book: bookID, page: page.id, style: paper)
                        self.panel = nil
                    } chooseCustom: { hex in
                        library.setPaperColor(book: bookID, page: page.id, hex: hex)
                        self.panel = nil
                    } setIntensity: { level in
                        library.setDecorationOpacity(book: bookID, page: page.id, opacity: level)
                    }
                case .inkColors:
                    InkColorPalette(color: $penColor)
                case .layers:
                    StudioLayerManager(page: page, library: library, bookID: bookID)
                case .shapes:
                    ShapePalette { shape in
                        var item = PageItem(kind: .shape, value: shape, x: 0.5, y: 0.48)
                        item.textStyle = PageTextStyle(colorHex: penColor.hexValue)
                        library.addItem(book: bookID, page: page.id, item: item)
                        arrangingDecor = false
                        self.panel = nil
                    }
                case .compositions:
                    MyCompositionsGallery(library: library) { id in
                        library.addSavedComposition(id, book: bookID, page: page.id)
                        arrangingDecor = false
                        self.panel = nil
                    }
                case .myMaterials:
                    MyPNGGallery(library: library, importFromPhotos: $pickedSticker,
                                 importFromFiles: $showingOwnPNGImporter) { path in
                        library.addItem(book: bookID, page: page.id,
                            item: PageItem(kind: .customSticker, value: path))
                        arrangingDecor = false
                        self.panel = nil
                    }
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
                    arrangingDecor = false
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
        .sheet(item: $editingPhotoItem) { item in
            if let image = library.photo(named: item.value),
               let book = library.notebook(bookID), let page = safePage(book) {
                PhotoWorkshopSheet(source: image, stickerMode: item.kind == .customSticker) { data in
                    if let newFile = library.savePhoto(data) {
                        library.updateItemImage(book: bookID, page: page.id, item: item.id, filename: newFile)
                    }
                }
            }
        }
        .sheet(item: $stickerDraft) { draft in
            if let book = library.notebook(bookID), let page = safePage(book) {
                PhotoWorkshopSheet(source: draft.image, stickerMode: true) { data in
                    if let path = library.savePhoto(data) {
                        rememberSticker(path)
                        library.addItem(book: bookID, page: page.id,
                                        item: PageItem(kind: .customSticker, value: path))
                        arrangingDecor = false
                    }
                }
            }
        }
        .sheet(item: $exportItem) { item in ShareSheet(url: item.url) }
        .fileImporter(isPresented: $showingOwnPNGImporter, allowedContentTypes: [.png, .jpeg, .heic]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if let image = UIImage(contentsOfFile: url.path) {
                    // Close the My PNG sheet before presenting the sticker editor.
                    panel = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        stickerDraft = WorkshopPhoto(image: image)
                    }
                } else { importError = "Изображение не удалось открыть." }
            } catch { importError = "Не удалось прочитать изображение из «Файлов»." }
        }
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
                        if let image = UIImage(data: data) {
                            panel = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                stickerDraft = WorkshopPhoto(image: image)
                            }
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
                            arrangingDecor = false
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
                let availableWidth = max(300, geometry.size.width - (focusMode ? 90 : 172))
                let availableHeight = max(320, geometry.size.height - (focusMode ? 60 : (showFilmstrip ? 268 : 208)))
                let width = min(availableWidth * 0.90, availableHeight * 0.735, 690)
                let height = width / 0.735
                ZStack {
                    AppPalette.parchment.ignoresSafeArea()
                    Image("StudioDesk").resizable().scaledToFill()
                        .ignoresSafeArea().opacity(0.50).allowsHitTesting(false)
                    VStack(spacing: 0) {
                        if !focusMode {
                            topBar(book)
                            quickToolStrip
                        }
                        HStack(spacing: 0) {
                            if !focusMode { studioSidebar }
                            HStack(spacing: 10) {
                                Button { turnPage(-1) } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 17, weight: .medium))
                                        .frame(width: 37, height: 54)
                                        .background(Color.white.opacity(0.80), in: Capsule())
                                }
                                .disabled(currentPage == 0).opacity(currentPage == 0 ? 0.16 : 1)
                                Spacer(minLength: 0)
                                StudioPageViewport(pageSize: CGSize(width: width, height: height), zoom: $pageZoom, allowsZoom: !arrangingDecor) {
                                JournalPageCanvas(page: page, width: width, height: height,
                                                  library: library, bookID: bookID,
                                                  ink: ink, penColor: penColor,
                                                  strokeWidth: strokeWidth,
                                                  strokeOpacity: strokeOpacity,
                                                  pencilOnly: pencilOnly,
                                                  constantWidth: constantWidth,
                                                  pageNumber: currentPage + 1,
                                                  arrangingDecor: arrangingDecor,
                                                  decorativeSticker: decorativeSticker,
                                                  editText: { item in editingTextItem = item },
                                                  editPhoto: { item in editingPhotoItem = item },
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
                                    .transition(.opacity)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        if !focusMode {
                            HStack(spacing: 14) {
                                Text("Страница \(currentPage + 1) из \(book.pages.count)")
                                Spacer()
                                Button("−") { pageZoom = max(1, pageZoom - 0.25) }
                                Button("\(Int(pageZoom * 100))%") { pageZoom = 1 }
                                Button("+") { pageZoom = min(3, pageZoom + 0.25) }
                                Text("Масштаб и сдвиг — двумя пальцами").foregroundStyle(AppPalette.muted)
                            }
                            .font(.system(size: 11)).padding(.horizontal, 25).padding(.vertical, 6)
                            if showFilmstrip { miniaturePages(book) }
                            toolBar(book)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if focusMode {
                            Button { focusMode = false } label: {
                                Label("Вернуть панели", systemImage: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 11)).padding(11)
                                    .background(.regularMaterial, in: Capsule())
                            }.padding(12)
                        }
                    }
                    .overlay(alignment: .trailing) {
                        if panel == .stickers && !focusMode {
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "line.3.horizontal")
                                        .frame(width: 35, height: 28)
                                        .contentShape(Rectangle())
                                        .gesture(DragGesture(minimumDistance: 1).onEnded { gesture in
                                            if !stickerPanelPinned {
                                                stickerPanelX = min(max(stickerPanelX + gesture.translation.width, -520), 55)
                                                stickerPanelY = min(max(stickerPanelY + gesture.translation.height, -240), 240)
                                            }
                                        })
                                    Text("Мои украшения ♡").font(.system(size: 14, design: .serif))
                                    Spacer()
                                    Button { stickerPanelPinned.toggle() } label: {
                                        Image(systemName: stickerPanelPinned ? "pin.fill" : "pin.slash")
                                    }
                                    Button { panel = nil } label: { Image(systemName: "xmark") }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                StickerPalette { name in insertSelectedSticker(name, page: page) }
                            }
                            .frame(width: min(320, geometry.size.width * 0.44),
                                   height: min(610, geometry.size.height - 110))
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppPalette.rose.opacity(0.35)))
                            .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
                            .offset(x: stickerPanelX, y: stickerPanelY)
                            .padding(.trailing, 12)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if showFloatingTools && !focusMode {
                            floatingQuickPanel
                                .offset(x: floatingX, y: floatingY)
                                .padding(.trailing, 8)
                        }
                    }
                }
            }
        }
    }

    private func miniaturePages(_ book: Notebook) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(book.pages.enumerated()), id: \.element.id) { index, page in
                    Button { currentPage = index } label: {
                        VStack(spacing: 3) {
                            PaperBackground(style: page.paper, customHex: page.customPaperHex)
                                .frame(width: 30, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .stroke(currentPage == index ? AppPalette.rose : Color.gray.opacity(0.2),
                                            lineWidth: currentPage == index ? 2 : 1))
                            Text("\(index + 1)").font(.system(size: 9))
                        }
                    }.buttonStyle(.plain)
                }
                Button { addPage() } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 17)).frame(width: 40, height: 40)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.vertical, 6)
        }
        .frame(height: 64)
        .background(Color(hex: 0xFFF9F5).opacity(0.92))
    }

    private func insertSelectedSticker(_ stickerName: String, page: NotebookPage) {
        arrangingDecor = false
        if let parts = StudioCompositionCatalog.components(for: stickerName) {
            let group = UUID()
            library.addItems(book: bookID, page: page.id, items: [
                PageItem(kind: .sticker, value: parts.0, x: 0.44, y: 0.48, scale: 1.15, groupID: group),
                PageItem(kind: .sticker, value: parts.1, x: 0.57, y: 0.59, scale: 0.80, groupID: group)
            ])
        } else {
            library.addItem(book: bookID, page: page.id,
                item: PageItem(kind: .sticker, value: stickerName, x: 0.5, y: 0.5))
        }
        panel = nil
        if ink == .decorative { ink = .pen }
    }

    private var floatingQuickPanel: some View {
        VStack(spacing: 9) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 132, height: 25)
                .foregroundStyle(AppPalette.rose)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 1).onEnded { movement in
                    floatingX = min(max(floatingX + movement.translation.width, -520), 80)
                    floatingY = min(max(floatingY + movement.translation.height, 0), 580)
                })
                .accessibilityLabel("Перетащить панель")
            HStack(spacing: 8) {
                Button { ink = .pen; arrangingDecor = false } label: { Image(systemName: "pencil.tip") }
                Button { ink = .decorative; arrangingDecor = false } label: { Image(systemName: "sparkles") }
                Button { panel = .stickers } label: { Image(systemName: "heart.text.square") }
                Button { panel = .inkColors } label: { Image(systemName: "paintpalette") }
                Button { showFloatingTools = false } label: { Image(systemName: "xmark.circle") }
            }
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundStyle(AppPalette.midnight)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppPalette.rose.opacity(0.32)))
        .shadow(color: .black.opacity(0.10), radius: 9, y: 4)
    }

    private var studioSidebar: some View {
        VStack(spacing: 4) {
            Text("TOOLS")
                .font(.system(size: 8, weight: .semibold)).tracking(2.4)
                .foregroundStyle(AppPalette.muted)
                .padding(.top, 22).padding(.bottom, 12)
            Button { panel = .pages } label: { StudioSideIcon(icon: "square.grid.2x2", title: "Страницы") }
            Button { panel = .paper } label: { StudioSideIcon(icon: "square.stack", title: "Бумага") }
            Button { panel = .layers } label: { StudioSideIcon(icon: "square.3.layers.3d", title: "Слои") }
            Button { panel = .compositions } label: { StudioSideIcon(icon: "square.on.square.dashed", title: "Композиции") }
            Button { panel = .shapes } label: { StudioSideIcon(icon: "square.on.circle", title: "Фигуры") }
            Button { showFloatingTools.toggle() } label: { StudioSideIcon(icon: "rectangle.on.rectangle", title: "Палитра") }
            Button { arrangingDecor = false; panel = .stickers } label: { StudioSideIcon(icon: "sparkles.rectangle.stack", title: "Стикеры") }
            Button { arrangingDecor = false; textOnSticker = nil; addingText = true } label: { StudioSideIcon(icon: "textformat", title: "Шрифты") }
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                StudioSideIcon(icon: "photo", title: "Фото")
            }
            Button { panel = .myMaterials } label: {
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

    private var quickToolStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { arrangingDecor = false } label: {
                    Label("Писать", systemImage: "pencil.tip")
                        .foregroundStyle(arrangingDecor ? AppPalette.midnight : .white)
                        .padding(.horizontal, 15).padding(.vertical, 9)
                        .background(arrangingDecor ? Color(hex: 0xF0E4E0) : AppPalette.rose, in: Capsule())
                }
                Button { arrangingDecor = true } label: {
                    Label("Двигать", systemImage: "hand.draw")
                        .foregroundStyle(arrangingDecor ? .white : AppPalette.midnight)
                        .padding(.horizontal, 15).padding(.vertical, 9)
                        .background(arrangingDecor ? AppPalette.rose : Color(hex: 0xF0E4E0), in: Capsule())
                }
                Rectangle().fill(Color(hex: 0xD8CFC9)).frame(width: 1, height: 25)
                ForEach(InkChoice.allCases) { kind in
                    Button { ink = kind; arrangingDecor = false } label: {
                        HStack(spacing: 5) {
                            Image(systemName: kind.symbol)
                            Text(kind.rawValue)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ink == kind && !arrangingDecor ? AppPalette.rose : AppPalette.midnight)
                        .padding(.horizontal, 8).padding(.vertical, 8)
                    }.buttonStyle(.plain)
                }
                HStack(spacing: 4) {
                    Image(systemName: "circle.lefthalf.filled")
                    Slider(value: $strokeOpacity, in: 0.15...1)
                        .frame(width: 65).tint(AppPalette.rose)
                }.font(.system(size: 11))
                Menu {
                    ForEach([("Goldstar", "Звёзды"), ("Flower", "Цветы"),
                             ("Daisies", "Ромашки"), ("Leaf", "Листья"),
                             ("SatinBow", "Бантики"), ("Mega_0101", "Зимние мотивы")], id: \.0) { option in
                        Button(option.1) { decorativeSticker = option.0; ink = .decorative; arrangingDecor = false }
                    }
                } label: {
                    Label("Кисть-декор", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                }
                Menu {
                    Button("♡ Сохранить текущую ручку") { saveFavoritePen() }
                    ForEach(favoritePens) { favorite in
                        Button(favorite.title) {
                            if let value = InkChoice.allCases.first(where: { $0.rawValue == favorite.tool }) {
                                ink = value
                            }
                            penColor = Color(hex: favorite.color)
                            strokeWidth = favorite.width
                            arrangingDecor = false
                        }
                    }
                } label: { Label("Любимые ручки", systemImage: "heart") }
                Button { panel = .inkColors } label: {
                    Image(systemName: "paintpalette").font(.system(size: 15))
                    Circle().fill(penColor).frame(width: 14, height: 14)
                }
                Button { panel = .layers } label: { Image(systemName: "square.3.layers.3d") }
                Button { panel = .shapes } label: { Image(systemName: "square.on.circle") }
                Button { panel = .stickers } label: { Image(systemName: "sparkles.rectangle.stack") }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppPalette.midnight)
            .padding(.horizontal, 19).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(Color(hex: 0xFFF9F5).opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xE3DAD2)).frame(height: 1) }
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
            Button { showFilmstrip.toggle() } label: {
                Image(systemName: showFilmstrip ? "rectangle.bottomthird.inset.filled" : "rectangle.bottomthird.inset")
                    .font(.system(size: 17)).frame(width: 35, height: 35)
            }.accessibilityLabel("Показать или скрыть ленту страниц")
            Button { focusMode = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 17)).frame(width: 35, height: 35)
            }.accessibilityLabel("Письмо без панелей")
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
                Button("Сохранить страницу PNG", systemImage: "photo") { exportPNG() }
                Button("Резервная копия блокнота", systemImage: "externaldrive.badge.timemachine") { exportBackup() }
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
                Menu {
                    Toggle("Только Apple Pencil (защита от ладони)", isOn: $pencilOnly)
                    Toggle("Постоянная толщина ручки и пера", isOn: $constantWidth)
                    Text("Для пальца и обычного стилуса выключите «Только Apple Pencil».")
                } label: {
                    ToolChip(title: pencilOnly ? "Apple Pencil" : "Палец / стилус",
                             symbol: "hand.raised", selected: pencilOnly)
                }
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
                Button { arrangingDecor = false; textOnSticker = nil; addingText = true } label: {
                    ToolChip(title: "Текст и шрифты", symbol: "textformat", selected: false)
                }.buttonStyle(.plain)
                Button { arrangingDecor = false; panel = .stickers } label: {
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
        guard let book = library.notebook(bookID) else { return }
        do { exportItem = SharedDocument(url: try PDFNotebookExporter.export(book: book, store: library)) }
        catch { importError = error.localizedDescription }
    }
    private func exportPNG() {
        guard let book = library.notebook(bookID), let page = safePage(book) else { return }
        do { exportItem = SharedDocument(url: try PDFNotebookExporter.exportPNG(page: page, store: library)) }
        catch { importError = error.localizedDescription }
    }

    private func exportBackup() {
        if let url = library.exportNotebookBackup(bookID) {
            exportItem = SharedDocument(url: url)
        } else {
            importError = "Не удалось подготовить резервную копию."
        }
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
    let strokeOpacity: Double
    let pencilOnly: Bool
    let constantWidth: Bool
    let pageNumber: Int
    let arrangingDecor: Bool
    let decorativeSticker: String
    @State private var lastDecoPoint: CGPoint?
    @State private var decoGroup = UUID()
    let editText: (PageItem) -> Void
    let editPhoto: (PageItem) -> Void
    let typeOnSticker: (PageItem) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground(style: page.paper, customHex: page.customPaperHex,
                            decorationOpacity: page.decorationOpacity ?? 1)
                .allowsHitTesting(false)
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
                if !item.hidden {
                    DraggablePageItem(item: item, pageID: page.id, bookID: bookID,
                                      library: library, width: width, height: height,
                                      editText: editText, editPhoto: editPhoto,
                                      typeOnSticker: typeOnSticker)
                    .position(x: width * item.x, y: height * item.y)
                    .allowsHitTesting(arrangingDecor)
                }
            }
            // Слой PencilKit теперь НАД декором: рукописные слова видны на стикерах.
            PenCanvas(pageID: page.id, library: library, ink: ink,
                      color: UIColor(penColor).withAlphaComponent(CGFloat(strokeOpacity)),
                      strokeWidth: CGFloat(strokeWidth),
                      isEnabled: !arrangingDecor && ink != .decorative,
                      revision: library.inkRevision,
                      pencilOnly: pencilOnly,
                      constantWidth: constantWidth,
                      canvasSize: CGSize(width: width, height: height))
                .allowsHitTesting(!arrangingDecor && ink != .decorative)
            if ink == .decorative && !arrangingDecor {
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let spot = value.location
                            guard spot.x >= 0, spot.x <= width, spot.y >= 0, spot.y <= height else { return }
                            if let previous = lastDecoPoint {
                                let distance = hypot(spot.x - previous.x, spot.y - previous.y)
                                guard distance > 34 else { return }
                            }
                            lastDecoPoint = spot
                            library.addItem(book: bookID, page: page.id,
                                item: PageItem(kind: .sticker, value: decorativeSticker,
                                    x: Double(spot.x / width), y: Double(spot.y / height),
                                    scale: 0.38, groupID: decoGroup))
                        }
                        .onEnded { _ in lastDecoPoint = nil; decoGroup = UUID() })
            }
            VStack {
                HStack {
                    if page.backgroundFile == nil && !page.paper.hasPrefix("Studio6_") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("THE JOURNAL")
                            .font(.system(size: 10, weight: .medium)).tracking(2.6)
                        Rectangle().fill(AppPalette.rose.opacity(0.42)).frame(width: 35, height: 1)
                    }
                    .foregroundStyle(AppPalette.rose.opacity(0.63))
                    }
                    Spacer()
                    if page.backgroundFile == nil && !page.paper.hasPrefix("Studio6_") {
                    Text("PRIVATE NOTES").font(.system(size: 8, weight: .medium))
                        .tracking(2).foregroundStyle(AppPalette.muted.opacity(0.65))
                    }
                }
                Spacer()
                HStack {
                    if page.backgroundFile == nil && !page.paper.hasPrefix("Studio6_") { Text("little moments, beautifully kept")
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
    let editPhoto: (PageItem) -> Void
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
            .opacity(item.opacity)
            .scaleEffect(x: item.flipped ? -1 : 1, y: 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { if !item.locked { drag = $0.translation } }
                    .onEnded { value in
                        if !item.locked {
                            library.moveItem(book: bookID, page: pageID, item: item.id,
                                             x: item.x + value.translation.width / width,
                                             y: item.y + value.translation.height / height)
                        }
                        drag = .zero
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { if !item.locked { pinch = $0 } }
                    .onEnded { value in
                        if !item.locked {
                            library.resizeItem(book: bookID, page: pageID, item: item.id,
                                               scale: item.scale * Double(value), angle: item.angle)
                        }
                        pinch = 1
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { if !item.locked { twist = $0 } }
                    .onEnded { value in
                        if !item.locked {
                            library.resizeItem(book: bookID, page: pageID, item: item.id,
                                               scale: item.scale, angle: item.angle + value.degrees)
                        }
                        twist = .zero
                    }
            )
            .onTapGesture(count: 2) {
                if item.kind == .text { editText(item) }
                else if item.kind != .shape { typeOnSticker(item) }
            }
            .contextMenu {
                if item.kind == .photo || item.kind == .customSticker {
                    Button("Фильтры, обрезка, коррекция", systemImage: "camera.filters") { editPhoto(item) }
                }
                if item.kind == .text {
                    Button("Изменить текст и шрифт", systemImage: "character.cursor.ibeam") { editText(item) }
                } else if item.kind != .shape {
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
                if item.groupID != nil {
                    Button("Разгруппировать композицию", systemImage: "rectangle.3.group") {
                        library.ungroupItem(book: bookID, page: pageID, item: item.id)
                    }
                }
                Button(item.locked ? "Разблокировать" : "Закрепить на странице", systemImage: item.locked ? "lock.open" : "lock") {
                    library.toggleItemLock(book: bookID, page: pageID, item: item.id)
                }
                Button("Отразить по горизонтали", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    library.toggleItemFlip(book: bookID, page: pageID, item: item.id)
                }
                Menu("Прозрачность", systemImage: "circle.lefthalf.filled") {
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { alpha in
                        Button("\(Int(alpha * 100))%") {
                            library.setItemOpacity(book: bookID, page: pageID, item: item.id, opacity: alpha)
                        }
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

    private var itemContent: some View {
        PageObjectContent(item: item, library: library, width: width, height: height)
    }
}

struct PageObjectContent: View {
    let item: PageItem
    let library: NotebookLibrary
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var body: some View {
        switch item.kind {
        case .sticker:
            Image(uiImage: StudioImageStore.full(item.value) ?? UIImage())
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
        case .shape:
            StudioShapeView(shape: item.value, color: Color(hex: item.textStyle?.colorHex ?? 0xA66D79))
                .frame(width: width * 0.24, height: width * 0.22)
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
    var decorationOpacity: Double = 1

    var body: some View {
        Canvas { ctx, size in
            let preset = PaperCatalog.find(style)
            if let art = Studio6Catalog.art(for: style) {
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFFF9EF)))
                ctx.opacity = decorationOpacity
                ctx.draw(Image(art), in: CGRect(origin: .zero, size: size))
                ctx.opacity = 1
                StudioTemplateRenderer.draw(preset?.pattern.replacingOccurrences(of: "s6:", with: "") ?? "blank", context: &ctx, size: size)
                return
            }
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
        .overlay {
            if style.hasPrefix("Paper_") {
                Image(style)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .opacity(decorationOpacity)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(PaperCatalog.find(style)?.title ?? "Бумага")
    }
}

struct StickerPalette: View {
    let add: (String) -> Void
    @State private var category = "Все"
    @State private var search = ""
    @State private var batch = 0
    @State private var preview: StickerEntry?
    private let batchSize = 48
    @AppStorage("qpFavoriteStickers") private var favoriteIDs = ""
    @AppStorage("qpRecentStickers") private var recentIDs = ""
    private var favoriteSet: Set<String> { Set(favoriteIDs.split(separator: ",").map(String.init)) }
    private var recentSet: Set<String> { Set(recentIDs.split(separator: ",").map(String.init)) }
    private func toggleFavorite(_ id: String) {
        var updated = favoriteSet
        if updated.contains(id) { updated.remove(id) } else { updated.insert(id) }
        favoriteIDs = updated.sorted().joined(separator: ",")
    }
    private func insertSticker(_ id: String) {
        let previous = recentIDs.split(separator: ",").map(String.init).filter { $0 != id }
        recentIDs = ([id] + Array(previous.prefix(39))).joined(separator: ",")
        add(id)
    }
    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 12)]
    private var filtered: [StickerEntry] {
        let favorites = favoriteSet
        let recent = recentIDs.split(separator: ",").map(String.init)
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let entries = category == "Недавние"
            ? recent.compactMap { id in StickerCatalog.all.first { $0.id == id } }
            : StickerCatalog.all
        return entries.filter { entry in
            (category == "Все" || category == "Недавние" || entry.category == category ||
             (category == "Избранное" && favorites.contains(entry.id))) &&
            (query.isEmpty || entry.title.localizedCaseInsensitiveContains(query) || entry.category.localizedCaseInsensitiveContains(query))
        }
    }
    private var visibleEntries: [StickerEntry] {
        Array(filtered.dropFirst(batch * batchSize).prefix(batchSize))
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
                            ForEach(["Все", "Избранное", "Недавние"] + StickerCatalog.categories.enumerated().filter { index, value in value != "Все" && !StickerCatalog.categories.prefix(index).contains(value) }.map(\.element), id: \.self) { section in
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
                            ForEach(visibleEntries) { sticker in
                                VStack(spacing: 6) {
                                    Button { insertSticker(sticker.id) } label: {
                                        VStack(spacing: 6) {
                                            Group {
                                                if let components = StudioCompositionCatalog.components(for: sticker.id) {
                                                    ZStack {
                                                        StickerThumbnail(id: components.0)
                                                            .frame(width: 106, height: 100).offset(x: -10, y: -7)
                                                        StickerThumbnail(id: components.1)
                                                            .frame(width: 74, height: 74).offset(x: 19, y: 14)
                                                    }
                                                } else {
                                                    StickerThumbnail(id: sticker.id)
                                                }
                                            }
                                            .frame(height: 100)
                                            .padding(.horizontal, 6)
                                            Text(sticker.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(AppPalette.midnight)
                                                .frame(height: 30)
                                        }.frame(maxWidth: .infinity)
                                    }.buttonStyle(.plain)
                                    Button("Рассмотреть") { preview = sticker }
                                        .font(.system(size: 11))
                                    Button { toggleFavorite(sticker.id) } label: {
                                        Label(favoriteSet.contains(sticker.id) ? "В избранном" : "В избранное",
                                              systemImage: favoriteSet.contains(sticker.id) ? "heart.fill" : "heart")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppPalette.rose)
                                    }.buttonStyle(.plain)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xE8DED4)))
                            }
                        }
                    }
                    HStack {
                        Button("Назад") { batch = max(0, batch - 1) }.disabled(batch == 0)
                        Spacer()
                        Text("\(batch + 1) / \(max(1, (filtered.count + batchSize - 1) / batchSize))")
                        Spacer()
                        Button("Далее") { batch += 1 }
                            .disabled((batch + 1) * batchSize >= filtered.count)
                    }.buttonStyle(.bordered)
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
        .onChange(of: category) { _, _ in batch = 0 }
        .onChange(of: search) { _, _ in batch = 0 }
        .sheet(item: $preview) { entry in
            StickerPreview(entry: entry) { insertSticker(entry.id) }
        }
        .presentationDetents([.medium, .large])
    }
}

struct PaperPalette: View {
    let current: String
    let customHex: UInt32?
    let select: (String) -> Void
    let chooseCustom: (UInt32) -> Void
    let setIntensity: (Double) -> Void
    @State private var intensity: Double
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

    init(current: String, customHex: UInt32?, decorationOpacity: Double = 1,
         select: @escaping (String) -> Void,
         chooseCustom: @escaping (UInt32) -> Void,
         setIntensity: @escaping (Double) -> Void = { _ in }) {
        self.current = current
        self.customHex = customHex
        self.select = select
        self.chooseCustom = chooseCustom
        self.setIntensity = setIntensity
        _intensity = State(initialValue: decorationOpacity)
        _customColor = State(initialValue: Color(hex: customHex ?? 0xFAE5EC))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("\(PaperCatalog.all.count) видов бумаги и шаблонов")
                            .font(.system(size: 21, design: .serif))
                        Spacer()
                        Text("Бесплатно · офлайн")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(AppPalette.rose)
                    }
                    TextField("Найти бумагу или шаблон...", text: $search)
                        .textFieldStyle(.roundedBorder)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(PaperCatalog.categories.enumerated().filter { index, value in !PaperCatalog.categories.prefix(index).contains(value) }.map(\.element), id: \.self) { cat in
                                Button { category = cat } label: {
                                    Text(cat).font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 13).padding(.vertical, 10)
                                        .foregroundStyle(category == cat ? Color.white : AppPalette.midnight)
                                        .background(category == cat ? AppPalette.rose : Color(hex: 0xEEE5DE), in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Насыщенность сказочного оформления")
                            .font(.system(size: 13, weight: .semibold))
                        Picker("Декор", selection: $intensity) {
                            Text("Минимально").tag(0.35)
                            Text("Нежно").tag(0.7)
                            Text("Сказочно").tag(1.0)
                        }.pickerStyle(.segmented)
                            .onChange(of: intensity) { _, value in setIntensity(value) }
                        Text("Картинки только по краям и в уголках. Середина свободна для письма.")
                            .font(.system(size: 10)).foregroundStyle(AppPalette.muted)
                    }
                    .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 13))
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

// Explicit layer inspector. It never blocks drawing when dismissed.
struct StudioLayerManager: View {
    let page: NotebookPage
    let library: NotebookLibrary
    let bookID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var newCompositionName = "Моя композиция"
    @State private var showingSave = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    Text("Управляй украшениями, текстом и фотографиями. При закрытии панели рисование остаётся доступным.")
                        .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    if !page.items.isEmpty {
                        Button { showingSave = true } label: {
                            Label("Сохранить оформление как композицию", systemImage: "square.on.square.dashed")
                                .frame(maxWidth: .infinity).padding(12)
                        }.buttonStyle(.borderedProminent).tint(AppPalette.rose)
                    }
                    if page.items.isEmpty {
                        ContentUnavailableView("Слои пока пусты", systemImage: "square.3.layers.3d", description: Text("Добавь стикер, текст или фотографию."))
                    } else {
                        ForEach(Array(page.items.reversed())) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.kind == .text ? "textformat" : item.kind == .photo ? "photo" : "sparkles")
                                    .frame(width: 24)
                                Text(item.kind == .text ? String(item.value.prefix(22)) : item.kind == .photo ? "Фотография" : "Украшение")
                                    .font(.system(size: 12)).lineLimit(1)
                                Spacer()
                                Button { library.sendBackward(book: bookID, page: page.id, item: item.id) } label: { Image(systemName: "arrow.down") }
                                Button { library.bringForward(book: bookID, page: page.id, item: item.id) } label: { Image(systemName: "arrow.up") }
                                Button { library.toggleItemLock(book: bookID, page: page.id, item: item.id) } label: {
                                    Image(systemName: item.locked ? "lock.fill" : "lock.open")
                                }
                                Button { library.toggleItemVisibility(book: bookID, page: page.id, item: item.id) } label: {
                                    Image(systemName: item.hidden ? "eye.slash" : "eye")
                                }
                                Button(role: .destructive) { library.deleteItem(book: bookID, page: page.id, item: item.id) } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .padding(13)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                            .buttonStyle(.borderless)
                        }
                    }
                }.padding(18)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Слои страницы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .alert("Сохранить композицию", isPresented: $showingSave) {
                TextField("Название", text: $newCompositionName)
                Button("Сохранить") {
                    library.saveComposition(name: newCompositionName,
                        items: page.items.filter { !$0.hidden })
                }
                Button("Отмена", role: .cancel) { }
            } message: { Text("Все видимые украшения и надписи останутся редактируемыми.") }
        }.presentationDetents([.medium, .large])
    }
}

// Editable geometrical figures, no raster stickers or network requests.
struct StudioShapeView: View {
    let shape: String
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            switch shape {
            case "circle":
                Ellipse().stroke(color, lineWidth: 3.5)
            case "rectangle":
                RoundedRectangle(cornerRadius: 7).stroke(color, lineWidth: 3.5)
            case "line":
                Path { p in p.move(to: CGPoint(x: 7, y: h / 2)); p.addLine(to: CGPoint(x: w - 7, y: h / 2)) }
                    .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            case "arrow":
                Image(systemName: "arrow.right").resizable().scaledToFit().foregroundStyle(color)
            default:
                RoundedRectangle(cornerRadius: 7).stroke(color, lineWidth: 3.5)
            }
        }
    }
}

struct ShapePalette: View {
    let insert: (String) -> Void
    private let choices = [("circle", "circle", "Круг"), ("rectangle", "rectangle", "Прямоугольник"),
                           ("line", "line.diagonal", "Линия"), ("arrow", "arrow.right", "Стрелка")]
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
                ForEach(choices.indices, id: \.self) { index in
                    Button { insert(choices[index].0) } label: {
                        VStack(spacing: 10) {
                            Image(systemName: choices[index].1).font(.system(size: 37, weight: .light))
                            Text(choices[index].2).font(.system(size: 13))
                        }
                        .foregroundStyle(AppPalette.rose)
                        .frame(maxWidth: .infinity).padding(20)
                        .background(.white, in: RoundedRectangle(cornerRadius: 15))
                    }.buttonStyle(.plain)
                }
            }
            .padding(22)
            .background(AppPalette.parchment)
            .navigationTitle("Фигуры")
        }.presentationDetents([.medium])
    }
}


private struct SavedPen: Identifiable, Codable {
    var id: String { "\(tool)-\(color)-\(width)" }
    let tool: String
    let color: UInt32
    let width: Double
    var title: String { "\(tool) · #\(String(format: "%06X", color)) · \(Int(width))" }
}


struct MyPNGGallery: View {
    let library: NotebookLibrary
    @Binding var importFromPhotos: PhotosPickerItem?
    @Binding var importFromFiles: Bool
    let add: (String) -> Void
    @AppStorage("qpMyPNGCollection") private var myPNGCollection = ""
    @Environment(\.dismiss) private var dismiss
    private var files: [String] { myPNGCollection.split(separator: "|").map(String.init) }
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Сохраняй собственные стикеры и используй их на любых страницах.")
                        .font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                    PhotosPicker(selection: $importFromPhotos, matching: .images) {
                        Label("Создать стикер из фотографии", systemImage: "plus.viewfinder")
                            .frame(maxWidth: .infinity).padding(12)
                    }.buttonStyle(.borderedProminent).tint(AppPalette.rose)
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { importFromFiles = true }
                    } label: {
                        Label("Открыть PNG из «Файлов»", systemImage: "folder")
                    }.buttonStyle(.bordered)
                    if files.isEmpty {
                        ContentUnavailableView("Пока нет своих стикеров", systemImage: "scissors")
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(files, id: \.self) { filename in
                                if let image = library.photo(named: filename, pixels: 192) {
                                    Button { add(filename) } label: {
                                        Image(uiImage: image).resizable().scaledToFit()
                                            .frame(height: 110).frame(maxWidth: .infinity)
                                            .padding(9)
                                            .background(.white, in: RoundedRectangle(cornerRadius: 13))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }.padding(20)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Мои PNG ♡")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Готово") { dismiss() }
            } }
        }.presentationDetents([.medium, .large])
    }
}


struct MyCompositionsGallery: View {
    let library: NotebookLibrary
    let insert: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("Сохраняй оформление страницы через раздел «Слои» и вставляй снова в любой блокнот.")
                        .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    if library.userCompositions.isEmpty {
                        ContentUnavailableView("Своих композиций пока нет", systemImage: "square.on.square.dashed")
                    } else {
                        ForEach(library.userCompositions) { composition in
                            Button { insert(composition.id) } label: {
                                HStack {
                                    Image(systemName: "square.on.square.dashed")
                                    VStack(alignment: .leading) {
                                        Text(composition.title)
                                        Text("\(composition.items.count) редактируемых элементов")
                                            .font(.system(size: 10)).foregroundStyle(AppPalette.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                }
                                .foregroundStyle(AppPalette.midnight)
                                .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Мои композиции")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

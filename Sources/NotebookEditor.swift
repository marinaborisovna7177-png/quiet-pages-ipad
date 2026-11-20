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
    case pen = "Ручка", pencil = "Карандаш", marker = "Маркер", eraser = "Ластик"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .pencil: "pencil"
        case .marker: "highlighter"
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
                    library.addItem(book: bookID, page: page.id,
                                    item: PageItem(kind: .sticker, value: stickerName))
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
                TextStudioSheet(existing: nil) { value, style in
                    var item = PageItem(kind: .text, value: value, y: 0.30)
                    item.textStyle = style
                    library.addItem(book: bookID, page: page.id, item: item)
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
                                                  editText: { item in editingTextItem = item })
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
            Button { panel = .stickers } label: { StudioSideIcon(icon: "sparkles.rectangle.stack", title: "Стикеры") }
            Button { addingText = true } label: { StudioSideIcon(icon: "textformat", title: "Шрифты") }
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
                Text("РИСОВАНИЕ")
                    .font(.system(size: 9, weight: .semibold)).tracking(1.6)
                    .foregroundStyle(AppPalette.muted).padding(.trailing, 4)
                ForEach(InkChoice.allCases) { t in
                    Button { ink = t } label: {
                        ToolChip(title: t.rawValue, symbol: t.symbol, selected: ink == t)
                    }.buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    Image(systemName: "line.diagonal").font(.system(size: 11))
                    Slider(value: $strokeWidth, in: 1...14, step: 1).tint(AppPalette.rose).frame(width: 90)
                }.foregroundStyle(AppPalette.muted).padding(.horizontal, 8)
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
                Button { addingText = true } label: {
                    ToolChip(title: "Текст и шрифты", symbol: "textformat", selected: false)
                }.buttonStyle(.plain)
                Button { panel = .stickers } label: {
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
    let editText: (PageItem) -> Void

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
            PenCanvas(pageID: page.id, library: library, ink: ink,
                      color: UIColor(penColor), strokeWidth: CGFloat(strokeWidth))
            ForEach(page.items) { item in
                DraggablePageItem(item: item, pageID: page.id, bookID: bookID,
                                  library: library, width: width, height: height, editText: editText)
                    .position(x: width * item.x, y: height * item.y)
            }
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
            }
            .contextMenu {
                if item.kind == .text {
                    Button("Изменить текст и шрифт", systemImage: "character.cursor.ibeam") { editText(item) }
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
                .resizable().scaledToFit().frame(width: width * 0.22, height: width * 0.22)
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
                .frame(width: width * 0.66)
                .padding(style.backgroundHex == nil ? 2 : 11)
                .background {
                    if let hex = style.backgroundHex {
                        RoundedRectangle(cornerRadius: 8).fill(Color(hex: hex).opacity(0.90))
                    }
                }
        }
    }
}

struct PaperBackground: View {
    let style: String
    var customHex: UInt32? = nil
    private var paperColor: Color {
        if let customHex { return Color(hex: customHex) }
        switch style {
        case "Blush", "Rose Lines": Color(hex: 0xFFF0F0)
        case "Cream Grid", "Vintage", "Daily Plan", "Checklist", "Cornell": Color(hex: 0xFFF6E9)
        case "Lilac": Color(hex: 0xF2EFF9)
        case "Sage": Color(hex: 0xF1F4EC)
        case "Dark": Color(hex: 0x2E3441)
        case "Peach": Color(hex: 0xFFE4D8)
        case "Lemon": Color(hex: 0xFFF7C9)
        case "Sea Glass": Color(hex: 0xD9EEE7)
        case "Powder Blue": Color(hex: 0xE3F0FD)
        case "Ballet Pink": Color(hex: 0xFCE1EA)
        case "Dusty Rose": Color(hex: 0xEBC9CF)
        case "Ivory Gold": Color(hex: 0xF8EBD8)
        case "Bluebell": Color(hex: 0xE3E5F9)
        case "Caramel": Color(hex: 0xEEDDCB)
        case "Mauve": Color(hex: 0xE6D7E6)
        case "Aqua": Color(hex: 0xD6F4F0)
        case "Almond": Color(hex: 0xF4E3CE)
        default: Color(hex: 0xFFFDF7)
        }
    }
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paperColor))
            if style == "Lines" || style == "Grid" || style == "Rose Lines" || style == "Cream Grid" || style == "Cornell" {
                let gap: CGFloat = 27
                for y in stride(from: 55.0, through: size.height, by: gap) {
                    var p = Path(); p.move(to: CGPoint(x: 20, y: y)); p.addLine(to: CGPoint(x: size.width-20, y: y))
                    context.stroke(p, with: .color(Color(hex: 0xBCC4D1).opacity(0.5)), lineWidth: 0.55)
                }
                if style == "Grid" || style == "Cream Grid" {
                    for x in stride(from: 20.0, through: size.width-20, by: gap) {
                        var p = Path(); p.move(to: CGPoint(x: x, y: 20)); p.addLine(to: CGPoint(x: x, y: size.height-20))
                        context.stroke(p, with: .color(Color(hex: 0xBCC4D1).opacity(0.32)), lineWidth: 0.5)
                    }
                }
            } else if style == "Daily Plan" || style == "Checklist" {
                let ink = Color(hex: 0xC7B3AB).opacity(0.52)
                for n in 0..<14 {
                    let y: CGFloat = 125 + CGFloat(n) * 39
                    var row = Path()
                    row.move(to: CGPoint(x: 65, y: y))
                    row.addLine(to: CGPoint(x: size.width - 45, y: y))
                    context.stroke(row, with: .color(ink), lineWidth: 0.8)
                    if style == "Checklist" {
                        let box = Path(roundedRect: CGRect(x: 36, y: y - 14, width: 16, height: 16), cornerRadius: 4)
                        context.stroke(box, with: .color(ink), lineWidth: 1.2)
                    }
                }
            } else if style == "Dots" {
                for y in stride(from: 24.0, through: size.height-18, by: 24) {
                    for x in stride(from: 24.0, through: size.width-18, by: 24) {
                        let point = Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                        context.fill(point, with: .color(Color(hex: 0xB4A5B0).opacity(0.5)))
                    }
                }
            }
            if style == "Cornell" {
                var column = Path()
                column.move(to: CGPoint(x: size.width * 0.30, y: 55))
                column.addLine(to: CGPoint(x: size.width * 0.30, y: size.height - 160))
                column.move(to: CGPoint(x: 22, y: size.height - 160))
                column.addLine(to: CGPoint(x: size.width - 22, y: size.height - 160))
                context.stroke(column, with: .color(Color(hex: 0xBCA6A3).opacity(0.7)), lineWidth: 1)
            }
            if style == "Vintage" {
                let outer = Path(roundedRect: CGRect(x: 24, y: 27, width: size.width - 48,
                                                     height: size.height - 54), cornerRadius: 7)
                let inner = Path(roundedRect: CGRect(x: 35, y: 38, width: size.width - 70,
                                                     height: size.height - 76), cornerRadius: 5)
                context.stroke(outer, with: .color(Color(hex: 0xBE9C80).opacity(0.45)), lineWidth: 1.5)
                context.stroke(inner, with: .color(Color(hex: 0xBE9C80).opacity(0.3)), lineWidth: 0.7)
            }
        }
    }
}

struct StickerPalette: View {
    let add: (String) -> Void
    private let columns = [GridItem(.adaptive(minimum: 95), spacing: 12)]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Коллекция украшений")
                            .font(.system(size: 25, design: .serif)).foregroundStyle(AppPalette.midnight)
                        Text("Всё бесплатно · Перемещай, вращай и масштабируй на странице")
                            .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    }
                    LazyVGrid(columns: columns, spacing: 13) {
                        ForEach(AppPalette.stickers.indices, id: \.self) { index in
                            let sticker = AppPalette.stickers[index]
                            Button { add(sticker.0) } label: {
                                VStack(spacing: 5) {
                                    Image("Sticker_\(sticker.0)").resizable().scaledToFit()
                                        .frame(height: 105)
                                    Text(sticker.1).font(.system(size: 12)).foregroundStyle(AppPalette.midnight)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xE8DED4), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
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
    @State private var customColor: Color = Color(hex: 0xFAE5EC)
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 15)]

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
                VStack(alignment: .leading, spacing: 18) {
                    Text("Свой оттенок бумаги")
                        .font(.system(size: 21, design: .serif))
                    HStack(spacing: 12) {
                        ColorPicker("Выбрать любой цвет", selection: $customColor, supportsOpacity: false)
                        Button("Применить") { chooseCustom(customColor.hexValue) }
                            .buttonStyle(.borderedProminent).tint(AppPalette.rose)
                    }
                    .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 15))
                    Text("Готовые страницы").font(.system(size: 21, design: .serif))
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AppPalette.papers, id: \.self) { paper in
                            Button { select(paper) } label: {
                                VStack(spacing: 8) {
                                    PaperBackground(style: paper)
                                        .aspectRatio(0.75, contentMode: .fit)
                                        .overlay(RoundedRectangle(cornerRadius: 7)
                                            .stroke(current == paper ? AppPalette.rose : Color(hex: 0xD5C8C3), lineWidth: current == paper ? 3 : 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                    Text(paper).font(.system(size: 13, design: .serif)).foregroundStyle(AppPalette.midnight)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(24)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Бумага и цвета")
        }.presentationDetents([.medium, .large])
    }
}

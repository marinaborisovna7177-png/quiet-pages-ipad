import SwiftUI
import PencilKit
import PhotosUI

private enum EditorPanel: String, Identifiable {
    case stickers, paper, text
    var id: String { rawValue }
}

enum InkChoice: String, CaseIterable, Identifiable {
    case pen = "Ручка", marker = "Маркер", eraser = "Ластик"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
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
                case .paper: PaperPalette(current: page.paper) { paper in
                    library.setPaper(book: bookID, page: page.id, style: paper)
                    self.panel = nil
                }
                case .text: AddTextSheet { text in
                    library.addItem(book: bookID, page: page.id,
                                    item: PageItem(kind: .text, value: text, y: 0.27))
                    self.panel = nil
                }
                }
            }
        }
        .sheet(item: $exportItem) { item in ShareSheet(url: item.url) }
        .alert("Удалить страницу?", isPresented: $showDeletePage) {
            Button("Удалить", role: .destructive) {
                if let book = library.notebook(bookID), let page = safePage(book), book.pages.count > 1 {
                    library.deletePage(book: bookID, page: page.id)
                    currentPage = min(currentPage, book.pages.count - 2)
                }
            }
            Button("Отмена", role: .cancel) { }
        } message: { Text("Рисунки и украшения на этой странице будут удалены.") }
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

    @ViewBuilder
    private func editor(_ book: Notebook) -> some View {
        if let page = safePage(book) {
            GeometryReader { geometry in
                let width = min(geometry.size.width * 0.83, (geometry.size.height - 145) * 0.73, 720)
                let height = width / 0.73
                ZStack {
                    LinearGradient(colors: [Color(hex: 0xE9E1DC), Color(hex: 0xF5EDE7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea()
                    VStack(spacing: 0) {
                        topBar(book)
                        HStack(spacing: 8) {
                            Button { turnPage(-1) } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 21, weight: .light))
                                    .frame(width: 38, height: 74)
                            }
                            .disabled(currentPage == 0)
                            .opacity(currentPage == 0 ? 0.18 : 1)
                            Spacer(minLength: 0)
                            JournalPageCanvas(page: page, width: width, height: height,
                                              library: library, bookID: bookID,
                                              ink: ink, penColor: penColor,
                                              pageNumber: currentPage + 1)
                                .id(page.id)
                                .shadow(color: Color(hex: 0x5D4750).opacity(0.22), radius: 18, x: 8, y: 17)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                        removal: .move(edge: .leading).combined(with: .opacity)))
                            Spacer(minLength: 0)
                            Button { turnPage(1) } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 21, weight: .light))
                                    .frame(width: 38, height: 74)
                            }
                            .disabled(currentPage >= book.pages.count - 1)
                            .opacity(currentPage >= book.pages.count - 1 ? 0.18 : 1)
                        }
                        .foregroundStyle(AppPalette.midnight)
                        .padding(.horizontal, 14)
                        .frame(maxHeight: .infinity)
                        toolBar(book)
                    }
                }
            }
        }
    }

    private func topBar(_ book: Notebook) -> some View {
        HStack(spacing: 15) {
            Button { dismiss() } label: { Label("Библиотека", systemImage: "chevron.backward") }
            Spacer()
            VStack(spacing: 3) {
                Text(book.title).font(.system(size: 19, weight: .medium, design: .serif)).lineLimit(1)
                Text("\(currentPage + 1) / \(book.pages.count) · сохранено на iPad")
                    .font(.system(size: 11)).foregroundStyle(AppPalette.muted)
            }
            Spacer()
            Menu {
                Button("Добавить страницу", systemImage: "plus.rectangle.on.rectangle") { addPage() }
                Button("Удалить страницу", systemImage: "trash", role: .destructive) { showDeletePage = true }
                    .disabled(book.pages.count == 1)
                Button("Экспортировать в PDF", systemImage: "square.and.arrow.up") { exportPDF() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 23, weight: .light))
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(AppPalette.midnight)
        .padding(.horizontal, 27)
        .padding(.vertical, 15)
        .background(Color(hex: 0xFBF7F2).opacity(0.75))
    }

    private func toolBar(_ book: Notebook) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(InkChoice.allCases) { t in
                    Button { ink = t } label: { ToolChip(title: t.rawValue, symbol: t.symbol, selected: ink == t) }
                }
                ColorPicker("Цвет", selection: $penColor, supportsOpacity: false)
                    .labelsHidden().frame(width: 38).padding(.trailing, 4)
                Rectangle().fill(Color(hex: 0xDDD0C9)).frame(width: 1, height: 25)
                Button { panel = .stickers } label: { ToolChip(title: "Стикеры", symbol: "sparkles", selected: false) }
                Button { panel = .text } label: { ToolChip(title: "Текст", symbol: "textformat", selected: false) }
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    ToolChip(title: "Фото", symbol: "photo", selected: false)
                }
                Button { panel = .paper } label: { ToolChip(title: "Бумага", symbol: "square.grid.3x3", selected: false) }
                Rectangle().fill(Color(hex: 0xDDD0C9)).frame(width: 1, height: 25)
                Button { addPage() } label: { ToolChip(title: "Страница +", symbol: "plus", selected: false) }
                Button { exportPDF() } label: { ToolChip(title: "PDF", symbol: "square.and.arrow.up", selected: false) }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xD3C3C1)).frame(height: 1) }
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

    private func exportPDF() {
        guard let book = library.notebook(bookID),
              let url = try? PDFNotebookExporter.export(book: book, store: library) else { return }
        exportItem = SharedDocument(url: url)
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
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12).padding(.vertical, 10)
        .foregroundStyle(selected ? Color.white : AppPalette.midnight)
        .background(selected ? AppPalette.midnight : Color.white.opacity(0.82), in: Capsule())
        .overlay(Capsule().stroke(selected ? Color.clear : Color(hex: 0xD9CBC6), lineWidth: 1))
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
    let pageNumber: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            PaperBackground(style: page.paper)
            PenCanvas(pageID: page.id, library: library, ink: ink, color: UIColor(penColor))
            ForEach(page.items) { item in
                DraggablePageItem(item: item, pageID: page.id, bookID: bookID,
                                  library: library, width: width, height: height)
                    .position(x: width * item.x, y: height * item.y)
            }
            VStack {
                HStack {
                    Text("dear diary,").font(.system(size: 20, design: .serif)).italic()
                        .foregroundStyle(AppPalette.rose.opacity(0.65))
                    Spacer()
                    Image(systemName: "sparkle").font(.system(size: 18, weight: .ultraLight))
                        .foregroundStyle(AppPalette.rose.opacity(0.65))
                }
                Spacer()
                HStack {
                    Text("quiet pages · keep this moment")
                        .font(.system(size: 10, design: .serif)).italic()
                    Spacer()
                    Text(String(format: "%02d", pageNumber))
                        .font(.system(size: 11, design: .serif))
                }
                .foregroundStyle(AppPalette.muted.opacity(0.7))
            }
            .padding(.horizontal, 25).padding(.vertical, 22)
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
    @State private var drag: CGSize = .zero

    var body: some View {
        itemContent
            .scaleEffect(item.scale)
            .rotationEffect(.degrees(item.angle))
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
            .contextMenu {
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
        case .photo:
            if let image = library.photo(named: item.value) {
                Image(uiImage: image)
                    .resizable().scaledToFill().frame(width: width * 0.34, height: width * 0.33)
                    .clipped().padding(7).background(.white)
                    .shadow(color: .black.opacity(0.17), radius: 4, y: 3)
            }
        case .text:
            Text(item.value)
                .font(.system(size: max(15, width * 0.037), design: .serif))
                .foregroundStyle(AppPalette.midnight)
                .multilineTextAlignment(.center)
                .frame(maxWidth: width * 0.63)
                .padding(8)
                .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

struct PaperBackground: View {
    let style: String
    private var paperColor: Color {
        switch style {
        case "Blush": Color(hex: 0xFFF0F0)
        case "Lilac": Color(hex: 0xF2EFF9)
        case "Sage": Color(hex: 0xF1F4EC)
        case "Dark": Color(hex: 0x2E3441)
        default: Color(hex: 0xFFFDF7)
        }
    }
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paperColor))
            if style == "Lines" || style == "Grid" {
                let gap: CGFloat = 27
                for y in stride(from: 55.0, through: size.height, by: gap) {
                    var p = Path(); p.move(to: CGPoint(x: 20, y: y)); p.addLine(to: CGPoint(x: size.width-20, y: y))
                    context.stroke(p, with: .color(Color(hex: 0xBCC4D1).opacity(0.5)), lineWidth: 0.55)
                }
                if style == "Grid" {
                    for x in stride(from: 20.0, through: size.width-20, by: gap) {
                        var p = Path(); p.move(to: CGPoint(x: x, y: 20)); p.addLine(to: CGPoint(x: x, y: size.height-20))
                        context.stroke(p, with: .color(Color(hex: 0xBCC4D1).opacity(0.32)), lineWidth: 0.5)
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
                    Text("Наклейки можно двигать пальцем, а долгим нажатием — удалять")
                        .font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                    LazyVGrid(columns: columns, spacing: 13) {
                        ForEach(AppPalette.stickers.indices, id: \.self) { index in
                            let sticker = AppPalette.stickers[index]
                            Button { add(sticker.0) } label: {
                                VStack(spacing: 5) {
                                    Image("Sticker_\(sticker.0)").resizable().scaledToFit()
                                        .frame(height: 79)
                                    Text(sticker.1).font(.system(size: 12)).foregroundStyle(AppPalette.midnight)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white, in: RoundedRectangle(cornerRadius: 15))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(24)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Стикеры · бесплатно")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

struct PaperPalette: View {
    let current: String
    let select: (String) -> Void
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 15)]
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AppPalette.papers, id: \.self) { paper in
                        Button { select(paper) } label: {
                            VStack(spacing: 8) {
                                PaperBackground(style: paper)
                                    .aspectRatio(0.75, contentMode: .fit)
                                    .overlay(RoundedRectangle(cornerRadius: 7)
                                        .stroke(current == paper ? AppPalette.rose : Color(hex: 0xD5C8C3), lineWidth: current == paper ? 3 : 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                                Text(paper).font(.system(size: 14, design: .serif)).foregroundStyle(AppPalette.midnight)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(24)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Бумага")
        }.presentationDetents([.medium, .large])
    }
}

struct AddTextSheet: View {
    let add: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var body: some View {
        NavigationStack {
            Form { TextField("Напиши текст для страницы", text: $text, axis: .vertical).lineLimit(3...8) }
                .navigationTitle("Текст на странице")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Добавить") { add(text); dismiss() }.disabled(text.isEmpty)
                    }
                }
        }.presentationDetents([.medium])
    }
}

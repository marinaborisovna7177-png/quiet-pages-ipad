import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255)
    }
}

enum AppPalette {
    static let parchment = Color(hex: 0xF6F2EB)
    static let midnight = Color(hex: 0x302E36)
    static let rose = Color(hex: 0xA66D79)
    static let muted = Color(hex: 0x867E7D)
    static let covers = CoverCatalog.all.map(\.id)
    static let papers = PaperCatalog.all.map(\.id)
    static let stickers: [(String,String)] = StickerCatalog.all.map { ($0.id, $0.title) }
}

// Atelier-style offline library: tactile covers, spacious editorial layout.
struct LibraryView: View {
    @EnvironmentObject private var library: NotebookLibrary
    @State private var showingCreator = false
    @State private var showingBackupImporter = false
    @State private var backupError: String?
    @State private var search = ""
    @State private var activeFolder = "Все"
    @AppStorage("qpLibraryShelfMode") private var shelfMode = true
    @State private var showingFolderCreator = false
    @State private var newFolderName = ""
    @State private var toRename: UUID?
    @State private var newNotebookTitle = ""
    @AppStorage("qpCustomFolders") private var customFolders = "Личное|Творчество|Учёба|Работа|Волшебный мир"
    private var folders: [String] {
        Array(Set(customFolders.split(separator: "|").map(String.init) + library.notebooks.compactMap(\.folder))).sorted()
    }
    @State private var toDelete: UUID?
    @State private var toChangeCover: UUID?
    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 230), spacing: 23)]
    private var filteredNotebooks: [Notebook] {
        library.notebooks.filter { book in
            (search.isEmpty || book.title.localizedCaseInsensitiveContains(search)) &&
            (activeFolder == "Все" || (activeFolder == "Избранное" && book.favorite == true) || book.folder == activeFolder)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppPalette.parchment.ignoresSafeArea()
                Image("StudioDesk").resizable().scaledToFill().ignoresSafeArea().opacity(0.19).allowsHitTesting(false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        HStack(alignment: .center) {
                            HStack(spacing: 11) {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 16, weight: .light)).foregroundStyle(AppPalette.rose)
                                    .frame(width: 36, height: 36)
                                    .background(Color(hex: 0xEBDFD8), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ТИХИЕ СТРАНИЦЫ").font(.system(size: 11, weight: .semibold)).tracking(3.6)
                                    Text("PRIVATE JOURNAL STUDIO").font(.system(size: 8, weight: .medium)).tracking(1.9).foregroundStyle(AppPalette.muted)
                                }
                            }
                            Spacer()
                            Button { showingBackupImporter = true } label: {
                                Label("Восстановить блокнот", systemImage: "square.and.arrow.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(.white.opacity(0.7), in: Capsule())
                            }.buttonStyle(.plain)
                            Text("100% OFFLINE")
                                .font(.system(size: 9, weight: .semibold)).tracking(1.5)
                                .padding(.horizontal, 13).padding(.vertical, 9)
                                .background(.white.opacity(0.6), in: Capsule())
                        }
                        .foregroundStyle(AppPalette.midnight)
                        .padding(.bottom, 10)
                        Rectangle().fill(Color(hex: 0xDCCFC5)).frame(height: 1)
                        HStack(alignment: .bottom, spacing: 20) {
                            VStack(alignment: .leading, spacing: 11) {
                                Text("ТВОЯ ЛИЧНАЯ БИБЛИОТЕКА").font(.system(size: 10, weight: .semibold))
                                    .tracking(2.5).foregroundStyle(AppPalette.rose)
                                Text("Красивые мысли\nживут здесь.")
                                    .font(.system(size: 39, weight: .regular, design: .serif))
                                    .lineSpacing(0).tracking(-0.8)
                                    .foregroundStyle(AppPalette.midnight)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Блокноты, воспоминания, заметки и маленькие истории.")
                                    .font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                            }
                            Spacer(minLength: 0)
                            HStack(spacing: 10) {
                                Button {
                                    library.createNotebook(title: "Быстрая заметка", cover: "Cream", paper: "Ivory", mood: "minimal")
                                } label: {
                                    Label("Быстрая заметка", systemImage: "square.and.pencil")
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 14).padding(.vertical, 15)
                                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
                                }.buttonStyle(.plain)
                                Button { showingCreator = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                                    Text("Новый блокнот").font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, 18).padding(.vertical, 15)
                                .foregroundStyle(.white)
                                .background(AppPalette.midnight, in: RoundedRectangle(cornerRadius: 14))
                                }.buttonStyle(.plain)
                            }
                        }.padding(.vertical, 18)
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(AppPalette.rose)
                            TextField("Найти блокнот...", text: $search)
                                .font(.system(size: 14)).autocorrectionDisabled()
                        }
                        .padding(.horizontal, 18).padding(.vertical, 15)
                        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color(hex: 0xE8DDD3), lineWidth: 1))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(["Все", "Избранное"] + folders, id: \.self) { title in
                                    Button { activeFolder = title } label: {
                                        Label(title, systemImage: title == "Избранное" ? "heart.fill" : "folder")
                                            .font(.system(size: 12, weight: .medium))
                                            .padding(.horizontal, 11).padding(.vertical, 8)
                                            .foregroundStyle(activeFolder == title ? .white : AppPalette.midnight)
                                            .background(activeFolder == title ? AppPalette.rose : Color.white, in: Capsule())
                                    }.buttonStyle(.plain)
                                }
                                Button { showingFolderCreator = true } label: {
                                    Label("Новая папка", systemImage: "folder.badge.plus")
                                        .font(.system(size: 12)).padding(8)
                                }.buttonStyle(.plain)
                            }
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("Мои коллекции").font(.system(size: 22, design: .serif))
                            Spacer()
                            Button { shelfMode.toggle() } label: {
                                Label(shelfMode ? "Сетка" : "Книжная полка",
                                      systemImage: shelfMode ? "square.grid.2x2" : "books.vertical")
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Color.white.opacity(0.85), in: Capsule())
                            }.buttonStyle(.plain)
                            Text("\(filteredNotebooks.count) блокн.")
                                .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                        }.foregroundStyle(AppPalette.midnight).padding(.top, 4)
                        LazyVGrid(columns: shelfMode ? [GridItem(.adaptive(minimum: 145, maximum: 220), spacing: 22)] : columns,
                                  spacing: shelfMode ? 40 : 24) {
                            ForEach(filteredNotebooks) { book in
                                NavigationLink(value: book.id) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        NotebookCover(book: book)
                                            .aspectRatio(0.77, contentMode: .fit)
                                            .overlay(alignment: .bottom) {
                                                if shelfMode {
                                                    RoundedRectangle(cornerRadius: 5)
                                                        .fill(LinearGradient(colors: [Color(hex: 0xC3A38A),
                                                            Color(hex: 0xF2E0C8), Color(hex: 0x9F7F68)],
                                                            startPoint: .top, endPoint: .bottom))
                                                        .frame(height: 12)
                                                        .offset(y: 18)
                                                        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
                                                }
                                            }
                                        Text(book.title)
                                            .font(.system(size: 15, weight: .medium, design: .serif))
                                            .lineLimit(1).foregroundStyle(AppPalette.midnight)
                                        Text("\(book.pages.count) страниц · На устройстве")
                                            .font(.system(size: 10)).foregroundStyle(AppPalette.muted)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(book.favorite == true ? "Убрать из избранного" : "В избранное", systemImage: "heart") { library.toggleFavorite(book.id) }
                                    Button("Переименовать", systemImage: "pencil") { newNotebookTitle = book.title; toRename = book.id }
                                    Button("Дублировать блокнот", systemImage: "plus.square.on.square") { library.duplicateNotebook(book.id) }
                                    Menu("Переместить в папку", systemImage: "folder") {
                                        Button("Без папки") { library.setNotebookFolder(book.id, folder: nil) }
                                        ForEach(folders, id: \.self) { folder in
                                            Button(folder) { library.setNotebookFolder(book.id, folder: folder) }
                                        }
                                    }
                                    Button("Сменить обложку", systemImage: "paintpalette") { toChangeCover = book.id }
                                    Button("Удалить блокнот", role: .destructive) { toDelete = book.id }
                                }
                            }
                            Button { showingCreator = true } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 13)
                                        .strokeBorder(AppPalette.rose.opacity(0.47), style: StrokeStyle(lineWidth: 1.1, dash: [5, 6]))
                                    VStack(spacing: 13) {
                                        Image(systemName: "plus").font(.system(size: 24, weight: .ultraLight))
                                            .frame(width: 55, height: 55)
                                            .background(Color.white.opacity(0.55), in: Circle())
                                        Text("Новая история")
                                            .font(.system(size: 14, design: .serif))
                                    }.foregroundStyle(AppPalette.rose)
                                }.aspectRatio(0.77, contentMode: .fit)
                            }.buttonStyle(.plain)
                        }
                        Text("Сохранено локально · Без рекламы, подписки и обязательного интернета")
                            .font(.system(size: 11)).foregroundStyle(AppPalette.muted)
                            .padding(.vertical, 20)
                    }
                    .padding(.horizontal, 40).padding(.vertical, 24)
                    .frame(maxWidth: 1060).frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { id in NotebookEditor(bookID: id) }
            .sheet(isPresented: $showingCreator) { CreateNotebookSheet() }
            .alert("Новая папка", isPresented: $showingFolderCreator) {
                TextField("Название папки", text: $newFolderName)
                Button("Создать") {
                    let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty && !folders.contains(name) {
                        customFolders += "|" + name
                        activeFolder = name
                    }
                    newFolderName = ""
                }
                Button("Отмена", role: .cancel) { newFolderName = "" }
            }
            .alert("Название блокнота", isPresented: Binding(get: { toRename != nil }, set: { if !$0 { toRename = nil } })) {
                TextField("Название", text: $newNotebookTitle)
                Button("Сохранить") { if let id = toRename { library.renameNotebook(id, title: newNotebookTitle) }; toRename = nil }
                Button("Отмена", role: .cancel) { toRename = nil }
            }
                        .fileImporter(isPresented: $showingBackupImporter, allowedContentTypes: [.data]) { result in
                do {
                    let source = try result.get()
                    let access = source.startAccessingSecurityScopedResource()
                    defer { if access { source.stopAccessingSecurityScopedResource() } }
                    try library.importNotebookBackup(from: source)
                } catch { backupError = "Не удалось восстановить блокнот: \(error.localizedDescription)" }
            }
            .alert("Резервная копия", isPresented: Binding(get: { backupError != nil }, set: { if !$0 { backupError = nil } })) {
                Button("Понятно", role: .cancel) { backupError = nil }
            } message: { Text(backupError ?? "") }
            .sheet(isPresented: Binding(get: { toChangeCover != nil }, set: { if !$0 { toChangeCover = nil } })) {
                if let id = toChangeCover { ChangeNotebookCoverSheet(bookID: id) }
            }
            .alert("Удалить блокнот?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
                Button("Удалить", role: .destructive) { if let id = toDelete { library.deleteNotebook(id) }; toDelete = nil }
                Button("Отмена", role: .cancel) { toDelete = nil }
            } message: { Text("Без резервной копии вернуть записи не получится.") }
        }
    }
}

struct NotebookCover: View {
    let book: Notebook
    var body: some View {
        ZStack {
            Image("Cover_\(CoverCatalog.source(for: book.cover))").resizable().scaledToFill()
                .overlay { if let tint = CoverCatalog.tint(for: book.cover) {
                    Color(hex: tint).opacity(0.28).blendMode(.multiply).allowsHitTesting(false)
                }}
            VStack(spacing: 12) {
                Text("THE QUIET PAGES COLLECTION")
                    .font(.system(size: 7, weight: .medium)).tracking(2.1).opacity(0.70)
                Spacer()
                VStack(spacing: 15) {
                    Rectangle().fill(AppPalette.rose.opacity(0.65)).frame(width: 35, height: 1)
                    Text(book.title)
                        .font(.system(size: 25, weight: .regular, design: .serif))
                        .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.72)
                    Text("NOTES  ·  MEMORIES  ·  IDEAS")
                        .font(.system(size: 7, weight: .medium)).tracking(1.9).opacity(0.72)
                }
                .padding(.horizontal, 18).padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color(hex: ["Night", "Moonlight", "Starlight", "MidnightBlue"].contains(book.cover) ? 0x2E3540 : 0xFFF9F2).opacity(["Night", "Moonlight", "Starlight", "MidnightBlue"].contains(book.cover) ? 0.62 : 0.78))
                Spacer()
                Text("VOL. 01 / PRIVATE")
                    .font(.system(size: 8, weight: .medium)).tracking(2.2).opacity(0.7)
            }
            .padding(.horizontal, 32).padding(.vertical, 35)
            .foregroundStyle(["Night", "Moonlight", "Starlight", "MidnightBlue"].contains(book.cover) ? Color.white : AppPalette.midnight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x75685C).opacity(0.16), lineWidth: 1))
        .shadow(color: Color(hex: 0x594344).opacity(0.19), radius: 16, x: 5, y: 12)
    }
}

struct CoverSelectionGrid: View {
    @Binding var selectedCover: String
    @State private var category = "Все"
    @State private var search = ""
    private let columns = [GridItem(.adaptive(minimum: 112, maximum: 150), spacing: 13)]
    private var options: [CoverPreset] {
        CoverCatalog.all.filter { item in
            (category == "Все" || item.category == category) &&
            (search.isEmpty || item.title.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(CoverCatalog.all.count) обложки • все бесплатно")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(AppPalette.rose)
                Spacer()
                Text("Без интернета").font(.system(size: 10)).foregroundStyle(AppPalette.muted)
            }
            TextField("Найти обложку", text: $search)
                .textFieldStyle(.roundedBorder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(CoverCatalog.categories, id: \.self) { kind in
                        Button { category = kind } label: {
                            Text(kind).font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 13).padding(.vertical, 8)
                                .foregroundStyle(category == kind ? Color.white : AppPalette.midnight)
                                .background(category == kind ? AppPalette.rose : Color(hex: 0xF1E7E1), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(options) { item in
                        Button { selectedCover = item.id } label: {
                            VStack(spacing: 6) {
                                Image("Cover_\(CoverCatalog.source(for: item.id))")
                                    .resizable().scaledToFill()
                                    .overlay { if let tint = item.tintHex {
                                        Color(hex: tint).opacity(0.28).blendMode(.multiply).allowsHitTesting(false)
                                    }}
                                    .frame(height: 156).frame(maxWidth: .infinity).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedCover == item.id ? AppPalette.rose : Color(hex: 0xDCD1CD), lineWidth: selectedCover == item.id ? 3 : 1))
                                    .overlay(alignment: .topTrailing) {
                                        if selectedCover == item.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppPalette.rose).padding(7)
                                        }
                                    }
                                Text(item.title).font(.system(size: 11, design: .serif))
                                    .lineLimit(2).foregroundStyle(AppPalette.midnight)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(.vertical, 5)
            }
        }
    }
}

// Guided offline journal creation. Every choice is changeable later.
struct JournalMood: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let cover: String
    let paper: String
    static let all: [JournalMood] = [
        JournalMood(id: "romantic", title: "Нежная романтика", subtitle: "Пионы · атлас · розовый", symbol: "heart", cover: "Peony", paper: "Rose Frame"),
        JournalMood(id: "pinterest", title: "Pinterest Journal", subtitle: "Фотографии · скотч · заметки", symbol: "photo.on.rectangle.angled", cover: "Postcard", paper: "Scrapbook Frame"),
        JournalMood(id: "vintage", title: "Старинные письма", subtitle: "Книжные страницы · винтаж", symbol: "envelope", cover: "Vintage", paper: "Vintage"),
        JournalMood(id: "kawaii", title: "Kawaii", subtitle: "Клубника · котики · банты", symbol: "sparkles", cover: "Strawberry", paper: "Pink Bows"),
        JournalMood(id: "academia", title: "Dark Academia", subtitle: "Книги · чернила · история", symbol: "books.vertical", cover: "Night", paper: "Kraft Journal"),
        JournalMood(id: "minimal", title: "Quiet Luxury", subtitle: "Лён · спокойные линии", symbol: "leaf", cover: "Linen", paper: "Fine Lines"),
        JournalMood(id: "spring", title: "Весенний сад", subtitle: "Ботаника · цветы", symbol: "camera.macro", cover: "Blossom", paper: "Botanical Header"),
        JournalMood(id: "winter", title: "Зимняя сказка", subtitle: "Морозные узоры · уют", symbol: "snowflake", cover: "Moonlight", paper: "Blue Frame"),
        JournalMood(id: "work", title: "Учёба и работа", subtitle: "Конспекты · планы · задачи", symbol: "checkmark.square", cover: "Cream", paper: "Cornell"),
        JournalMood(id: "summer", title: "Летние воспоминания", subtitle: "Цветы · солнце · море", symbol: "sun.max", cover: "Painted_Summer_01", paper: "Paper_Summer_01"),
        JournalMood(id: "autumn", title: "Осенний уют", subtitle: "Листья · книги · кофе", symbol: "leaf.fill", cover: "Painted_Autumn_01", paper: "Paper_Autumn_01"),
        JournalMood(id: "magic", title: "Волшебная школа", subtitle: "Совушки · письма · звёзды", symbol: "sparkles", cover: "Painted_Magic_01", paper: "Paper_Magic_01"),
        JournalMood(id: "fantasy", title: "Сказочные истории", subtitle: "Луна · ночное небо · чудеса", symbol: "moon.stars", cover: "Painted_Magic_02", paper: "Paper_Magic_02"),
        JournalMood(id: "springpainted", title: "Весенняя акварель", subtitle: "Нежные цветочные края", symbol: "camera.macro", cover: "Painted_Spring_01", paper: "Paper_Spring_01"),
        JournalMood(id: "winterpainted", title: "Зимняя акварель", subtitle: "Иней и морозные поля", symbol: "snowflake", cover: "Painted_Winter_01", paper: "Paper_Winter_01"),
        JournalMood(id: "vintagepainted", title: "Винтажные письма", subtitle: "Пергамент · марки · кружево", symbol: "envelope.open", cover: "Painted_Vintage_01", paper: "Paper_Vintage_01")
    ]
}

struct CreateNotebookSheet: View {
    @EnvironmentObject private var library: NotebookLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Мой красивый блокнот"
    @State private var cover = "Peony"
    @State private var paper = "Rose Frame"
    @State private var mood = "romantic"
    @State private var chooseCover = false
    @State private var choosePaper = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        NotebookCover(book: Notebook(title: title.isEmpty ? "Мой блокнот" : title, cover: cover))
                            .frame(width: 142, height: 191)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ЭСТЕТИЧНАЯ МАСТЕРСКАЯ").font(.system(size: 9, weight: .semibold)).tracking(1.5)
                            Text("Создай свою историю").font(.system(size: 25, design: .serif))
                            Text("Выбирай готовый стиль, а затем смешивай любые материалы внутри блокнота.")
                                .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                        }
                    }.padding(.bottom, 4)
                    Text("Название").font(.system(size: 15, weight: .semibold))
                    TextField("Название блокнота", text: $title).textFieldStyle(.roundedBorder)
                    HStack { Text("1 · Стиль блокнота").font(.system(size: 18, design: .serif)); Spacer(); Text("\(JournalMood.all.count) настроений").font(.system(size: 11)).foregroundStyle(AppPalette.muted) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 10)], spacing: 10) {
                        ForEach(JournalMood.all) { option in
                            Button {
                                mood = option.id; cover = option.cover; paper = option.paper
                            } label: {
                                HStack(alignment: .top, spacing: 9) {
                                    Image(systemName: option.symbol).font(.system(size: 17)).frame(width: 25)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.title).font(.system(size: 13, weight: .semibold))
                                        Text(option.subtitle).font(.system(size: 10)).foregroundStyle(AppPalette.muted)
                                    }
                                    Spacer(minLength: 0)
                                    if mood == option.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppPalette.rose) }
                                }
                                .foregroundStyle(AppPalette.midnight).padding(12)
                                .background(.white, in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(mood == option.id ? AppPalette.rose : Color(hex: 0xE6D9D1), lineWidth: mood == option.id ? 2 : 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("2 · Обложка и бумага").font(.system(size: 18, design: .serif))
                    HStack(spacing: 12) {
                        Button { chooseCover = true } label: {
                            Label("Обложки · \(CoverCatalog.all.count)", systemImage: "book.closed").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                        Button { choosePaper = true } label: {
                            Label("Бумага · \(PaperCatalog.all.count)", systemImage: "square.stack").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                    }
                    Text("Все материалы доступны бесплатно и без интернета. Оформление каждой страницы можно менять отдельно.")
                        .font(.system(size: 11)).foregroundStyle(AppPalette.muted)
                }
                .padding(22)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Новый блокнот")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") { library.createNotebook(title: title, cover: cover, paper: paper, mood: mood); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $chooseCover) {
            NavigationStack {
                CoverSelectionGrid(selectedCover: $cover).padding(18)
                    .background(AppPalette.parchment)
                    .navigationTitle("Выбрать обложку")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { chooseCover = false } } }
            }.presentationDetents([.large])
        }
        .sheet(isPresented: $choosePaper) {
            PaperPalette(current: paper, customHex: nil) { picked in
                paper = picked; choosePaper = false
            } chooseCustom: { _ in choosePaper = false }
        }
    }
}

struct ChangeNotebookCoverSheet: View {
    let bookID: UUID
    @EnvironmentObject private var library: NotebookLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCover: String = "Rose"
    var body: some View {
        NavigationStack {
            CoverSelectionGrid(selectedCover: $selectedCover)
                .padding(18)
                .background(AppPalette.parchment)
                .navigationTitle("Сменить обложку")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") { library.setCover(book: bookID, cover: selectedCover); dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
        .onAppear { selectedCover = library.notebook(bookID)?.cover ?? "Rose" }
    }
}

struct StickerEntry: Identifiable {
    let id: String
    let title: String
    let category: String
}

enum StickerCatalog {
    static let categories = Studio6StickerCatalog.categories + ["Все", "Рамки", "Цветы", "Ленты", "Записки", "Уют", "Винтаж"] + MegaStickerCatalog.categories + StudioCompositionCatalog.categories
    static let all: [StickerEntry] = Studio6StickerCatalog.all + [
        StickerEntry(id: "CozyKitten", title: "Котёнок", category: "Уют"),
        StickerEntry(id: "StrawberryCake", title: "Клубничный торт", category: "Уют"),
        StickerEntry(id: "MatchaCup", title: "Матча", category: "Уют"),
        StickerEntry(id: "Pancakes", title: "Блинчики", category: "Уют"),
        StickerEntry(id: "PeonyBouquet", title: "Пионы", category: "Цветы"),
        StickerEntry(id: "SatinBow", title: "Шёлковый бант", category: "Ленты"),
        StickerEntry(id: "GinghamTape", title: "Клетчатый скотч", category: "Ленты"),
        StickerEntry(id: "PinkPaper", title: "Розовая записка", category: "Записки"),
        StickerEntry(id: "Instax", title: "Фотоаппарат", category: "Уют"),
        StickerEntry(id: "LaceButterfly", title: "Кружевная бабочка", category: "Цветы"),
        StickerEntry(id: "MintClip", title: "Зажим", category: "Записки"),
        StickerEntry(id: "Daisies", title: "Ромашки", category: "Цветы"),
        StickerEntry(id: "Rosebud", title: "Бутон", category: "Цветы"),
        StickerEntry(id: "Flower", title: "Цветок", category: "Цветы"),
        StickerEntry(id: "Peony", title: "Пион", category: "Цветы"),
        StickerEntry(id: "Butterfly", title: "Бабочка", category: "Цветы"),
        StickerEntry(id: "Bow", title: "Бантик", category: "Ленты"),
        StickerEntry(id: "Goldstar", title: "Звёздочки", category: "Уют"),
        StickerEntry(id: "Waxseal", title: "Печать", category: "Винтаж"),
        StickerEntry(id: "Coffee", title: "Кофе", category: "Уют"),
        StickerEntry(id: "Tea", title: "Чай", category: "Уют"),
        StickerEntry(id: "Book", title: "Книга", category: "Уют"),
        StickerEntry(id: "Ticket", title: "Билетик", category: "Винтаж"),
        StickerEntry(id: "Lace", title: "Кружево", category: "Ленты"),
        StickerEntry(id: "Moon", title: "Луна", category: "Уют"),
        StickerEntry(id: "Heart", title: "Сердечко", category: "Записки"),
        StickerEntry(id: "Leaf", title: "Лист", category: "Цветы"),
        StickerEntry(id: "Envelope", title: "Письмо", category: "Винтаж"),
        StickerEntry(id: "Washi", title: "Лента", category: "Ленты"),
        StickerEntry(id: "Polaroid", title: "Фоторамка", category: "Винтаж"),
        StickerEntry(id: "LinenTape", title: "Льняной скотч", category: "Ленты"),
        StickerEntry(id: "SageTape", title: "Лента шалфей", category: "Ленты"),
        StickerEntry(id: "DriedRose", title: "Сухоцвет", category: "Цветы"),
        StickerEntry(id: "AtelierPeonyBouquet1", title: "Пионы · 1", category: "Цветы"),
        StickerEntry(id: "AtelierPeonyBouquet2", title: "Пионы · 2", category: "Цветы"),
        StickerEntry(id: "AtelierDaisies1", title: "Ромашки · 1", category: "Цветы"),
        StickerEntry(id: "AtelierDaisies2", title: "Ромашки · 2", category: "Цветы"),
        StickerEntry(id: "AtelierDriedRose1", title: "Сухоцвет · 1", category: "Цветы"),
        StickerEntry(id: "AtelierDriedRose2", title: "Сухоцвет · 2", category: "Цветы"),
        StickerEntry(id: "AtelierLaceButterfly1", title: "Бабочка · 1", category: "Цветы"),
        StickerEntry(id: "AtelierLaceButterfly2", title: "Бабочка · 2", category: "Цветы"),
        StickerEntry(id: "AtelierStrawberryCake1", title: "Клубничный торт · 1", category: "Уют"),
        StickerEntry(id: "AtelierStrawberryCake2", title: "Клубничный торт · 2", category: "Уют"),
        StickerEntry(id: "AtelierCozyKitten1", title: "Рыжий кот · 1", category: "Уют"),
        StickerEntry(id: "AtelierCozyKitten2", title: "Рыжий кот · 2", category: "Уют"),
        StickerEntry(id: "AtelierMatchaCup1", title: "Чашка · 1", category: "Уют"),
        StickerEntry(id: "AtelierMatchaCup2", title: "Чашка · 2", category: "Уют"),
        StickerEntry(id: "AtelierSatinBow1", title: "Бант · 1", category: "Ленты"),
        StickerEntry(id: "AtelierSatinBow2", title: "Бант · 2", category: "Ленты"),
        StickerEntry(id: "AtelierInstax1", title: "Камера · 1", category: "Уют"),
        StickerEntry(id: "AtelierInstax2", title: "Камера · 2", category: "Уют"),
        StickerEntry(id: "AtelierPancakes1", title: "Панкейки · 1", category: "Уют"),
        StickerEntry(id: "AtelierPancakes2", title: "Панкейки · 2", category: "Уют"),
        StickerEntry(id: "AtelierPolaroid1", title: "Полароид · 1", category: "Винтаж"),
        StickerEntry(id: "AtelierPolaroid2", title: "Полароид · 2", category: "Винтаж"),
        StickerEntry(id: "WashiGingham1", title: "Розовый · клетка", category: "Ленты"),
        StickerEntry(id: "WashiFloral1", title: "Розовый · цветы", category: "Ленты"),
        StickerEntry(id: "WashiSilk1", title: "Розовый · атлас", category: "Ленты"),
        StickerEntry(id: "WashiGingham2", title: "Сиреневый · клетка", category: "Ленты"),
        StickerEntry(id: "WashiFloral2", title: "Сиреневый · цветы", category: "Ленты"),
        StickerEntry(id: "WashiSilk2", title: "Сиреневый · атлас", category: "Ленты"),
        StickerEntry(id: "WashiGingham3", title: "Мятный · клетка", category: "Ленты"),
        StickerEntry(id: "WashiFloral3", title: "Мятный · цветы", category: "Ленты"),
        StickerEntry(id: "WashiSilk3", title: "Мятный · атлас", category: "Ленты"),
        StickerEntry(id: "WashiGingham4", title: "Ванильный · клетка", category: "Ленты"),
        StickerEntry(id: "WashiFloral4", title: "Ванильный · цветы", category: "Ленты"),
        StickerEntry(id: "WashiSilk4", title: "Ванильный · атлас", category: "Ленты"),
        StickerEntry(id: "WashiGingham5", title: "Голубой · клетка", category: "Ленты"),
        StickerEntry(id: "WashiFloral5", title: "Голубой · цветы", category: "Ленты"),
        StickerEntry(id: "WashiSilk5", title: "Голубой · атлас", category: "Ленты"),
        StickerEntry(id: "WashiGingham6", title: "Персиковый · клетка", category: "Ленты"),
        StickerEntry(id: "WashiFloral6", title: "Персиковый · цветы", category: "Ленты"),
        StickerEntry(id: "WashiSilk6", title: "Персиковый · атлас", category: "Ленты"),
        StickerEntry(id: "WashiGingham7", title: "Льняной · клетка", category: "Ленты"),
        StickerEntry(id: "WashiFloral7", title: "Льняной · цветы", category: "Ленты"),
        StickerEntry(id: "WashiSilk7", title: "Льняной · атлас", category: "Ленты"),
        StickerEntry(id: "WashiGingham8", title: "Лавандовый · клетка", category: "Ленты"),
        StickerEntry(id: "WashiFloral8", title: "Лавандовый · цветы", category: "Ленты"),
        StickerEntry(id: "WashiSilk8", title: "Лавандовый · атлас", category: "Ленты"),
        StickerEntry(id: "NoteCard1", title: "Записка · Розовый", category: "Записки"),
        StickerEntry(id: "NoteCard2", title: "Записка · Сиреневый", category: "Записки"),
        StickerEntry(id: "NoteCard3", title: "Записка · Мятный", category: "Записки"),
        StickerEntry(id: "NoteCard4", title: "Записка · Ванильный", category: "Записки"),
        StickerEntry(id: "NoteCard5", title: "Записка · Голубой", category: "Записки"),
        StickerEntry(id: "NoteCard6", title: "Записка · Персиковый", category: "Записки"),
        StickerEntry(id: "NoteCard7", title: "Записка · Льняной", category: "Записки"),
        StickerEntry(id: "NoteCard8", title: "Записка · Лавандовый", category: "Записки"),
        StickerEntry(id: "Label1", title: "Бирка · Розовый", category: "Винтаж"),
        StickerEntry(id: "Label2", title: "Бирка · Сиреневый", category: "Винтаж"),
        StickerEntry(id: "Label3", title: "Бирка · Мятный", category: "Винтаж"),
        StickerEntry(id: "Label4", title: "Бирка · Ванильный", category: "Винтаж"),
        StickerEntry(id: "Label5", title: "Бирка · Голубой", category: "Винтаж"),
        StickerEntry(id: "Label6", title: "Бирка · Персиковый", category: "Винтаж"),
        StickerEntry(id: "Label7", title: "Бирка · Льняной", category: "Винтаж"),
        StickerEntry(id: "Label8", title: "Бирка · Лавандовый", category: "Винтаж"),
        StickerEntry(id: "FrameLace1", title: "Lace · Пудровая роза", category: "Рамки"),
        StickerEntry(id: "FrameLace2", title: "Lace · Молочная сирень", category: "Рамки"),
        StickerEntry(id: "FrameLace3", title: "Lace · Шалфей", category: "Рамки"),
        StickerEntry(id: "FrameLace4", title: "Lace · Шампань", category: "Рамки"),
        StickerEntry(id: "FrameLace5", title: "Lace · Небесная", category: "Рамки"),
        StickerEntry(id: "FrameLace6", title: "Lace · Персик", category: "Рамки"),
        StickerEntry(id: "FrameLace7", title: "Lace · Винтаж", category: "Рамки"),
        StickerEntry(id: "FrameLace8", title: "Lace · Зефир", category: "Рамки"),
        StickerEntry(id: "FrameFloral1", title: "Floral · Пудровая роза", category: "Рамки"),
        StickerEntry(id: "FrameFloral2", title: "Floral · Молочная сирень", category: "Рамки"),
        StickerEntry(id: "FrameFloral3", title: "Floral · Шалфей", category: "Рамки"),
        StickerEntry(id: "FrameFloral4", title: "Floral · Шампань", category: "Рамки"),
        StickerEntry(id: "FrameFloral5", title: "Floral · Небесная", category: "Рамки"),
        StickerEntry(id: "FrameFloral6", title: "Floral · Персик", category: "Рамки"),
        StickerEntry(id: "FrameFloral7", title: "Floral · Винтаж", category: "Рамки"),
        StickerEntry(id: "FrameFloral8", title: "Floral · Зефир", category: "Рамки"),
        StickerEntry(id: "FramePearl1", title: "Pearl · Пудровая роза", category: "Рамки"),
        StickerEntry(id: "FramePearl2", title: "Pearl · Молочная сирень", category: "Рамки"),
        StickerEntry(id: "FramePearl3", title: "Pearl · Шалфей", category: "Рамки"),
        StickerEntry(id: "FramePearl4", title: "Pearl · Шампань", category: "Рамки"),
        StickerEntry(id: "FramePearl5", title: "Pearl · Небесная", category: "Рамки"),
        StickerEntry(id: "FramePearl6", title: "Pearl · Персик", category: "Рамки"),
        StickerEntry(id: "FramePearl7", title: "Pearl · Винтаж", category: "Рамки"),
        StickerEntry(id: "FramePearl8", title: "Pearl · Зефир", category: "Рамки"),
        StickerEntry(id: "FrameBotanical1", title: "Botanical · Пудровая роза", category: "Рамки"),
        StickerEntry(id: "FrameBotanical2", title: "Botanical · Молочная сирень", category: "Рамки"),
        StickerEntry(id: "FrameBotanical3", title: "Botanical · Шалфей", category: "Рамки"),
        StickerEntry(id: "FrameBotanical4", title: "Botanical · Шампань", category: "Рамки"),
        StickerEntry(id: "FrameBotanical5", title: "Botanical · Небесная", category: "Рамки"),
        StickerEntry(id: "FrameBotanical6", title: "Botanical · Персик", category: "Рамки"),
        StickerEntry(id: "FrameBotanical7", title: "Botanical · Винтаж", category: "Рамки"),
        StickerEntry(id: "FrameBotanical8", title: "Botanical · Зефир", category: "Рамки"),
    ] + MegaStickerCatalog.all + StudioCompositionCatalog.all
}

/// The 2,000-image catalog is generated from 20 collections × 100 stickers.
/// All images are bundled with the app during the GitHub Actions build for offline access.
private enum MegaStickerCatalog {
    static let categories: [String] = [
        "Осенний вайб", "Зимняя сказка", "Новогоднее волшебство", "Весеннее пробуждение",
        "Лето и каникулы", "Магическая академия", "Волчьи легенды", "Книги и чтение",
        "Кампус и мечты", "Кино и сериалы", "Сказочные миры", "Луна и звёзды",
        "Горные легенды", "Методист и детский сад", "Экология и природа", "Кофейный уют",
        "Пастельная эстетика", "Письма и винтаж", "Цветочные сады", "Нежность и мечты"
    ]
    static let all: [StickerEntry] = categories.enumerated().flatMap { categoryIndex, category in
        (1...100).map { localIndex in
            let number = categoryIndex * 100 + localIndex
            return StickerEntry(
                id: String(format: "Mega_%04d", number),
                title: "\(category) · \(localIndex)",
                category: category
            )
        }
    }
}

// 1,000 transparent PNG collages compiled from our original offline art.
// These are precomposed stickers, individually movable as one object.
enum StudioCompositionCatalog {
    static let categories = ["Бантики и цветы", "Акварельные букеты", "Кофе и книги",
        "Романтические письма", "Сказочные ночи", "Сезонные коллажи", "Винтажный декор",
        "Сладкие моменты", "Пастельные истории", "Готовые композиции"]
    static func components(for name: String) -> (String, String)? {
        guard name.hasPrefix("AtelierMix_"),
              let n = Int(name.replacingOccurrences(of: "AtelierMix_", with: "")),
              (1...1000).contains(n) else { return nil }
        let group = (n - 1) / 100
        let pos = (n - 1) % 100
        let first = (group * 2) * 100 + ((pos * 13 + 7) % 100) + 1
        let second = (group * 2 + 1) * 100 + ((pos * 17 + 23) % 100) + 1
        return (String(format: "Mega_%04d", first), String(format: "Mega_%04d", second))
    }
    static let all: [StickerEntry] = categories.enumerated().flatMap { group, title in
        (1...100).map { position in
            let number = group * 100 + position
            return StickerEntry(id: String(format: "AtelierMix_%04d", number),
                                title: "\(title) · \(position)", category: title)
        }
    }
}


enum Studio6StickerCatalog {
    static let categories = ["Винтажные закладки", "Акварельные растения", "Банты и кружево", "Декоративный скотч", "Пейзажные бордюры", "Сказочные объекты", "Книги, письма и ключи", "Животные", "Часы, фонари и свечи", "Чай и десерты", "Сезонные украшения", "Рамки и полароиды", "Текстурная бумага", "Готовые композиции"]
    static let all: [StickerEntry] = [
        StickerEntry(id: "Studio6_01", title: "Закладка лесная", category: "Винтажные закладки"),
        StickerEntry(id: "Studio6_02", title: "Пионы акварельные", category: "Акварельные растения"),
        StickerEntry(id: "Studio6_03", title: "Бант с кружевом", category: "Банты и кружево"),
        StickerEntry(id: "Studio6_04", title: "Ботанический скотч", category: "Декоративный скотч"),
        StickerEntry(id: "Studio6_05", title: "Горный пейзаж", category: "Пейзажные бордюры"),
        StickerEntry(id: "Studio6_06", title: "Сказочная лестница", category: "Сказочные объекты"),
        StickerEntry(id: "Studio6_07", title: "Волшебная книга и ключ", category: "Книги, письма и ключи"),
        StickerEntry(id: "Studio6_08", title: "Спящий котёнок", category: "Животные"),
        StickerEntry(id: "Studio6_09", title: "Старинный фонарь", category: "Часы, фонари и свечи"),
        StickerEntry(id: "Studio6_10", title: "Чай с печеньем", category: "Чай и десерты"),
        StickerEntry(id: "Studio6_11", title: "Осенние украшения", category: "Сезонные украшения"),
        StickerEntry(id: "Studio6_12", title: "Цветочный полароид", category: "Рамки и полароиды"),
        StickerEntry(id: "Studio6_13", title: "Старинная бумага", category: "Текстурная бумага"),
        StickerEntry(id: "Studio6_14", title: "Книжная композиция", category: "Готовые композиции"),
        StickerEntry(id: "Studio6_15", title: "Зимняя веточка", category: "Сезонные украшения"),
        StickerEntry(id: "Studio6_16", title: "Луна и звёзды", category: "Сказочные объекты")
    ]
}

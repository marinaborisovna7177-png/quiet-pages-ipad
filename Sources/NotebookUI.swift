import SwiftUI
import PhotosUI

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
    @State private var search = ""
    @State private var toDelete: UUID?
    @State private var toChangeCover: UUID?
    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 230), spacing: 23)]
    private var filteredNotebooks: [Notebook] {
        library.notebooks.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
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
                            Button { showingCreator = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                                    Text("Новый блокнот").font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, 18).padding(.vertical, 15)
                                .foregroundStyle(.white)
                                .background(AppPalette.midnight, in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain)
                        }.padding(.vertical, 18)
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(AppPalette.rose)
                            TextField("Найти блокнот...", text: $search)
                                .font(.system(size: 14)).autocorrectionDisabled()
                        }
                        .padding(.horizontal, 18).padding(.vertical, 15)
                        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color(hex: 0xE8DDD3), lineWidth: 1))
                        HStack(alignment: .firstTextBaseline) {
                            Text("Мои коллекции").font(.system(size: 22, design: .serif))
                            Spacer()
                            Text("\(filteredNotebooks.count) блокн.")
                                .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                        }.foregroundStyle(AppPalette.midnight).padding(.top, 4)
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(filteredNotebooks) { book in
                                NavigationLink(value: book.id) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        NotebookCover(book: book)
                                            .aspectRatio(0.77, contentMode: .fit)
                                        Text(book.title)
                                            .font(.system(size: 15, weight: .medium, design: .serif))
                                            .lineLimit(1).foregroundStyle(AppPalette.midnight)
                                        Text("\(book.pages.count) страниц · На устройстве")
                                            .font(.system(size: 10)).foregroundStyle(AppPalette.muted)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
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
            Image("Cover_\(book.cover)").resizable().scaledToFill()
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
                Text("36 обложек • все бесплатно")
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
                                Image("Cover_\(item.id)")
                                    .resizable().scaledToFill()
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

struct CreateNotebookSheet: View {
    @EnvironmentObject private var library: NotebookLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Мой красивый блокнот"
    @State private var cover = "Rose"
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Название блокнота").font(.system(size: 13, weight: .medium))
                    TextField("Например: Мои мечты", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                CoverSelectionGrid(selectedCover: $cover)
            }
            .padding(18)
            .background(AppPalette.parchment)
            .navigationTitle("Новый блокнот")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") { library.createNotebook(title: title, cover: cover); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }.presentationDetents([.large])
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
    static let categories = ["Все", "Рамки", "Цветы", "Ленты", "Записки", "Уют", "Винтаж"] + MegaStickerCatalog.categories
    static let all: [StickerEntry] = [
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
    ] + MegaStickerCatalog.all
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

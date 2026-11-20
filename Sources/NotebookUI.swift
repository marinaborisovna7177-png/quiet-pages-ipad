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
    static let covers = ["Rose", "Sage", "Lavender", "Night", "Cream", "Blue"]
    static let papers = ["Ivory", "Lines", "Dots", "Grid", "Blush", "Lilac", "Sage", "Dark", "Rose Lines", "Cream Grid", "Daily Plan", "Checklist", "Vintage", "Cornell", "Peach", "Lemon", "Sea Glass", "Powder Blue", "Ballet Pink", "Dusty Rose", "Ivory Gold", "Bluebell", "Caramel", "Mauve", "Aqua", "Almond"]
    static let stickers: [(String,String)] = [
        ("CozyKitten", "Котёнок"), ("StrawberryCake", "Торт"),
        ("MatchaCup", "Матча"), ("Pancakes", "Панкейки"),
        ("PeonyBouquet", "Пионы"), ("SatinBow", "Атласный бант"),
        ("GinghamTape", "Лента"), ("PinkPaper", "Бумага"),
        ("Instax", "Камера"), ("LaceButterfly", "Кружево"),
        ("MintClip", "Зажим"), ("Daisies", "Ромашки"),
        ("Rosebud", "Роза"), ("Flower", "Цветы"), ("Peony", "Пион"),
        ("Butterfly", "Бабочка"), ("Bow", "Бант"), ("Goldstar", "Звёзды"),
        ("Waxseal", "Печать"), ("Coffee", "Кофе"), ("Tea", "Чай"),
        ("Book", "Книга"), ("Ticket", "Билет"), ("Lace", "Кружево"),
        ("Moon", "Луна"), ("Heart", "Сердце"), ("Leaf", "Листья"),
        ("Envelope", "Письмо"), ("Washi", "Скотч"), ("Polaroid", "Фоторамка"),
        ("LinenTape", "Льняной скотч"), ("SageTape", "Лента шалфей"), ("DriedRose", "Сухоцвет")
    ]
}

// Atelier-style offline library: tactile covers, spacious editorial layout.
struct LibraryView: View {
    @EnvironmentObject private var library: NotebookLibrary
    @State private var showingCreator = false
    @State private var search = ""
    @State private var toDelete: UUID?
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
                .background(Color(hex: book.cover == "Night" ? 0x2E3540 : 0xFFF9F2).opacity(book.cover == "Night" ? 0.62 : 0.78))
                Spacer()
                Text("VOL. 01 / PRIVATE")
                    .font(.system(size: 8, weight: .medium)).tracking(2.2).opacity(0.7)
            }
            .padding(.horizontal, 32).padding(.vertical, 35)
            .foregroundStyle(book.cover == "Night" ? Color.white : AppPalette.midnight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0x75685C).opacity(0.16), lineWidth: 1))
        .shadow(color: Color(hex: 0x594344).opacity(0.19), radius: 16, x: 5, y: 12)
    }
}

struct CreateNotebookSheet: View {
    @EnvironmentObject private var library: NotebookLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Мой красивый блокнот"
    @State private var cover = "Rose"
    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 13)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") { TextField("Название блокнота", text: $title) }
                Section("Выбери обложку") {
                    LazyVGrid(columns: columns) {
                        ForEach(AppPalette.covers, id: \.self) { name in
                            Button { cover = name } label: {
                                Image("Cover_\(name)")
                                    .resizable().aspectRatio(0.77, contentMode: .fill)
                                    .frame(height: 112).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9)
                                        .stroke(cover == name ? AppPalette.rose : .clear, lineWidth: 4))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 7)
                }
            }
            .navigationTitle("Новый блокнот")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") { library.createNotebook(title: title, cover: cover); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }.presentationDetents([.medium, .large])
    }
}

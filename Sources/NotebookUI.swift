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
    static let parchment = Color(hex: 0xF7F1E9)
    static let midnight = Color(hex: 0x343342)
    static let rose = Color(hex: 0xB06D84)
    static let muted = Color(hex: 0x857B85)
    static let covers = ["Rose", "Sage", "Lavender", "Night", "Cream", "Blue"]
    static let papers = ["Ivory", "Lines", "Dots", "Grid", "Blush", "Lilac", "Sage", "Dark", "Rose Lines", "Cream Grid", "Daily Plan", "Checklist", "Vintage", "Cornell"]
    static let stickers: [(String,String)] = [
        ("Rosebud", "Роза"), ("Flower", "Цветы"), ("Peony", "Пион"),
        ("Butterfly", "Бабочка"), ("Bow", "Бант"), ("Goldstar", "Звёзды"),
        ("Waxseal", "Печать"), ("Coffee", "Кофе"), ("Tea", "Чай"),
        ("Book", "Книга"), ("Ticket", "Билет"), ("Lace", "Кружево"),
        ("Moon", "Луна"), ("Heart", "Сердце"), ("Leaf", "Листья"),
        ("Envelope", "Письмо"), ("Washi", "Скотч"), ("Polaroid", "Фото")
    ]
}

struct LibraryView: View {
    @EnvironmentObject private var library: NotebookLibrary
    @State private var showingCreator = false
    @State private var search = ""
    private var filteredNotebooks: [Notebook] {
        library.notebooks.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }
    @State private var toDelete: UUID?
    private let columns = [GridItem(.adaptive(minimum: 182, maximum: 235), spacing: 27)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppPalette.parchment.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 27) {
                        header
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Моя библиотека").font(.system(size: 26, weight: .semibold, design: .serif))
                                Text("Личные страницы — только на твоём iPad")
                                    .font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                            }
                            Spacer()
                            Button { showingCreator = true } label: {
                                Label("Новый блокнот", systemImage: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(AppPalette.midnight, in: Capsule())
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(AppPalette.muted)
                            TextField("Поиск по блокнотам", text: $search)
                                .font(.system(size: 14))
                                .autocorrectionDisabled()
                        }
                        .padding(13)
                        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
                        LazyVGrid(columns: columns, spacing: 30) {
                            ForEach(filteredNotebooks) { book in
                                NavigationLink(value: book.id) {
                                    VStack(alignment: .leading, spacing: 11) {
                                        NotebookCover(book: book)
                                            .aspectRatio(0.78, contentMode: .fit)
                                        Text(book.title).font(.system(size: 16, weight: .semibold, design: .serif))
                                            .foregroundStyle(AppPalette.midnight).lineLimit(1)
                                        Text("\(book.pages.count) стр. · Офлайн")
                                            .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Удалить блокнот", role: .destructive) { toDelete = book.id }
                                }
                            }
                            Button { showingCreator = true } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 17)
                                        .stroke(AppPalette.rose.opacity(0.42), style: StrokeStyle(lineWidth: 1.4, dash: [8,7]))
                                    VStack(spacing: 16) {
                                        Image(systemName: "plus.circle").font(.system(size: 39, weight: .ultraLight))
                                        Text("Создать новый")
                                            .font(.system(size: 17, weight: .medium, design: .serif))
                                    }
                                    .foregroundStyle(AppPalette.rose)
                                }
                                .aspectRatio(0.78, contentMode: .fit)
                            }.buttonStyle(.plain)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                            Text("Никаких подписок, рекламы и обязательного интернета. Сохраняется на устройстве.")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(AppPalette.muted)
                        .padding(.top, 18)
                    }
                    .padding(.horizontal, 35).padding(.vertical, 24)
                    .frame(maxWidth: 1080)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { id in NotebookEditor(bookID: id) }
            .sheet(isPresented: $showingCreator) { CreateNotebookSheet() }
            .alert("Удалить блокнот?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
                Button("Удалить", role: .destructive) { if let id = toDelete { library.deleteNotebook(id) }; toDelete = nil }
                Button("Отмена", role: .cancel) { toDelete = nil }
            } message: { Text("Восстановить его без резервной копии не получится.") }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: "leaf").font(.system(size: 22, weight: .ultraLight))
                Text("ТИХИЕ СТРАНИЦЫ")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(3.2)
                Spacer()
                Text("OFFLINE JOURNAL")
                    .font(.system(size: 10, weight: .medium)).tracking(2)
            }
            .foregroundStyle(AppPalette.rose)
            Rectangle().frame(height: 1).foregroundStyle(Color(hex: 0xD9CCC5))
                .padding(.top, 14)
        }
    }
}

struct NotebookCover: View {
    let book: Notebook
    var body: some View {
        ZStack {
            Image("Cover_\(book.cover)")
                .resizable().scaledToFill().clipped()
            Rectangle().stroke(Color.white.opacity(0.48), lineWidth: 1)
                .padding(10)
            VStack(spacing: 14) {
                Spacer()
                Image(systemName: "sparkle").font(.system(size: 25, weight: .ultraLight))
                Text(book.title)
                    .font(.system(size: 25, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.72)
                Rectangle().frame(width: 36, height: 1)
                Text("notes & little memories")
                    .font(.system(size: 10, weight: .medium, design: .serif)).tracking(1.4)
                Spacer()
                Text("EST. 2026").font(.system(size: 9)).tracking(3)
                    .padding(.bottom, 16)
            }
            .padding(20)
            .foregroundStyle(book.cover == "Night" ? Color.white : AppPalette.midnight)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 18, x: 5, y: 11)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.10))
                .frame(width: 7).padding(.leading, 7)
        }
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

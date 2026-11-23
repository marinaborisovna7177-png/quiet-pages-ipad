import SwiftUI

struct CoverPreset: Identifiable {
    let id: String
    let title: String
    let category: String
}

enum CoverCatalog {
    static let all: [CoverPreset] = [
        CoverPreset(id: "Rose", title: "Розовая коллекция", category: "Романтика"),
        CoverPreset(id: "Sage", title: "Шалфей", category: "Природа"),
        CoverPreset(id: "Lavender", title: "Лавандовый", category: "Романтика"),
        CoverPreset(id: "Night", title: "Ночной дневник", category: "Винтаж"),
        CoverPreset(id: "Cream", title: "Кремовый", category: "Минимализм"),
        CoverPreset(id: "Blue", title: "Голубой", category: "Минимализм"),
        CoverPreset(id: "Cherry", title: "Вишнёвый сад", category: "Романтика"),
        CoverPreset(id: "Pearl", title: "Жемчужная пудра", category: "Романтика"),
        CoverPreset(id: "Peony", title: "Пионовый букет", category: "Романтика"),
        CoverPreset(id: "Ribbon", title: "Шёлковые ленты", category: "Романтика"),
        CoverPreset(id: "Blossom", title: "Весенние цветы", category: "Романтика"),
        CoverPreset(id: "Ballet", title: "Балетный розовый", category: "Романтика"),
        CoverPreset(id: "Strawberry", title: "Клубничный крем", category: "Романтика"),
        CoverPreset(id: "Sakura", title: "Сакура", category: "Романтика"),
        CoverPreset(id: "Orchid", title: "Орхидея", category: "Романтика"),
        CoverPreset(id: "Daisy", title: "Ромашковое поле", category: "Природа"),
        CoverPreset(id: "Botanic", title: "Ботанический", category: "Природа"),
        CoverPreset(id: "Linen", title: "Натуральный лён", category: "Природа"),
        CoverPreset(id: "Olive", title: "Оливковый", category: "Природа"),
        CoverPreset(id: "Forest", title: "Лесные заметки", category: "Природа"),
        CoverPreset(id: "Terracotta", title: "Терракота", category: "Природа"),
        CoverPreset(id: "BlueSky", title: "Нежное небо", category: "Природа"),
        CoverPreset(id: "Seaside", title: "Морской бриз", category: "Природа"),
        CoverPreset(id: "Lilypad", title: "Зелёный чай", category: "Природа"),
        CoverPreset(id: "Autumn", title: "Осенние письма", category: "Природа"),
        CoverPreset(id: "Clouds", title: "Облака", category: "Минимализм"),
        CoverPreset(id: "Marble", title: "Розовый мрамор", category: "Минимализм"),
        CoverPreset(id: "Buttercream", title: "Ванильный", category: "Минимализм"),
        CoverPreset(id: "Honey", title: "Медовый", category: "Минимализм"),
        CoverPreset(id: "GoldLeaf", title: "Золотой контур", category: "Минимализм"),
        CoverPreset(id: "Postcard", title: "Старинная открытка", category: "Минимализм"),
        CoverPreset(id: "Coffee", title: "Кофейная бумага", category: "Винтаж"),
        CoverPreset(id: "Vintage", title: "Винтажная роза", category: "Винтаж"),
        CoverPreset(id: "Moonlight", title: "Лунная ночь", category: "Винтаж"),
        CoverPreset(id: "Starlight", title: "Звёздная пыль", category: "Винтаж"),
        CoverPreset(id: "MidnightBlue", title: "Ночная синь", category: "Винтаж"),
    ]
    static let categories = ["Все", "Романтика", "Природа", "Минимализм", "Винтаж"]
    static func find(_ id: String) -> CoverPreset? { all.first(where: { $0.id == id }) }
}

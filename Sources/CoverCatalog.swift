import SwiftUI

struct CoverPreset: Identifiable {
    let id: String
    let title: String
    let category: String
    var sourceCover: String? = nil
    var tintHex: UInt32? = nil
}

enum CoverCatalog {
    static let all: [CoverPreset] = {
        var values: [CoverPreset] = [
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
        let bases = ["Rose", "Peony", "Strawberry", "Linen", "Vintage", "Night", "Autumn", "Sakura", "Coffee", "Seaside", "Marble", "Ribbon"]
        let families = ["Нежная", "Цветочная", "Клубничная", "Льняная", "Старинная", "Ночная", "Осенняя", "Сакура", "Кофейная", "Морская", "Мраморная", "Атласная", "Зимняя сказка", "Весенний сад", "Летние мечты", "Осенний уют", "Волшебная академия", "Старинная библиотека"]
        let shades: [(String, UInt32)] = [
            ("Пудра", 0xF4CBD7), ("Персик", 0xEBC4B5), ("Лаванда", 0xD2C5ED),
            ("Шалфей", 0xAFCCB2), ("Крем", 0xF0DEC2), ("Голубой", 0xB3D2E8),
            ("Какао", 0x96705F), ("Роза", 0xDCA5BB), ("Серебро", 0xD9DDE5)
        ]
        for index in bases.indices {
            for shade in shades.indices {
                var design = CoverPreset(id: "StudioCover_\(index * shades.count + shade + 1)",
                    title: "\(families[index]) · \(shades[shade].0)", category: families[index])
                design.sourceCover = bases[index]
                design.tintHex = shades[shade].1
                values.append(design)
            }
        }
        let coverThemes: [(String, String)] = [
            ("Winter", "Зимняя сказка"), ("Spring", "Весенний сад"),
            ("Summer", "Летние мечты"), ("Autumn", "Осенний уют"),
            ("Magic", "Волшебная академия"), ("Vintage", "Старинная библиотека")
        ]
        for (key, title) in coverThemes {
            for number in 1...4 {
                let asset = String(format: "Painted_%@_%02d", key, number)
                values.append(CoverPreset(id: asset, title: "\(title) · №\(number)", category: title))
            }
        }
        return values
    }()
    static let categories = ["Все", "Романтика", "Природа", "Минимализм", "Винтаж", "Нежная", "Цветочная", "Клубничная", "Льняная", "Старинная", "Ночная", "Осенняя", "Сакура", "Кофейная", "Морская", "Мраморная", "Атласная", "Зимняя сказка", "Весенний сад", "Летние мечты", "Осенний уют", "Волшебная академия", "Старинная библиотека"]
    static func find(_ id: String) -> CoverPreset? { all.first(where: { $0.id == id }) }
    static func source(for id: String) -> String { find(id)?.sourceCover ?? id }
    static func tint(for id: String) -> UInt32? { find(id)?.tintHex }

}

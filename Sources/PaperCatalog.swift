import SwiftUI

// Избранные бумаги + локальные шаблоны, без магазина и сети. Старые ID сохранены.
struct PaperPreset: Identifiable {
    let id: String
    let title: String
    let category: String
    let background: UInt32
    let accent: UInt32
    let pattern: String
    init(_ id: String, _ title: String, _ category: String, _ background: UInt32, _ accent: UInt32, _ pattern: String) {
        self.id = id; self.title = title; self.category = category
        self.background = background; self.accent = accent; self.pattern = pattern
    }
}

enum PaperCatalog {
    static let all: [PaperPreset] = {
        var values: [PaperPreset] = [
        PaperPreset("Ivory", "Слоновая кость", "Цветная", 0xFFFDF7, 0xBCB0AE, "blank"),
        PaperPreset("Lines", "Классическая линейка", "Для записей", 0xFFFDF7, 0xA7B8C2, "lines"),
        PaperPreset("Dots", "Точки", "Для записей", 0xFFFDF7, 0xBEA9B8, "dots"),
        PaperPreset("Grid", "Клетка", "Для записей", 0xFFFDF7, 0xB4C4D1, "grid"),
        PaperPreset("Blush", "Нежно-розовая", "Цветная", 0xFFF0F0, 0xD5A9B3, "blank"),
        PaperPreset("Lilac", "Лиловая", "Цветная", 0xF2EFF9, 0xB6A2C5, "blank"),
        PaperPreset("Sage", "Шалфейная", "Цветная", 0xF1F4EC, 0x9AAE97, "blank"),
        PaperPreset("Dark", "Тёмная", "Цветная", 0x2E3441, 0xA9BBCB, "blank"),
        PaperPreset("Rose Lines", "Розовая линейка", "Для записей", 0xFFF0F0, 0xD5A9B3, "lines"),
        PaperPreset("Cream Grid", "Кремовая клетка", "Для записей", 0xFFF6E9, 0xC1AF9B, "grid"),
        PaperPreset("Daily Plan", "План дня", "Планеры", 0xFFF6E9, 0xC0AA9C, "daily"),
        PaperPreset("Checklist", "Список дел", "Планеры", 0xFFF6E9, 0xC0AA9C, "checklist"),
        PaperPreset("Vintage", "Винтажная рамка", "Эстетика", 0xFFF6E9, 0xBEA68A, "vintage"),
        PaperPreset("Cornell", "Конспект Корнелла", "Учёба", 0xFFF6E9, 0xBCA6A3, "cornell"),
        PaperPreset("Peach", "Персиковая", "Цветная", 0xFFE4D8, 0xB3A7A4, "blank"),
        PaperPreset("Lemon", "Лимонная", "Цветная", 0xFFF7C9, 0xB3A7A4, "blank"),
        PaperPreset("Sea Glass", "Морская", "Цветная", 0xD9EEE7, 0xB3A7A4, "blank"),
        PaperPreset("Powder Blue", "Пудрово-голубая", "Цветная", 0xE3F0FD, 0xB3A7A4, "blank"),
        PaperPreset("Ballet Pink", "Балетная", "Цветная", 0xFCE1EA, 0xB3A7A4, "blank"),
        PaperPreset("Dusty Rose", "Пыльная роза", "Цветная", 0xEBC9CF, 0xB3A7A4, "blank"),
        PaperPreset("Ivory Gold", "Золотистый крем", "Цветная", 0xF8EBD8, 0xB3A7A4, "blank"),
        PaperPreset("Bluebell", "Незабудка", "Цветная", 0xE3E5F9, 0xB3A7A4, "blank"),
        PaperPreset("Caramel", "Карамельная", "Цветная", 0xEEDDCB, 0xB3A7A4, "blank"),
        PaperPreset("Mauve", "Пыльная сирень", "Цветная", 0xE6D7E6, 0xB3A7A4, "blank"),
        PaperPreset("Aqua", "Аквамарин", "Цветная", 0xD6F4F0, 0xB3A7A4, "blank"),
        PaperPreset("Almond", "Миндальная", "Цветная", 0xF4E3CE, 0xB3A7A4, "blank"),
        PaperPreset("Pink Dots", "Розовые точки", "Для записей", 0xFFF3F6, 0xD0A2B5, "dots"),
        PaperPreset("Sage Dots", "Мятные точки", "Для записей", 0xEFF7EF, 0xA7BDA8, "dots"),
        PaperPreset("Lavender Dots", "Лавандовые точки", "Для записей", 0xF5F0FF, 0xBEABD4, "dots"),
        PaperPreset("Fine Lines", "Тонкая линейка", "Для записей", 0xFFFAF1, 0xC3BAB1, "thinlines"),
        PaperPreset("Blue Lines", "Синяя линейка", "Для записей", 0xF4FAFF, 0xABC2D9, "lines"),
        PaperPreset("Rose Double Lines", "Двойная розовая", "Для записей", 0xFFF8F7, 0xD6ACB3, "doublelines"),
        PaperPreset("Lilac Grid", "Сиреневая клетка", "Для записей", 0xF6F1FF, 0xC7B0DA, "grid"),
        PaperPreset("Sage Grid", "Зелёная клетка", "Для записей", 0xF7FBF5, 0xA7BCA8, "grid"),
        PaperPreset("Peach Grid", "Персиковая клетка", "Для записей", 0xFFF7F0, 0xD9B5A5, "grid"),
        PaperPreset("Mint Graph", "Мелкая миллиметровка", "Для записей", 0xF5FFF9, 0xA9CBBE, "finegrid"),
        PaperPreset("Blue Graph", "Голубая миллиметровка", "Для записей", 0xF6FBFF, 0x9EB9CD, "finegrid"),
        PaperPreset("Margin Notes", "Линейка с полями", "Для записей", 0xFFFDF8, 0xBFC2D7, "margin"),
        PaperPreset("Pastel Rainbow", "Радужные полоски", "Для записей", 0xFFFDF9, 0xC8B8C5, "rainbowlines"),
        PaperPreset("Cherry Gingham", "Розовая клеточка", "Узоры", 0xFFF7F8, 0xE1B2C0, "gingham"),
        PaperPreset("Sage Gingham", "Шалфейная клеточка", "Узоры", 0xF5F9F0, 0xA8C2AD, "gingham"),
        PaperPreset("Blue Gingham", "Голубая клеточка", "Узоры", 0xF3FAFF, 0xA3BED3, "gingham"),
        PaperPreset("Lilac Gingham", "Сиреневая клеточка", "Узоры", 0xF8F4FF, 0xBDB2D9, "gingham"),
        PaperPreset("Strawberry Stripes", "Клубничные полоски", "Узоры", 0xFFF5F2, 0xE3B9B5, "stripes"),
        PaperPreset("Mint Stripes", "Мятные полоски", "Узоры", 0xF4FCFA, 0xA5C7BF, "stripes"),
        PaperPreset("Peach Waves", "Персиковые волны", "Узоры", 0xFFF8F4, 0xE6BDB0, "waves"),
        PaperPreset("Sea Waves", "Морские волны", "Узоры", 0xF2FCFF, 0x9ABCCE, "waves"),
        PaperPreset("Confetti", "Нежное конфетти", "Узоры", 0xFFF8F5, 0xD5B3BC, "confetti"),
        PaperPreset("Tiny Hearts", "Маленькие сердечки", "Узоры", 0xFFF5F8, 0xD59BAE, "hearts"),
        PaperPreset("Soft Stars", "Маленькие звёзды", "Узоры", 0xFFF9EC, 0xDBBD86, "stars"),
        PaperPreset("Pink Bows", "Бантики", "Узоры", 0xFFF6F9, 0xD9ABC2, "bows"),
        PaperPreset("Blue Clouds", "Облачка", "Узоры", 0xF5FAFF, 0xB8CADD, "clouds"),
        PaperPreset("Leafy Journal", "Нежная ботаника", "Цветы и винтаж", 0xF7FAF3, 0xA4BAA4, "leaves"),
        PaperPreset("Daisy Frame", "Ромашковая рамка", "Цветы и винтаж", 0xFFFDF1, 0xD6BC85, "flowers"),
        PaperPreset("Rose Frame", "Розовая рамка", "Цветы и винтаж", 0xFFF8F7, 0xD6A8AD, "flowers"),
        PaperPreset("Blue Floral", "Голубые цветы", "Цветы и винтаж", 0xF8FCFF, 0xAEC9D8, "flowers"),
        PaperPreset("Lavender Floral", "Лавандовые цветы", "Цветы и винтаж", 0xF9F7FF, 0xB7AED5, "flowers"),
        PaperPreset("Lace Edge", "Кружевная рамка", "Цветы и винтаж", 0xFFF8F6, 0xD4BDC0, "lace"),
        PaperPreset("Botanical Header", "Цветочный верх", "Цветы и винтаж", 0xFAFDF7, 0x9DB79B, "botanical"),
        PaperPreset("Postcard Paper", "Старинное письмо", "Цветы и винтаж", 0xF8EEDC, 0xC5AB8B, "postcard"),
        PaperPreset("Kraft Journal", "Крафтовая бумага", "Цветы и винтаж", 0xE8D5BC, 0xAF997C, "kraft"),
        PaperPreset("Vintage Lace", "Винтажное кружево", "Цветы и винтаж", 0xF5E8DE, 0xBD9DA1, "lace"),
        PaperPreset("Scrapbook Frame", "Рамочки для фото", "Скрапбукинг", 0xFCF8EE, 0xB9AD9A, "polaroids"),
        PaperPreset("Washi Grid", "Бумажный скотч", "Скрапбукинг", 0xF9F6EF, 0xBAA8B9, "washi"),
        PaperPreset("Torn Paper", "Рваная бумага", "Скрапбукинг", 0xFFF7F0, 0xD6BBA8, "torn"),
        PaperPreset("Notebook Tabs", "Закладки по краю", "Скрапбукинг", 0xFFF9F4, 0xBDADA0, "tabs"),
        PaperPreset("Photo Diary", "Фотоистории", "Скрапбукинг", 0xFFF8F8, 0xD4B4B6, "photo"),
        PaperPreset("Memory Journal", "Дневник воспоминаний", "Скрапбукинг", 0xFCF8F4, 0xC7A6A1, "memory"),
        PaperPreset("Weekly Planner", "Неделя", "Планеры", 0xFFF9F5, 0xC5ADA4, "weekly"),
        PaperPreset("Monthly Calendar", "Календарь месяца", "Планеры", 0xFAF7FB, 0xBBAAC8, "calendar"),
        PaperPreset("Habit Tracker", "Трекер привычек", "Планеры", 0xF6FCF9, 0xA4BDA9, "tracker"),
        PaperPreset("Mood Tracker", "Настроение", "Планеры", 0xFFF9F5, 0xD3A8AC, "mood"),
        PaperPreset("Daily Schedule", "Расписание дня", "Планеры", 0xFBF9F5, 0xB6BAC1, "schedule"),
        PaperPreset("Budget Planner", "Бюджет", "Планеры", 0xF8F9F4, 0xB0B9A6, "budget"),
        PaperPreset("Project Planner", "План проекта", "Планеры", 0xF6FAFF, 0xA4BACD, "project"),
        PaperPreset("Goal Planner", "Мои цели", "Планеры", 0xFFF9F4, 0xCEB8A7, "goals"),
        PaperPreset("Meal Planner", "План питания", "Планеры", 0xFCF8F4, 0xD2B6A9, "meal"),
        PaperPreset("Study Notes", "Учебный конспект", "Учёба", 0xF8FAFF, 0xAEBACA, "study"),
        PaperPreset("Cornell Blue", "Корнелл синий", "Учёба", 0xF8FBFF, 0xAABFD5, "cornell"),
        PaperPreset("Class Notes", "Записи уроков", "Учёба", 0xFFFBF7, 0xC5B7AA, "class"),
        PaperPreset("Reading Log", "Дневник чтения", "Учёба", 0xF8FBF7, 0xA6B9AC, "reading"),
        PaperPreset("Mind Map", "Ментальная карта", "Учёба", 0xF8F6FF, 0xBBACCC, "mindmap"),
        PaperPreset("Storyboard", "Раскадровка", "Учёба", 0xFFFDF9, 0xB7B2A7, "storyboard"),
        PaperPreset("Music Notes", "Нотная бумага", "Учёба", 0xFFFDF8, 0xB4B6C6, "music"),
        PaperPreset("Recipe Book", "Книга рецептов", "Учёба", 0xFFF9F0, 0xCDB29F, "recipe"),
        PaperPreset("Morning Pages", "Утренние страницы", "Эстетика", 0xFFF9F5, 0xD0B4AC, "morning"),
        PaperPreset("Gratitude Journal", "Дневник благодарности", "Эстетика", 0xFFF6F8, 0xCCACB4, "gratitude"),
        PaperPreset("Dream Journal", "Дневник снов", "Эстетика", 0xF6F3FE, 0xB8ABD0, "dream"),
        PaperPreset("Rainy Day", "Дождливый день", "Эстетика", 0xF4F9FC, 0xA3BAC5, "rain"),
        PaperPreset("Golden Frame", "Тонкая золотая рамка", "Эстетика", 0xFFFBF4, 0xD5BC8A, "vintage"),
        PaperPreset("Blue Frame", "Голубая рамка", "Эстетика", 0xF6FAFE, 0xA6BECE, "vintage"),
        PaperPreset("Pink Frame", "Розовая рамка", "Эстетика", 0xFFF8F8, 0xCEADB2, "vintage"),
        PaperPreset("Little Letters", "Маленькие письма", "Эстетика", 0xFAF4EB, 0xC4AE9D, "postcard"),
        ]
        // Additional themed color-and-pattern editions. All saved IDs remain stable.
        let moods: [(String, UInt32, UInt32)] = [
            ("Романтика", 0xFFF1F5, 0xC99DAD),
            ("Pinterest", 0xFFF7F0, 0xC5A5A4),
            ("Винтаж", 0xF7EBDA, 0xB49B7E),
            ("Kawaii", 0xFFF1F6, 0xD6A3C4),
            ("Шалфей", 0xF1F6EE, 0x9DB69C),
            ("Лаванда", 0xF6F1FF, 0xB6A3CC),
            ("Кофейный", 0xFAEEE2, 0xBB947E),
            ("Морской", 0xF1FAFD, 0x96B8C7),
            ("Осенний", 0xFFF4E8, 0xBD9570),
            ("Зимний", 0xF5F9FF, 0xA3B8D5),
            ("Весенний", 0xF6FBEF, 0xA9BE8F),
            ("Ночной", 0x343A4D, 0xADB5CC)
        ]
        let styles = ["blank", "lines", "dots", "grid", "gingham", "stripes", "flowers", "lace", "vintage", "washi", "polaroids", "weekly", "cornell"]
        let names = ["Чистый", "Линейка", "Точки", "Клетка", "Клетчатый", "Полоски", "Цветы", "Кружево", "Рамка", "Скотч", "Фотостраница", "План недели", "Конспект"]
        for (index, mood) in moods.enumerated() {
            for (patternIndex, pattern) in styles.enumerated() where values.count < 240 {
                values.append(PaperPreset("StudioPaper_\(index * styles.count + patternIndex + 1)",
                    "\(mood.0) · \(names[patternIndex])", mood.0, mood.1, mood.2, pattern))
            }
        }
        // 48 painted, raster-backed seasonal sheets. Decorations are only on the margins.
        let painted: [(String, String, UInt32, UInt32)] = [
            ("Winter", "Зима", 0xF7FAFD, 0x8DA7C2),
            ("Spring", "Весна", 0xFFF9F6, 0xD5A5A9),
            ("Summer", "Лето", 0xFFFCF5, 0xCEB577),
            ("Autumn", "Осень", 0xFBF4EA, 0xAE7759),
            ("Magic", "Волшебство", 0xF9F3E8, 0x9D7B56),
            ("Vintage", "Винтажные письма", 0xF8F1E7, 0xA28571)
        ]
        for (key, category, background, ink) in painted {
            for variation in 1...8 {
                let title = "\(category) · акварель №\(variation)"
                values.append(PaperPreset(String(format: "Paper_%@_%02d", key, variation),
                                          title, category, background, ink, "painted"))
            }
        }
        return Studio6Catalog.papers + values
    }()
    static let categories = Array(Set(Studio6Catalog.themes.map(\.title))).sorted() + ["Все", "Для записей", "Цветная", "Узоры", "Цветы и винтаж", "Скрапбукинг", "Планеры", "Учёба", "Эстетика", "Романтика", "Pinterest", "Винтаж", "Kawaii", "Шалфей", "Лаванда", "Кофейный", "Морской", "Осенний", "Зимний", "Весенний", "Ночной", "Зима", "Весна", "Лето", "Осень", "Волшебство", "Винтажные письма"]
    static func find(_ id: String) -> PaperPreset? { all.first(where: { $0.id == id }) }
}

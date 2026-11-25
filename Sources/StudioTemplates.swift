import SwiftUI

struct StudioTheme {
    let key: String
    let title: String
}
enum Studio6Catalog {
    static let themes: [StudioTheme] = [
        .init(key: "Winter", title: "Зима"), .init(key: "Spring", title: "Весна"),
        .init(key: "Summer", title: "Лето"), .init(key: "Autumn", title: "Осень"),
        .init(key: "Magic", title: "Волшебная школа"), .init(key: "Fantasy", title: "Фэнтези"),
        .init(key: "Vintage", title: "Винтаж"), .init(key: "Library", title: "Старинная библиотека"),
        .init(key: "Romance", title: "Романтика"), .init(key: "Kawaii", title: "Kawaii"),
        .init(key: "Botanical", title: "Ботаника"), .init(key: "Minimal", title: "Минимализм"),
        .init(key: "Academia", title: "Dark Academia"), .init(key: "Cottage", title: "Cottagecore"),
        .init(key: "Ocean", title: "Морская тематика"), .init(key: "Cosmic", title: "Космическая эстетика")
    ]
    static let templates: [(String, String)] = [
        ("diary", "Личный дневник"), ("reading", "Читательский дневник"),
        ("recipe", "Кулинарная книга"), ("budget", "Финансовый планер"),
        ("daily", "Ежедневник"), ("weekly", "Недельный планер"),
        ("monthly", "Месячный планер"), ("habits", "Трекер привычек"),
        ("gratitude", "Дневник благодарности"), ("album", "Фотоальбом"),
        ("study", "Учебные конспекты"), ("season", "Сезонный дневник"),
        ("calendar", "Календарь"), ("goals", "Список целей"), ("creative", "Творческая страница")
    ]
    static let papers: [PaperPreset] = themes.flatMap { theme in
        let ruling = [("blank", "Чистый"), ("lines", "Линейка"), ("grid", "Клетка"), ("dots", "Точки")]
        return (ruling + templates).map { type, title in
            PaperPreset("Studio6_\(theme.key)_\(type)", "\(theme.title) · \(title)", theme.title,
                        0xFFF9EF, 0x766657, "s6:\(type)")
        }
    }
    static func art(for id: String) -> String? {
        guard id.hasPrefix("Studio6_") else { return nil }
        let parts = id.split(separator: "_")
        guard parts.count == 3 else { return nil }
        return "Studio6Art_\(parts[1])"
    }
}

/// Exact labels, lines and tables are drawn in code, above original raster artwork.
/// Every template supports handwriting and the existing editable text tool.
enum StudioTemplateRenderer {
    static func draw(_ kind: String, context: inout GraphicsContext, size: CGSize) {
        let sx = size.width / 700, sy = size.height / 952
        let color = Color(hex: 0x54483D)
        let left: CGFloat = 108, top: CGFloat = 132, width: CGFloat = 484, bottom: CGFloat = 775
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x*sx, y: y*sy, width: w*sx, height: h*sy)
        }
        func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ font: CGFloat = 12) {
            context.draw(Text(value).font(.system(size: font*sx, weight: .medium, design: .serif))
                .foregroundColor(color), at: CGPoint(x: x*sx, y: y*sy), anchor: .topLeading)
        }
        func line(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) {
            var p = Path(); p.move(to: CGPoint(x: x*sx,y: y*sy));p.addLine(to: CGPoint(x: (x+w)*sx,y:y*sy))
            context.stroke(p, with: .color(color.opacity(0.3)), lineWidth: 0.7*sx)
        }
        func box(_ label: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, lines: Bool = true) {
            context.fill(Path(roundedRect: rect(x,y,w,h), cornerRadius: 5*sx), with: .color(.white.opacity(0.56)))
            context.stroke(Path(roundedRect: rect(x,y,w,h), cornerRadius: 5*sx), with: .color(color.opacity(0.25)), lineWidth: 0.7*sx)
            text(label,x+10,y+9)
            if lines { for row in stride(from: y+48, through: y+h-12, by: 26) { line(x+10,row,w-20) } }
        }
        if kind == "blank" { return }
        if ["lines", "grid", "dots"].contains(kind) {
            if kind == "lines" || kind == "grid" {
                for y in stride(from: top, through: bottom, by: kind == "lines" ? 30.0 : 24.0) { line(left,y,width) }
            }
            if kind == "grid" {
                for x in stride(from: left, through: left+width, by: 24.0) {
                    var p=Path();p.move(to: CGPoint(x:x*sx,y:top*sy));p.addLine(to: CGPoint(x:x*sx,y:bottom*sy))
                    context.stroke(p,with:.color(color.opacity(0.2)),lineWidth:0.6*sx)
                }
            }
            if kind == "dots" {
                for y in stride(from: top, through: bottom, by: 24.0) {
                    for x in stride(from: left, through: left+width, by: 24.0) {
                        context.fill(Path(ellipseIn:rect(x,y,1.5,1.5)),with:.color(color.opacity(0.45)))
                    }
                }
            }
            return
        }
        let title = Studio6Catalog.templates.first { $0.0 == kind }?.1 ?? "Мои записи"
        text(title,left,top,22)
        text("Дата / период: ____________________",left,top+38)
        switch kind {
        case "weekly":
            let days=["Понедельник","Вторник","Среда","Четверг","Пятница","Суббота","Воскресенье","Главное на неделю"]
            for (i,day) in days.enumerated() { box(day,left+CGFloat(i%2)*248,205+CGFloat(i/2)*140,236,128) }
        case "monthly", "calendar":
            let days=["ПН","ВТ","СР","ЧТ","ПТ","СБ","ВС"]
            for (i,day) in days.enumerated() { text(day,left+CGFloat(i)*69+18,210) }
            for r in 0..<6 { for c in 0..<7 { box("",left+CGFloat(c)*69,240+CGFloat(r)*68,68,67,lines:false) } }
            box("Цели и важные даты",left,670,width,105)
        case "habits":
            text("Привычка и 31 день месяца",left,205)
            for r in 0..<5 {
                let y: CGFloat = 240+CGFloat(r)*103
                text("Привычка: _________________________",left,y)
                for n in 0..<31 {
                    let x=left+CGFloat(n%16)*30, yy=y+27+CGFloat(n/16)*27
                    context.stroke(Path(ellipseIn:rect(x,yy,22,22)),with:.color(color.opacity(0.5)),lineWidth:0.7*sx)
                    text("\(n+1)",x+5,yy+5,9)
                }
            }
        case "recipe":
            box("Блюдо · порции · время приготовления",left,205,width,85)
            box("Ингредиенты",left,305,width,165)
            box("Приготовление",left,485,width,220)
            box("Заметки",left,720,width,55,lines:false)
        case "reading":
            box("Название · автор · даты чтения",left,205,width,100)
            box("О чём книга",left,320,width,170)
            box("Цитаты и мысли",left,505,width,170)
            box("Моя оценка и впечатления",left,690,width,85)
        case "budget":
            box("Цель · сумма · срок",left,205,width,85)
            box("Доходы",left,305,236,145);box("Расходы",left+248,305,236,145)
            box("Дата          Категория                     Сумма",left,465,width,210)
            box("Итог · накопления · остаток",left,690,width,85)
        case "album":
            box("Фотография",left,205,width,250,lines:false)
            box("Фотография",left,470,236,190,lines:false)
            box("Фотография",left+248,470,236,190,lines:false)
            box("История этих фотографий",left,675,width,100)
        case "study":
            box("Тема и ключевые вопросы",left,205,width,85)
            box("Термины",left,305,145,340);box("Конспект",left+157,305,327,340)
            box("Выводы и вопросы",left,660,width,115)
        case "daily":
            box("Три главных дела",left,205,width,125)
            box("Время и планы",left,345,236,290);box("Задачи",left+248,345,236,290)
            box("Итоги дня",left,650,width,125)
        case "goals":
            for i in 0..<3 { box("Цель \(i+1) · шаги · срок · результат",left,205+CGFloat(i)*190,width,175) }
        case "gratitude":
            box("Сегодня я благодарна за…",left,205,width,220)
            box("Тёплые моменты",left,440,width,160)
            box("Что я хочу сохранить в памяти",left,615,width,160)
        case "season":
            box("Мои планы на сезон",left,205,width,170)
            box("Хочу попробовать",left,390,236,190);box("Уютные моменты",left+248,390,236,190)
            box("Впечатления и воспоминания",left,595,width,180)
        case "creative":
            box("Идеи · рисунки · коллаж",left,205,width,440,lines:false)
            box("Материалы и следующие шаги",left,660,width,115)
        default:
            box("Моё настроение и события дня",left,205,width,200)
            box("Мои мысли",left,420,width,230)
            box("Что хочется запомнить",left,665,width,110)
        }
    }
}

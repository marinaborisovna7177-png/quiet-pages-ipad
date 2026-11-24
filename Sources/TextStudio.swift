import SwiftUI
import UIKit
import CoreText
import UniformTypeIdentifiers

// Fonts are enumerated on the iPad, rather than bundled or downloaded.  This
// keeps every choice free, offline and compatible with the device's licenses.
private enum TypeLibrary {
    static let featured = [
        "AvenirNext-Regular", "AvenirNext-Medium", "AvenirNext-DemiBold",
        "AvenirNext-Italic", "Didot", "Didot-Italic", "Baskerville",
        "Baskerville-Italic", "Baskerville-Bold", "Georgia", "Georgia-Italic",
        "Georgia-Bold", "AmericanTypewriter", "AmericanTypewriter-Bold",
        "Palatino-Roman", "Palatino-Italic", "HoeflerText-Regular",
        "HoeflerText-Italic", "Futura-Medium", "Futura-CondensedMedium",
        "Optima-Regular", "Optima-Italic", "Optima-Bold", "GillSans",
        "GillSans-Italic", "HelveticaNeue", "HelveticaNeue-Light",
        "HelveticaNeue-Medium", "HelveticaNeue-Bold", "TimesNewRomanPSMT",
        "TimesNewRomanPS-ItalicMT", "CourierNewPSMT", "CourierNewPS-BoldMT",
        "TrebuchetMS", "TrebuchetMS-Italic", "ChalkboardSE-Regular",
        "ChalkboardSE-Bold", "MarkerFelt-Thin", "MarkerFelt-Wide",
        "Noteworthy-Light", "Noteworthy-Bold", "Papyrus"
    ]
    static var all: [String] {
        var found = Set<String>()
        for family in UIFont.familyNames {
            for name in UIFont.fontNames(forFamilyName: family) { found.insert(name) }
        }
        // Display only faces actually installed on this iPad.
        let pinned = featured.filter { found.contains($0) }
        let others = found.subtracting(Set(pinned)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return pinned + others
    }
}

// Optional fonts imported by the user are retained on-device and registered
// at each app launch.  No font files are bundled in distributable archives.
final class OfflineFontLibrary: ObservableObject {
    static let shared = OfflineFontLibrary()
    @Published private(set) var revision = 0
    private let manager = FileManager.default
    private let folder: URL

    private init() {
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        folder = base.appendingPathComponent("QuietPagesFonts", isDirectory: true)
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        if let urls = try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for url in urls where ["otf", "ttf"].contains(url.pathExtension.lowercased()) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    func importFont(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard ext == "ttf" || ext == "otf" else { return false }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let destination = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        do {
            try manager.copyItem(at: url, to: destination)
            guard CTFontManagerRegisterFontsForURL(destination as CFURL, .process, nil) else {
                try? manager.removeItem(at: destination)
                return false
            }
            revision += 1
            return true
        } catch { return false }
    }
}

struct ColorMood: Identifiable {
    let id: Int
    let title: String
    let shades: [UInt32]
}

enum ColorMoodCatalog {
    private static let names = ["Пудровая", "Клубничная", "Розовая", "Жемчужная", "Лавандовая", "Сиреневая",
        "Винтажная", "Кофейная", "Шоколадная", "Золотистая", "Осенняя", "Терракота",
        "Шалфейная", "Ботаническая", "Мятная", "Изумрудная", "Морская", "Небесная",
        "Голубая", "Зимняя", "Ночная", "Академия", "Минимализм", "Радужная"]
    private static let bases: [UInt32] = [0xD19AAE,0xDE7487,0xC77899,0xBBA7AA,0xB49BDA,0x957BAF,
        0xA38A78,0x96775C,0x755044,0xC6A362,0xB67A48,0xC77961,
        0x8EAB8F,0x648868,0x81BFAE,0x448A72,0x6CAAB4,0x8EB8D3,
        0x6E9DBE,0xA1BDDF,0x455579,0x644A6E,0x9F9A97,0xB880B4]
    static let all: [ColorMood] = names.enumerated().map { i, title in
        let base = bases[i]
        let red = Int((base >> 16) & 255), green = Int((base >> 8) & 255), blue = Int(base & 255)
        let shades: [UInt32] = (0..<10).map { step in
            let mix = Double(step) / 11.0
            let channel = { (c: Int) -> UInt32 in
                let result = Int(Double(c) * (0.38 + mix * 0.77) + 255 * max(0, 0.44 - mix * 0.63))
                return UInt32(max(0, min(255, result)))
            }
            return (channel(red) << 16) | (channel(green) << 8) | channel(blue)
        }
        return ColorMood(id: i, title: title, shades: shades)
    }
}

private enum StudioSwatches {
    static let colors: [UInt32] = [
        0x1E222B,0x3C3540,0x594852,0x746066,0x9D8A8B,0xFFFFFF,
        0xB13F54,0xE56F83,0xF6A4B5,0xF5CBD3,0xFFE2E8,0xEAD8E7,
        0x96415D,0xC46E96,0xCF96C3,0x9272AB,0xB3A3E9,0xDBD1FF,
        0xAA4937,0xE37F54,0xEDA775,0xF7D0AB,0xC69C73,0xEEDBBD,
        0xA87B18,0xD0AD35,0xF1D46B,0xFFE99A,0xEEE5C4,0xD5C7A5,
        0x1C6757,0x498C73,0x82B79F,0xB7D8AD,0xDDECCB,0xEAF5D7,
        0x285879,0x4D86B7,0x82AFD4,0xB1D2E9,0xD8EAFB,0xD7E5EB,
        0x436270,0x5C9299,0x7BC9C5,0xA5E6DA,0xC8EBE6,0xEFF9F5,
        0xBF6789,0xE7A9C1,0xEAC9D3,0xD8ADA9,0xBDA49C,0xF9EFE9
    ]
}

extension Color {
    // Converts the user's native iOS color picker choice to a persistent value.
    var hexValue: UInt32 {
        let native = UIColor(self)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 1
        if native.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (UInt32((r * 255).rounded()) << 16) |
                   (UInt32((g * 255).rounded()) << 8) |
                    UInt32((b * 255).rounded())
        }
        return 0x302E36
    }
}

struct TextStudioSheet: View {
    let existing: PageItem?
    let save: (String, PageTextStyle) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var fontLibrary = OfflineFontLibrary.shared
    @State private var showingFontImporter = false
    @State private var fontImportStatus: String?
    @State private var text: String
    @State private var style: PageTextStyle
    @State private var fontSearch = ""
    @State private var selectedTextPalette = 0
    @State private var section = 0
    @State private var newStyleName = "Мой стиль"
    @AppStorage("qpSavedTextStyles") private var savedTextStylesJSON = ""
    private var savedTextStyles: [String: PageTextStyle] {
        guard let data = savedTextStylesJSON.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: PageTextStyle].self, from: data)) ?? [:]
    }
    private func saveCurrentTextStyle() {
        let name = newStyleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var styles = savedTextStyles
        styles[name] = style
        if let json = try? JSONEncoder().encode(styles),
           let string = String(data: json, encoding: .utf8) {
            savedTextStylesJSON = string
        }
    }

    init(existing: PageItem?, initialStyle: PageTextStyle? = nil,
         save: @escaping (String, PageTextStyle) -> Void) {
        self.existing = existing
        self.save = save
        _text = State(initialValue: existing?.value ?? "")
        _style = State(initialValue: existing?.textStyle ?? initialStyle ?? PageTextStyle())
    }

    private let sections = ["Шрифты", "Цвета", "Оформление"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ЖИВАЯ ТИПОГРАФИКА")
                        .font(.system(size: 10, weight: .semibold)).tracking(2.1)
                        .foregroundStyle(AppPalette.rose)
                    TextField("Напиши что-нибудь красивое…", text: $text, axis: .vertical)
                        .font(.system(size: 15)).lineLimit(2...4)
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: 0xE4D6D2), lineWidth: 1))
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(hex: style.backgroundHex ?? 0xFFF8F5))
                        Text(text.isEmpty ? "Твои красивые слова…" : text)
                            .font(.custom(style.fontName, size: min(CGFloat(style.fontSize), 58)))
                            .tracking(style.letterSpacing)
                            .foregroundStyle(Color(hex: style.colorHex).opacity(style.opacity))
                            .multilineTextAlignment(style.alignment == "left" ? .leading : style.alignment == "right" ? .trailing : .center)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity)
                            .padding(17)
                    }
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: 0xE9DBD6)))
                    Picker("Раздел", selection: $section) {
                        ForEach(sections.indices, id: \.self) { i in Text(sections[i]).tag(i) }
                    }.pickerStyle(.segmented)
                }
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 13)
                ScrollView {
                    Group {
                        switch section {
                        case 0: fontSection
                        case 1: colorsSection
                        default: effectsSection
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 28)
                }
            }
            .background(AppPalette.parchment)
            .navigationTitle(existing == nil ? "Красивый текст" : "Изменить надпись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        let entered = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !entered.isEmpty { save(entered, style); dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .fileImporter(isPresented: $showingFontImporter, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                let successCount = urls.filter { fontLibrary.importFont($0) }.count
                fontImportStatus = successCount > 0
                    ? "Добавлено шрифтов: \(successCount). Они останутся на iPad и доступны офлайн."
                    : "Не удалось добавить файл. Нужен корректный шрифт TTF или OTF."
            case .failure:
                fontImportStatus = "Не удалось открыть выбранные файлы."
            }
        }
        .alert("Свои шрифты", isPresented: Binding(
            get: { fontImportStatus != nil },
            set: { if !$0 { fontImportStatus = nil } }
        )) { Button("OK") { fontImportStatus = nil } } message: { Text(fontImportStatus ?? "") }
    }

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Шрифты на твоём iPad")
                    .font(.system(size: 20, design: .serif))
                Spacer()
                Text("\(TypeLibrary.all.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.rose)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white, in: Capsule())
            }
            Text("Любой системный шрифт + свои TTF/OTF. Все доступны без интернета.")
                .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
            Button { showingFontImporter = true } label: {
                Label("Импортировать свои шрифты (.ttf / .otf)", systemImage: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .foregroundStyle(.white)
                    .background(AppPalette.midnight, in: RoundedRectangle(cornerRadius: 13))
            }.buttonStyle(.plain)
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(AppPalette.muted)
                TextField("Поиск шрифта", text: $fontSearch)
                    .textInputAutocapitalization(.never)
            }
            .padding(13).background(.white, in: RoundedRectangle(cornerRadius: 12))
            LazyVStack(spacing: 9) {
                ForEach(TypeLibrary.all.filter { fontSearch.isEmpty || $0.localizedCaseInsensitiveContains(fontSearch) }, id: \.self) { face in
                    Button {
                        style.fontName = face
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Красивые моменты · Aa Бб")
                                    .font(.custom(face, size: 22))
                                    .foregroundStyle(AppPalette.midnight).lineLimit(1)
                                Text(face).font(.system(size: 10)).foregroundStyle(AppPalette.muted)
                            }
                            Spacer()
                            if style.fontName == face {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppPalette.rose)
                            }
                        }
                        .padding(15).background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(style.fontName == face ? AppPalette.rose : Color(hex: 0xE8DDD6), lineWidth: style.fontName == face ? 2 : 1))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(.top, 12)
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Цвет текста").font(.system(size: 20, design: .serif))
            HStack(spacing: 13) {
                Circle().fill(Color(hex: style.colorHex))
                    .frame(width: 35, height: 35)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                Text(String(format: "#%06X", style.colorHex))
                    .font(.system(.subheadline, design: .monospaced))
                Spacer()
                ColorPicker("Любой оттенок", selection: Binding(
                    get: { Color(hex: style.colorHex) },
                    set: { style.colorHex = $0.hexValue }
                ), supportsOpacity: false)
            }
            .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 14))
            swatches { style.colorHex = $0 }
            Text("24 палитры для оформления").font(.system(size: 16, design: .serif))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ColorMoodCatalog.all) { mood in
                        Button(mood.title) { selectedTextPalette = mood.id }
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .foregroundStyle(selectedTextPalette == mood.id ? .white : AppPalette.midnight)
                            .background(selectedTextPalette == mood.id ? AppPalette.rose : Color.white, in: Capsule())
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 8)], spacing: 10) {
                ForEach(ColorMoodCatalog.all[selectedTextPalette].shades, id: \.self) { hex in
                    Button { style.colorHex = hex } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                    }.buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Прозрачность"); Spacer(); Text("\(Int(style.opacity * 100))%") }
                    .font(.system(size: 13))
                Slider(value: $style.opacity, in: 0.2...1)
                    .tint(AppPalette.rose)
            }
            .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 14))
        }.padding(.top, 14)
    }

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 19) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Размер текста").font(.system(size: 16, design: .serif))
                    Spacer()
                    Text("\(Int(style.fontSize)) pt").font(.system(size: 13, weight: .semibold))
                }
                Slider(value: $style.fontSize, in: 16...96, step: 1).tint(AppPalette.rose)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Расстояние между буквами"); Spacer(); Text(String(format: "%.1f", style.letterSpacing)) }
                    .font(.system(size: 13))
                Slider(value: $style.letterSpacing, in: -1...8, step: 0.5).tint(AppPalette.rose)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("Выравнивание").font(.system(size: 16, design: .serif))
                Picker("Выравнивание", selection: $style.alignment) {
                    Text("Слева").tag("left")
                    Text("По центру").tag("center")
                    Text("Справа").tag("right")
                }.pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Цветная подложка под текстом", isOn: Binding(
                    get: { style.backgroundHex != nil },
                    set: { style.backgroundHex = $0 ? 0xFFF1E8 : nil }
                )).tint(AppPalette.rose)
                if let hex = style.backgroundHex {
                    HStack {
                        ColorPicker("Цвет подложки", selection: Binding(
                            get: { Color(hex: hex) },
                            set: { style.backgroundHex = $0.hexValue }
                        ), supportsOpacity: false)
                    }
                    swatches { style.backgroundHex = $0 }
                }
            }
            .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 8) {
                Text("Быстрый стиль").font(.system(size: 18, design: .serif))
                HStack(spacing: 8) {
                    presetButton("Нежный") { style.fontName = existingFont("Didot", otherwise: "Georgia"); style.colorHex = 0x9A5668; style.backgroundHex = nil; style.fontSize = 38 }
                    presetButton("Винтаж") { style.fontName = existingFont("Baskerville", otherwise: "Georgia"); style.colorHex = 0x6B463D; style.backgroundHex = 0xF6E8D6; style.fontSize = 33 }
                    presetButton("Современный") { style.fontName = existingFont("AvenirNext-DemiBold", otherwise: "HelveticaNeue"); style.colorHex = 0x2E4055; style.backgroundHex = nil; style.fontSize = 28 }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Мои сохранённые стили").font(.system(size: 18, design: .serif))
                HStack {
                    TextField("Название стиля", text: $newStyleName).textFieldStyle(.roundedBorder)
                    Button("Сохранить ♡") { saveCurrentTextStyle() }
                        .buttonStyle(.borderedProminent).tint(AppPalette.rose)
                }
                ForEach(savedTextStyles.keys.sorted(), id: \.self) { name in
                    Button {
                        if let favorite = savedTextStyles[name] { style = favorite }
                    } label: {
                        HStack { Image(systemName: "heart.text.square"); Text(name); Spacer(); Image(systemName: "arrow.up.left") }
                            .font(.system(size: 12)).padding(11)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(.top, 17)
    }

    private func existingFont(_ wanted: String, otherwise fallback: String) -> String {
        TypeLibrary.all.contains(wanted) ? wanted : fallback
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 11).padding(.vertical, 12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 11))
        }.buttonStyle(.plain)
    }

    private func swatches(onPick: @escaping (UInt32) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 35), spacing: 11)], spacing: 11) {
            ForEach(StudioSwatches.colors, id: \.self) { hex in
                Button { onPick(hex) } label: {
                    Circle().fill(Color(hex: hex))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.05), radius: 2)
                }.buttonStyle(.plain).accessibilityLabel(String(format: "Цвет #%06X", hex))
            }
        }
    }
}

struct InkColorPalette: View {
    @Binding var color: Color
    @State private var selectedMood = 0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    Text("Многоцветная палитра")
                        .font(.system(size: 24, design: .serif))
                    Text("Выбери готовый оттенок или открой круг выбора любого цвета")
                        .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    ColorPicker("Смешать свой цвет", selection: $color, supportsOpacity: false)
                        .padding(17)
                        .background(.white, in: RoundedRectangle(cornerRadius: 15))
                    Text("24 тематические палитры").font(.system(size: 18, design: .serif))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ColorMoodCatalog.all) { mood in
                                Button(mood.title) { selectedMood = mood.id }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(selectedMood == mood.id ? .white : AppPalette.midnight)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(selectedMood == mood.id ? AppPalette.rose : Color.white, in: Capsule())
                            }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 12)], spacing: 14) {
                        ForEach(ColorMoodCatalog.all[selectedMood].shades, id: \.self) { hex in
                            Button { color = Color(hex: hex) } label: {
                                Circle().fill(Color(hex: hex))
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().stroke(Color(hex: 0xD3BEBB), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("Все базовые оттенки").font(.system(size: 17, design: .serif))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 12)], spacing: 14) {
                        ForEach(StudioSwatches.colors, id: \.self) { hex in
                            Button { color = Color(hex: hex) } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 38, height: 38)
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(24)
            }
            .background(AppPalette.parchment)
            .navigationTitle("Цвета ручки")
        }.presentationDetents([.medium, .large])
    }
}

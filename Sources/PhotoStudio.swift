import SwiftUI
import UIKit
import CoreImage

// Entirely local photo and user-sticker editing, no network or paid service.
struct PhotoWorkshopSheet: View {
    let source: UIImage
    let stickerMode: Bool
    let onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var brightness = 0.0
    @State private var contrast = 1.0
    @State private var saturation = 1.0
    @State private var filter = "Оригинал"
    @State private var crop = "Оригинал"
    @State private var removeLight = false
    @State private var rotation = 0

    private let filters = ["Оригинал", "Нежный", "Тёплый", "Винтаж", "Ч/Б"]
    private let crops = ["Оригинал", "Квадрат", "Круг"]

    private var preview: UIImage {
        LocalPhotoRenderer.render(source, maxDimension: 460, brightness: brightness,
                                  contrast: contrast, saturation: saturation,
                                  filter: filter, crop: crop, angle: rotation,
                                  removeLightBackground: removeLight)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(stickerMode ? "Собственный стикер ♡" : "Редактор фотографии ♡")
                        .font(.system(size: 25, design: .serif))
                        .foregroundStyle(AppPalette.midnight)
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0xEADFD9))
                        Image(uiImage: preview)
                            .resizable().scaledToFit()
                            .padding(16)
                    }
                    .frame(height: 315)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Фильтр").fontWeight(.semibold)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filters, id: \.self) { name in
                                    Button(name) { filter = name }
                                        .padding(.horizontal, 12).padding(.vertical, 9)
                                        .foregroundStyle(filter == name ? .white : AppPalette.midnight)
                                        .background(filter == name ? AppPalette.rose : Color.white, in: Capsule())
                                }
                            }
                        }
                        Text("Форма").fontWeight(.semibold)
                        Picker("Форма изображения", selection: $crop) {
                            ForEach(crops, id: \.self) { name in Text(name).tag(name) }
                        }.pickerStyle(.segmented)
                        HStack {
                            Text("Яркость")
                            Slider(value: $brightness, in: -0.45...0.45)
                        }
                        HStack {
                            Text("Контраст")
                            Slider(value: $contrast, in: 0.55...1.7)
                        }
                        HStack {
                            Text("Насыщенность")
                            Slider(value: $saturation, in: 0...1.8)
                        }
                        HStack(spacing: 12) {
                            Button { rotation = (rotation + 90) % 360 } label: {
                                Label("Повернуть", systemImage: "rotate.right")
                            }.buttonStyle(.bordered)
                            if stickerMode {
                                Toggle("Убрать светлый фон", isOn: $removeLight)
                                    .font(.system(size: 12))
                            }
                        }
                        if stickerMode && removeLight {
                            Text("Удаление светлого однотонного фона работает офлайн. Для сложного фона потребуется ручная вырезка.")
                                .font(.system(size: 11)).foregroundStyle(AppPalette.muted)
                        }
                    }
                    .font(.system(size: 13))
                    .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
                }
                .padding(22)
            }
            .background(AppPalette.parchment)
            .navigationTitle(stickerMode ? "Мастерская наклеек" : "Редактирование фото")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let result = LocalPhotoRenderer.render(source, maxDimension: 1450,
                            brightness: brightness, contrast: contrast, saturation: saturation,
                            filter: filter, crop: crop, angle: rotation,
                            removeLightBackground: removeLight)
                        if let bytes = result.pngData() { onSave(bytes); dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct WorkshopPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

enum LocalPhotoRenderer {
    static func render(_ source: UIImage, maxDimension: CGFloat, brightness: Double,
                       contrast: Double, saturation: Double, filter: String,
                       crop: String, angle: Int, removeLightBackground: Bool) -> UIImage {
        // Normalize orientation and downsample first: an iPad 6 must not decode several
        // full-resolution camera images for every slider movement.
        let factor = min(1.0, maxDimension / max(source.size.width, source.size.height, 1))
        let size = CGSize(width: max(1, source.size.width * factor),
                          height: max(1, source.size.height * factor))
        let form = UIGraphicsImageRendererFormat.default()
        form.scale = 1
        let normalized = UIGraphicsImageRenderer(size: size, format: form).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        guard var ci = CIImage(image: normalized) else { return source }
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(ci, forKey: kCIInputImageKey)
        controls?.setValue(brightness, forKey: kCIInputBrightnessKey)
        controls?.setValue(contrast, forKey: kCIInputContrastKey)
        controls?.setValue(saturation, forKey: kCIInputSaturationKey)
        ci = controls?.outputImage ?? ci
        let filterName: String?
        switch filter {
        case "Нежный": filterName = "CIPhotoEffectFade"
        case "Тёплый": filterName = "CIPhotoEffectTransfer"
        case "Винтаж": filterName = "CISepiaTone"
        case "Ч/Б": filterName = "CIPhotoEffectMono"
        default: filterName = nil
        }
        if let filterName, let effect = CIFilter(name: filterName) {
            effect.setValue(ci, forKey: kCIInputImageKey)
            if filterName == "CISepiaTone" { effect.setValue(0.7, forKey: kCIInputIntensityKey) }
            ci = effect.outputImage ?? ci
        }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return normalized }
        var image = UIImage(cgImage: cg)
        if removeLightBackground { image = removeNearlyWhite(image) }
        // Rotate clockwise by right angles. We always output a normalized PNG.
        if angle % 360 != 0 {
            let quarter = angle % 180 != 0
            let outputSize = CGSize(width: quarter ? image.size.height : image.size.width,
                                    height: quarter ? image.size.width : image.size.height)
            let original = image
            image = UIGraphicsImageRenderer(size: outputSize, format: form).image { renderer in
                let cgContext = renderer.cgContext
                cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
                cgContext.rotate(by: CGFloat(angle) * .pi / 180)
                original.draw(in: CGRect(x: -original.size.width / 2,
                                         y: -original.size.height / 2,
                                         width: original.size.width,
                                         height: original.size.height))
            }
        }
        guard crop != "Оригинал" else { return image }
        let edge = min(image.size.width, image.size.height)
        return UIGraphicsImageRenderer(size: CGSize(width: edge, height: edge), format: form).image { renderer in
            if crop == "Круг" {
                renderer.cgContext.addEllipse(in: CGRect(x: 0, y: 0, width: edge, height: edge))
                renderer.cgContext.clip()
            }
            image.draw(at: CGPoint(x: (edge - image.size.width) / 2,
                                   y: (edge - image.size.height) / 2))
        }
    }

    private static func removeNearlyWhite(_ source: UIImage) -> UIImage {
        guard let cg = source.cgImage else { return source }
        let width = cg.width, height = cg.height
        guard width > 0, height > 0, width * height < 4_000_000 else { return source }
        let rowSize = width * 4
        var pixels = [UInt8](repeating: 0, count: rowSize * height)
        guard let ctx = CGContext(data: &pixels, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: rowSize,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return source }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let low = min(pixels[i], pixels[i+1], pixels[i+2])
            if low > 240 {
                let opacity = UInt8(max(0, 255 - Int(low - 240) * 17))
                pixels[i+3] = min(pixels[i+3], opacity)
                // For a premultiplied alpha buffer RGB must not exceed A.
                for c in 0..<3 { pixels[i+c] = min(pixels[i+c], opacity) }
            }
        }
        guard let result = ctx.makeImage() else { return source }
        return UIImage(cgImage: result)
    }
}

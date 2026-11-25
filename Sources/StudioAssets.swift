import SwiftUI
import ImageIO
import UIKit

/// A dismissed thumbnail must not leave expensive decoding queued behind it.
private final class ImageDecodeCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}

/// File-backed ImageIO decoding avoids UIImage(named:) retaining a whole gallery.
@MainActor
final class StudioImageStore {
    static let shared = StudioImageStore()
    private let cache = NSCache<NSString, UIImage>()
    private let canvasCache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "quietpages.image.decode", qos: .userInitiated)
    private var warningObserver: NSObjectProtocol?
    private init() {
        cache.totalCostLimit = 12 * 1024 * 1024
        cache.countLimit = 96
        canvasCache.totalCostLimit = 24 * 1024 * 1024
        canvasCache.countLimit = 24
        warningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.cache.removeAllObjects(); self?.canvasCache.removeAllObjects() } }
    }
    static func url(_ id: String, thumbnail: Bool) -> URL? {
        guard !id.contains("/"), !id.contains("..") else { return nil }
        return Bundle.main.url(forResource: id, withExtension: "png",
            subdirectory: "StudioAssets/\(thumbnail ? "thumbnails" : "stickers")")
    }
    nonisolated static func decode(_ url: URL, pixels: Int) -> UIImage? {
        autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(url as CFURL,
                [kCGImageSourceShouldCache: false] as CFDictionary),
                let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: pixels,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }
    }
    func thumbnail(_ id: String) async -> UIImage? {
        if let image = cache.object(forKey: id as NSString) { return image }
        guard let url = Self.url(id, thumbnail: true) else { return nil }
        let cancellation = ImageDecodeCancellation()
        let image: UIImage? = await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                queue.async {
                    guard !cancellation.isCancelled else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: Self.decode(url, pixels: 192))
                }
            }
        }, onCancel: { cancellation.cancel() })
        guard !Task.isCancelled else { return nil }
        if let image {
            cache.setObject(image, forKey: id as NSString,
                            cost: (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0))
        }
        return image
    }
    static func local(_ url: URL, pixels: Int) -> UIImage? {
        let bounded = min(max(pixels, 64), 2048)
        let key = "local:\(bounded):\(url.path)" as NSString
        if let image = shared.canvasCache.object(forKey: key) { return image }
        guard let image = decode(url, pixels: bounded) else { return nil }
        shared.canvasCache.setObject(image, forKey: key,
            cost: (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0))
        return image
    }
    static func full(_ id: String) -> UIImage? {
        if let existing = shared.canvasCache.object(forKey: id as NSString) { return existing }
        guard let url = url(id, thumbnail: false), let image = decode(url, pixels: 1024) else { return nil }
        shared.canvasCache.setObject(image, forKey: id as NSString,
            cost: (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0))
        return image
    }
}

struct StickerThumbnail: View {
    let id: String
    @State private var image: UIImage?
    @State private var loading = true
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else if loading { Color.clear.overlay(ProgressView().controlSize(.small)) }
            else { Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary) }
        }
        .task(id: id) {
            image = nil
            loading = true
            let loaded = await StudioImageStore.shared.thumbnail(id)
            guard !Task.isCancelled else { return }
            image = loaded
            loading = false
        }
        .onDisappear { image = nil }
        .accessibilityHidden(true)
    }
}

struct StickerPreview: View {
    let entry: StickerEntry
    let insert: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let parts = StudioCompositionCatalog.components(for: entry.id) {
                    ZStack {
                        StickerThumbnail(id: parts.0).offset(x: -30, y: -30)
                        StickerThumbnail(id: parts.1).scaleEffect(0.65).offset(x: 50, y: 60)
                    }.frame(width: 300, height: 340)
                } else if let image = StudioImageStore.full(entry.id) {
                    Image(uiImage: image).resizable().scaledToFit().padding(30)
                }
                Button("Добавить на страницу") { dismiss(); insert() }
                    .buttonStyle(.borderedProminent).padding()
            }
            .background(AppPalette.parchment)
            .navigationTitle(entry.title)
            .toolbar { Button("Закрыть") { dismiss() } }
        }
    }
}

/// Two-finger scrolling is kept separate from single-finger/Pencil drawing.
struct StudioPageViewport<Content: View>: UIViewControllerRepresentable {
    let pageSize: CGSize
    @Binding var zoom: CGFloat
    let allowsZoom: Bool
    let content: Content
    init(pageSize: CGSize, zoom: Binding<CGFloat>, allowsZoom: Bool = true, @ViewBuilder content: () -> Content) {
        self.pageSize = pageSize; self._zoom = zoom; self.allowsZoom = allowsZoom; self.content = content()
    }
    func makeUIViewController(context: Context) -> StudioViewportController<Content> {
        StudioViewportController(content: content, size: pageSize, zoomChanged: { zoom = $0 })
    }
    func updateUIViewController(_ controller: StudioViewportController<Content>, context: Context) {
        controller.scroll.pinchGestureRecognizer?.isEnabled = allowsZoom
        controller.host.rootView = content
        controller.zoomChanged = { zoom = $0 }
        controller.update(size: pageSize, zoom: zoom)
    }
}
final class StudioViewportController<Content: View>: UIViewController, UIScrollViewDelegate {
    let host: UIHostingController<Content>
    let scroll = UIScrollView()
    var pageSize: CGSize
    var zoomChanged: (CGFloat) -> Void
    private var applyingUpdate = false
    init(content: Content, size: CGSize, zoomChanged: @escaping (CGFloat) -> Void) {
        host = UIHostingController(rootView: content)
        pageSize = size
        self.zoomChanged = zoomChanged
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(content:size:zoomChanged:)") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        scroll.backgroundColor = .clear
        scroll.delegate = self
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 3
        scroll.panGestureRecognizer.minimumNumberOfTouches = 2
        scroll.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        scroll.pinchGestureRecognizer?.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        scroll.delaysContentTouches = false
        scroll.canCancelContentTouches = true
        scroll.bouncesZoom = false
        view.addSubview(scroll)
        addChild(host)
        host.view.backgroundColor = .clear
        scroll.addSubview(host.view)
        host.didMove(toParent: self)
        update(size: pageSize, zoom: 1)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scroll.frame = view.bounds
        centerPage()
    }
    func update(size: CGSize, zoom: CGFloat) {
        guard isViewLoaded else { pageSize = size; return }
        applyingUpdate = true
        if pageSize != size || host.view.bounds.size != size {
            scroll.setZoomScale(1, animated: false)
            pageSize = size
            host.view.frame = CGRect(origin: .zero, size: size)
            scroll.contentSize = size
        }
        let clamped = min(max(zoom, 1), 3)
        if abs(scroll.zoomScale - clamped) > 0.005 { scroll.setZoomScale(clamped, animated: false) }
        applyingUpdate = false
        centerPage()
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { host.view }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerPage()
        if !applyingUpdate { zoomChanged(scrollView.zoomScale) }
    }
    private func centerPage() {
        let h = max(0, (scroll.bounds.width - scroll.contentSize.width) / 2)
        let v = max(0, (scroll.bounds.height - scroll.contentSize.height) / 2)
        scroll.contentInset = UIEdgeInsets(top: v, left: h, bottom: v, right: h)
    }
}

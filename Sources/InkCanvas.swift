import SwiftUI
import PencilKit

struct PenCanvas: UIViewRepresentable {
    let pageID: UUID
    let library: NotebookLibrary
    let ink: InkChoice
    let color: UIColor
    let strokeWidth: CGFloat
    let isEnabled: Bool
    let revision: Int
    var pencilOnly = false
    var constantWidth = false
    var canvasSize: CGSize = CGSize(width: 700, height: 952.38)

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView(frame: CGRect(origin: .zero, size: canvasSize))
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.drawingPolicy = .anyInput
        let c = context.coordinator
        c.canvas = canvas
        c.load(into: canvas)
        canvas.delegate = c
        c.observeLifecycle()
        c.applyConfiguration()
        return canvas
    }
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let c = context.coordinator
        if c.isUsingTool && c.loadedPage == pageID && c.loadedRevision == revision {
            c.pendingParent = self
            return
        }
        if c.loadedPage != pageID {
            c.flush()
            c.parent = self
            c.load(into: canvas)
        } else if c.loadedRevision != revision {
            // Undo/redo owns the new state; do not overwrite it with the old view.
            c.pendingSave?.cancel()
            c.dirty = false
            c.parent = self
            c.load(into: canvas)
        } else {
            if c.parent.canvasSize != canvasSize {
                c.flush()
                c.parent = self
                c.load(into: canvas)
            } else { c.parent = self }
        }
        c.applyConfiguration()
    }
    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.flush()
        canvas.delegate = nil
        coordinator.stopObserving()
    }
    private func configure(_ canvas: PKCanvasView) {
        canvas.isUserInteractionEnabled = isEnabled
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        let strokeWidth = strokeWidth.isFinite ? min(max(strokeWidth, 1), 14) : 3
        let selectedInk: InkChoice = constantWidth && (ink == .pen || ink == .fountainPen) ? .monoline : ink
        switch selectedInk {
        case .pen: canvas.tool = PKInkingTool(.pen, color: color, width: strokeWidth)
        case .fountainPen: canvas.tool = PKInkingTool(.fountainPen, color: color, width: strokeWidth)
        case .monoline: canvas.tool = PKInkingTool(.monoline, color: color, width: strokeWidth)
        case .pencil: canvas.tool = PKInkingTool(.pencil, color: color, width: strokeWidth)
        case .marker: canvas.tool = PKInkingTool(.marker, color: color, width: max(3, strokeWidth * 2))
        case .watercolor: canvas.tool = PKInkingTool(.watercolor, color: color, width: max(4, strokeWidth * 2))
        case .crayon: canvas.tool = PKInkingTool(.crayon, color: color, width: max(3, strokeWidth * 2))
        case .eraser: canvas.tool = PKEraserTool(.vector)
        case .pixelEraser: canvas.tool = PKEraserTool(.bitmap)
        case .lasso: canvas.tool = PKLassoTool()
        case .decorative: canvas.tool = PKInkingTool(.pen, color: color, width: strokeWidth)
        }
    }
    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PenCanvas
        var pendingParent: PenCanvas?
        weak var canvas: PKCanvasView?
        var pendingSave: DispatchWorkItem?
        var suppressChanges = false
        var dirty = false
        private(set) var isUsingTool = false
        private var appliedSettings: ToolSettings?
        private struct ToolSettings: Equatable {
            let ink: InkChoice
            let color: UIColor
            let width: CGFloat
            let enabled: Bool
            let pencilOnly: Bool
            let constantWidth: Bool
        }
        var loadedPage: UUID?
        var loadedRevision = -1
        private var observer: NSObjectProtocol?
        init(_ parent: PenCanvas) { self.parent = parent }
        func applyConfiguration() {
            guard let canvas, !isUsingTool else { return }
            let settings = ToolSettings(ink: parent.ink, color: parent.color,
                width: parent.strokeWidth, enabled: parent.isEnabled,
                pencilOnly: parent.pencilOnly, constantWidth: parent.constantWidth)
            guard settings != appliedSettings else { return }
            parent.configure(canvas)
            appliedSettings = settings
        }
        func observeLifecycle() {
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in MainActor.assumeIsolated { self?.flush() } }
        }
        func stopObserving() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
        }
        func load(into canvas: PKCanvasView) {
            pendingSave?.cancel()
            pendingSave = nil
            isUsingTool = false
            pendingParent = nil
            suppressChanges = true
            let stored = parent.library.inkCanvasSize(page: parent.pageID) ?? parent.canvasSize
            let scale = parent.canvasSize.width / max(stored.width, 1)
            canvas.drawing = parent.library.drawing(for: parent.pageID)
                .transformed(using: CGAffineTransform(scaleX: scale, y: scale))
            loadedPage = parent.pageID
            loadedRevision = parent.revision
            dirty = false
            suppressChanges = false
        }
        func flush() {
            pendingSave?.cancel()
            pendingSave = nil
            guard dirty, let canvas, let page = loadedPage else { return }
            dirty = false
            parent.library.setInkCanvasSize(parent.canvasSize, page: page)
            let stored = parent.library.inkCanvasSize(page: page) ?? parent.canvasSize
            let scale = stored.width / max(parent.canvasSize.width, 1)
            let drawing = canvas.drawing.transformed(using: CGAffineTransform(scaleX: scale, y: scale))
            parent.library.saveDrawing(drawing, for: page)
        }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !suppressChanges else { return }
            dirty = true
            pendingSave?.cancel()
            // Never serialize the drawing or publish library updates mid-stroke.
            guard !isUsingTool else { return }
            let work = DispatchWorkItem { [weak self] in self?.flush() }
            pendingSave = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            pendingSave?.cancel()
            pendingSave = nil
            isUsingTool = true
        }
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            isUsingTool = false
            // PencilKit may deliver the final drawing-change callback after this one.
            flush()
            if let next = pendingParent {
                let sizeChanged = next.canvasSize != parent.canvasSize
                parent = next
                pendingParent = nil
                if sizeChanged { load(into: canvasView) }
            }
            applyConfiguration()
        }
    }
}

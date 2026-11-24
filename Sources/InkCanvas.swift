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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView(frame: .zero)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.drawingPolicy = .anyInput
        canvas.isUserInteractionEnabled = isEnabled
        context.coordinator.suppressChanges = true
        canvas.delegate = context.coordinator
        canvas.drawing = library.drawing(for: pageID)
        context.coordinator.suppressChanges = false
        context.coordinator.loadedPage = pageID
        context.coordinator.loadedRevision = revision
        configure(canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.loadedPage != pageID || coordinator.loadedRevision != revision {
            coordinator.pendingSave?.cancel()
            coordinator.suppressChanges = true
            canvas.drawing = library.drawing(for: pageID)
            coordinator.loadedPage = pageID
            coordinator.loadedRevision = revision
            coordinator.suppressChanges = false
        }
        configure(canvas)
    }

    private func configure(_ canvas: PKCanvasView) {
        canvas.isUserInteractionEnabled = isEnabled
        switch ink {
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

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PenCanvas
        var pendingSave: DispatchWorkItem?
        var suppressChanges = false
        var loadedPage: UUID?
        var loadedRevision = -1
        init(_ parent: PenCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !suppressChanges else { return }
            pendingSave?.cancel()
            let drawing = canvasView.drawing
            let page = parent.pageID
            let store = parent.library
            let work = DispatchWorkItem {
                Task { @MainActor in store.saveDrawing(drawing, for: page) }
            }
            pendingSave = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }
}

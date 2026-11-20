import SwiftUI
import PencilKit

struct PenCanvas: UIViewRepresentable {
    let pageID: UUID
    let library: NotebookLibrary
    let ink: InkChoice
    let color: UIColor
    let strokeWidth: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView(frame: .zero)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.drawing = library.drawing(for: pageID)
        configure(canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        configure(canvas)
    }

    private func configure(_ canvas: PKCanvasView) {
        switch ink {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: color, width: strokeWidth)
        case .pencil:
            canvas.tool = PKInkingTool(.pencil, color: color, width: strokeWidth)
        case .marker:
            canvas.tool = PKInkingTool(.marker, color: color.withAlphaComponent(0.45), width: max(10, strokeWidth * 4))
        case .eraser:
            canvas.tool = PKEraserTool(.vector)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PenCanvas
        private var pendingSave: DispatchWorkItem?
        init(_ parent: PenCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
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

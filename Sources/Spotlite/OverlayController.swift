import AppKit

@MainActor
final class OverlayController {
    let settings = AnnotationSettings()
    var onSettingsChanged: (() -> Void)?
    var onDrawingStateChanged: ((Bool) -> Void)?

    var isDrawingEnabled = false {
        didSet {
            guard oldValue != isDrawingEnabled else { return }
            isDrawingEnabled ? showDrawingOverlays() : hideDrawingOverlays()
            onDrawingStateChanged?(isDrawingEnabled)
        }
    }

    private var overlays: [DrawingOverlayWindow] = []

    func rebuildOverlaysIfNeeded() {
        let wasDrawingEnabled = isDrawingEnabled
        destroyOverlays()

        if wasDrawingEnabled {
            showDrawingOverlays()
        }
    }

    func clearAnnotations() {
        for canvas in canvases {
            canvas.clearAnnotations()
        }
    }

    func undoLastAnnotation() {
        let mostRecentCanvas = canvases
            .compactMap { canvas -> (CanvasOverlayView, Date)? in
                guard let date = canvas.lastAnnotationDate else { return nil }
                return (canvas, date)
            }
            .max { $0.1 < $1.1 }?
            .0

        _ = mostRecentCanvas?.undoLastAnnotation()
    }

    func setAutoEraseDelay(_ delay: AnnotationAutoEraseDelay) {
        settings.autoEraseDelay = delay
        refreshCanvasSettings()
    }

    func refreshCanvasesForSettingsChange() {
        refreshCanvasSettings()
    }

    private var canvases: [CanvasOverlayView] {
        overlays.compactMap { $0.contentView as? CanvasOverlayView }
    }

    private func refreshCanvasSettings() {
        for canvas in canvases {
            canvas.annotationSettingsDidChange()
        }
    }

    private func showDrawingOverlays() {
        if overlays.isEmpty {
            overlays = NSScreen.screens.map { screen in
                let overlayFrame = screen.spotliteOverlayFrame
                let canvas = CanvasOverlayView(
                    frame: NSRect(origin: .zero, size: overlayFrame.size),
                    settings: settings
                )
                canvas.onEscape = { [weak self] in
                    self?.isDrawingEnabled = false
                }
                canvas.onClearAnnotations = { [weak self] in
                    self?.clearAnnotations()
                }
                canvas.onUndoAnnotation = { [weak self] in
                    self?.undoLastAnnotation()
                }
                canvas.onSettingsChangedFromKeyboard = { [weak self] in
                    self?.onSettingsChanged?()
                }

                return DrawingOverlayWindow(screen: screen, contentView: canvas)
            }
        }

        for overlay in overlays {
            overlay.ignoresMouseEvents = false
            overlay.orderFrontRegardless()
        }
    }

    private func hideDrawingOverlays() {
        for overlay in overlays {
            overlay.orderOut(nil)
        }
    }

    private func destroyOverlays() {
        for overlay in overlays {
            if let canvas = overlay.contentView as? CanvasOverlayView {
                canvas.prepareForClose()
            }
            overlay.orderOut(nil)
            overlay.close()
        }
        overlays.removeAll()
    }
}

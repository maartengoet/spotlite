import AppKit

final class DrawingOverlayWindow: NSPanel {
    init(screen: NSScreen, contentView: CanvasOverlayView) {
        let overlayFrame = screen.spotliteOverlayFrame

        super.init(
            contentRect: overlayFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView
        setFrame(overlayFrame, display: true)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isFloatingPanel = true
        level = .screenSaver
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .stationary
        ]
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

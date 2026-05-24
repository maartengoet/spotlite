import AppKit

final class ClickIndicatorWindow: NSPanel {
    init(screen: NSScreen, contentView: ClickIndicatorView) {
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
        ignoresMouseEvents = true
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
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

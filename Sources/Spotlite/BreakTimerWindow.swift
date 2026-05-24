import AppKit

final class BreakTimerWindow: NSPanel {
    init(screen: NSScreen, contentView: BreakTimerView) {
        let frame = screen.frame

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView
        setFrame(frame, display: true)
        backgroundColor = .black
        isOpaque = true
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

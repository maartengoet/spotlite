import AppKit

final class CursorFocusView: NSView {
    var mode: CursorFocusMode = .off {
        didSet { needsDisplay = true }
    }

    var spotlightRadius: CGFloat = 115 {
        didSet { needsDisplay = true }
    }

    private let screenFrame: NSRect
    private let fullScreenFrame: NSRect
    private var cursorPoint: CGPoint?
    private var typingFocusRect: CGRect?
    private var typingFocusContextRect: CGRect?
    private var typingFocusKind: TypingFocusKind?

    override var isFlipped: Bool { true }

    init(screen: NSScreen) {
        let overlayFrame = screen.spotliteOverlayFrame
        screenFrame = overlayFrame
        fullScreenFrame = screen.frame
        super.init(frame: NSRect(origin: .zero, size: overlayFrame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(mouseLocation: CGPoint) {
        guard screenFrame.contains(mouseLocation) else {
            cursorPoint = nil
            isHidden = true
            return
        }

        isHidden = false
        cursorPoint = CGPoint(
            x: mouseLocation.x - screenFrame.minX,
            y: screenFrame.maxY - mouseLocation.y
        )
        typingFocusRect = nil
        typingFocusContextRect = nil
        typingFocusKind = nil
        needsDisplay = true
    }

    func update(typingTarget: TypingFocusTarget?) {
        guard let typingTarget,
              let targetRect = localRect(forScreenRect: typingTarget.rect) else {
            cursorPoint = nil
            typingFocusRect = nil
            typingFocusContextRect = nil
            typingFocusKind = nil
            isHidden = true
            needsDisplay = true
            return
        }

        isHidden = false
        cursorPoint = nil
        typingFocusRect = targetRect
        typingFocusContextRect = typingTarget.contextRect.flatMap { localRect(forScreenRect: $0) }
        typingFocusKind = typingTarget.kind
        needsDisplay = true
    }

    func clearFocus() {
        cursorPoint = nil
        typingFocusRect = nil
        typingFocusContextRect = nil
        typingFocusKind = nil
        isHidden = true
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard mode != .off else { return }

        switch mode {
        case .off:
            break
        case .typingFocus:
            guard let typingFocusRect, let typingFocusKind else { return }
            drawTypingFocus(rect: typingFocusRect, contextRect: typingFocusContextRect, kind: typingFocusKind)
        case .spotlight:
            guard let cursorPoint else { return }
            drawSpotlight(at: cursorPoint)
        }
    }

    private func drawTypingFocus(rect: CGRect, contextRect: CGRect?, kind: TypingFocusKind) {
        switch kind {
        case .caret:
            drawCaretFocus(rect: rect, contextRect: contextRect)
        case .selection:
            drawSelectionFocus(rect: rect)
        }
    }

    private func drawSpotlight(at point: CGPoint) {
        NSColor.black.withAlphaComponent(0.48).setFill()
        bounds.fill()

        let radius = spotlightRadius
        let cutoutRect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        context.compositingOperation = .clear
        NSBezierPath(ovalIn: cutoutRect).fill()
        context.restoreGraphicsState()

        NSColor.systemYellow.withAlphaComponent(0.9).setStroke()
        let ring = NSBezierPath(ovalIn: cutoutRect.insetBy(dx: 2, dy: 2))
        ring.lineWidth = 3
        ring.stroke()
    }

    private func drawCaretFocus(rect: CGRect, contextRect: CGRect?) {
        let caretRect = CGRect(
            x: rect.midX - 2,
            y: rect.minY - 4,
            width: 4,
            height: rect.height + 8
        )

        let lineHighlight = contextHighlightRect(for: caretRect, contextRect: contextRect)

        NSColor.systemYellow.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: lineHighlight, xRadius: 8, yRadius: 8).fill()

        NSColor.systemYellow.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: caretRect.insetBy(dx: -8, dy: -6), xRadius: 9, yRadius: 9).fill()

        NSColor.systemYellow.setFill()
        NSBezierPath(roundedRect: caretRect, xRadius: 2, yRadius: 2).fill()
    }

    private func contextHighlightRect(for caretRect: CGRect, contextRect: CGRect?) -> CGRect {
        if let contextRect {
            let paddedContext = contextRect.standardized.insetBy(dx: -5, dy: -3)
            let minX = max(0, min(paddedContext.minX, caretRect.minX - 8))
            let maxX = min(bounds.width, caretRect.maxX + 10)
            let height = min(max(max(paddedContext.height, caretRect.height + 4), 22), 34)
            let midY = caretRect.midY

            return CGRect(
                x: minX,
                y: max(0, midY - height / 2),
                width: max(12, maxX - minX),
                height: height
            )
        }

        let minX = max(0, caretRect.minX - 220)
        let maxX = min(bounds.width, caretRect.maxX + 10)
        return CGRect(
            x: minX,
            y: max(0, caretRect.midY - 13),
            width: max(12, maxX - minX),
            height: 26
        )
    }

    private func drawSelectionFocus(rect: CGRect) {
        let paddedRect = rect.insetBy(dx: -6, dy: -4)
        NSColor.systemYellow.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect: paddedRect, xRadius: 6, yRadius: 6).fill()

        NSColor.systemYellow.withAlphaComponent(0.9).setStroke()
        let outline = NSBezierPath(roundedRect: paddedRect, xRadius: 6, yRadius: 6)
        outline.lineWidth = 2
        outline.stroke()
    }

    private func localRect(forScreenRect screenRect: CGRect) -> CGRect? {
        let accessibilityTopInset = fullScreenFrame.maxY - screenFrame.maxY
        let accessibilityRect = CGRect(
            x: screenRect.minX - screenFrame.minX,
            y: screenRect.minY - accessibilityTopInset,
            width: screenRect.width,
            height: screenRect.height
        )

        if bounds.intersects(accessibilityRect) {
            return accessibilityRect.intersection(bounds)
        }

        let directRect = CGRect(
            x: screenRect.minX - screenFrame.minX,
            y: screenFrame.maxY - screenRect.maxY,
            width: screenRect.width,
            height: screenRect.height
        )

        if bounds.intersects(directRect) {
            return directRect.intersection(bounds)
        }

        return nil
    }
}

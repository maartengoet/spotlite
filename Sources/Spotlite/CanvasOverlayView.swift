import AppKit
import Carbon

final class CanvasOverlayView: NSView {
    var onEscape: (() -> Void)?
    var onClearAnnotations: (() -> Void)?
    var onUndoAnnotation: (() -> Void)?
    var onSettingsChangedFromKeyboard: (() -> Void)?

    let settings: AnnotationSettings

    private var annotations: [AnnotationElement] = []
    private var activeAnnotation: AnnotationElement?
    private var activeTool: AnnotationTool?
    private var textEditor: TextAnnotationField?
    private var autoEraseTimer: Timer?

    var lastAnnotationDate: Date? {
        annotations.last?.createdAt
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    init(frame frameRect: NSRect, settings: AnnotationSettings) {
        self.settings = settings
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func annotationSettingsDidChange() {
        refreshAutoEraseTimer()
        needsDisplay = true
    }

    func prepareForClose() {
        cancelTextEditor()
        stopAutoEraseTimer()
    }

    func clearAnnotations() {
        cancelTextEditor()
        annotations.removeAll()
        activeAnnotation = nil
        refreshAutoEraseTimer()
        needsDisplay = true
    }

    @discardableResult
    func undoLastAnnotation() -> Bool {
        if textEditor != nil {
            cancelTextEditor()
            return true
        }

        guard !annotations.isEmpty else { return false }
        annotations.removeLast()
        refreshAutoEraseTimer()
        needsDisplay = true
        return true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)

        let point = convert(event.locationInWindow, from: nil)
        let tool = resolvedTool(for: event)

        if tool == .text {
            beginTextAnnotation(at: point)
            return
        }

        activeTool = tool
        activeAnnotation = AnnotationElement(
            shape: initialShape(for: tool, at: point),
            style: style(for: tool),
            createdAt: Date()
        )
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let tool = activeTool, var annotation = activeAnnotation else { return }
        guard tool != .text else { return }

        let point = convert(event.locationInWindow, from: nil)
        annotation.shape = updatedShape(annotation.shape, for: tool, currentPoint: point)
        activeAnnotation = annotation
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard var activeAnnotation else { return }
        activeAnnotation.createdAt = Date()
        annotations.append(activeAnnotation)
        self.activeAnnotation = nil
        activeTool = nil
        refreshAutoEraseTimer()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape {
            onEscape?()
            return
        }

        guard let key = event.charactersIgnoringModifiers?.lowercased() else {
            super.keyDown(with: event)
            return
        }

        switch key {
        case "1", "2", "3", "4", "5", "6":
            selectPaletteColor(for: key, asHighlighter: event.modifierFlags.contains(.shift))
        case "e":
            onClearAnnotations?()
        case "z":
            onUndoAnnotation?()
        case "p":
            settings.tool = .pen
            onSettingsChangedFromKeyboard?()
        case "h":
            settings.tool = .highlighter
            onSettingsChangedFromKeyboard?()
        case "n":
            settings.tool = .text
            onSettingsChangedFromKeyboard?()
        case "l":
            settings.tool = .line
            onSettingsChangedFromKeyboard?()
        case "a":
            settings.tool = .arrow
            onSettingsChangedFromKeyboard?()
        case "r":
            settings.tool = .rectangle
            onSettingsChangedFromKeyboard?()
        case "o":
            settings.tool = .ellipse
            onSettingsChangedFromKeyboard?()
        case "w":
            settings.background = .whiteboard
            onSettingsChangedFromKeyboard?()
        case "k":
            settings.background = .blackboard
            onSettingsChangedFromKeyboard?()
        case "t":
            settings.background = .transparent
            onSettingsChangedFromKeyboard?()
        default:
            super.keyDown(with: event)
        }
    }

    private func selectPaletteColor(for key: String, asHighlighter: Bool) {
        guard let number = Int(key) else { return }
        let index = number - 1
        guard AnnotationColor.allCases.indices.contains(index) else { return }

        settings.color = AnnotationColor.allCases[index]
        settings.tool = asHighlighter ? .highlighter : .pen
        onSettingsChangedFromKeyboard?()
    }

    private func beginTextAnnotation(at point: CGPoint) {
        cancelTextEditor()

        let origin = clampedTextOrigin(for: point)
        let editor = TextAnnotationField(
            frame: CGRect(x: origin.x, y: origin.y, width: 340, height: max(settings.textSize + 16, 44))
        )
        editor.font = .systemFont(ofSize: settings.textSize, weight: .semibold)
        editor.textColor = settings.color.nsColor
        editor.placeholderString = "Text"
        editor.onCommit = { [weak self, weak editor] text in
            guard let self, let editor else { return }
            self.commitTextAnnotation(text, from: editor)
        }
        editor.onCancel = { [weak self] in
            self?.cancelTextEditor()
        }

        addSubview(editor)
        textEditor = editor
        window?.makeFirstResponder(editor)
    }

    private func clampedTextOrigin(for point: CGPoint) -> CGPoint {
        let editorWidth: CGFloat = 340
        let editorHeight = max(settings.textSize + 16, 44)
        return CGPoint(
            x: min(max(point.x, 12), max(12, bounds.maxX - editorWidth - 12)),
            y: min(max(point.y, 12), max(12, bounds.maxY - editorHeight - 12))
        )
    }

    private func commitTextAnnotation(_ text: String, from editor: TextAnnotationField) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let origin = editor.frame.origin
        cancelTextEditor()

        guard !trimmed.isEmpty else { return }

        annotations.append(
            AnnotationElement(
                shape: .text(trimmed, at: origin),
                style: style(for: .text),
                createdAt: Date()
            )
        )
        refreshAutoEraseTimer()
        needsDisplay = true
    }

    private func cancelTextEditor() {
        textEditor?.removeFromSuperview()
        textEditor = nil
        window?.makeFirstResponder(self)
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            if settings.tool == .text {
                event.scrollingDeltaY > 0 ? settings.increaseTextSize() : settings.decreaseTextSize()
            } else {
                event.scrollingDeltaY > 0 ? settings.increaseLineWidth() : settings.decreaseLineWidth()
            }
            onSettingsChangedFromKeyboard?()
            return
        }

        super.scrollWheel(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        drawBackground()

        for annotation in annotations {
            draw(annotation, opacity: opacity(for: annotation))
        }

        if let activeAnnotation {
            draw(activeAnnotation, opacity: 1)
        }
    }

    private func refreshAutoEraseTimer() {
        guard settings.autoEraseDelay.seconds != nil, !annotations.isEmpty else {
            stopAutoEraseTimer()
            return
        }

        guard autoEraseTimer == nil else { return }

        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.expireAutoEraseAnnotations()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoEraseTimer = timer
    }

    private func stopAutoEraseTimer() {
        autoEraseTimer?.invalidate()
        autoEraseTimer = nil
    }

    private func expireAutoEraseAnnotations() {
        guard let delay = settings.autoEraseDelay.seconds else {
            stopAutoEraseTimer()
            needsDisplay = true
            return
        }

        let now = Date()
        let countBefore = annotations.count
        annotations.removeAll { now.timeIntervalSince($0.createdAt) >= delay }

        if annotations.count != countBefore {
            needsDisplay = true
        }

        if annotations.isEmpty {
            stopAutoEraseTimer()
        } else {
            needsDisplay = true
        }
    }

    private func opacity(for annotation: AnnotationElement) -> CGFloat {
        guard let delay = settings.autoEraseDelay.seconds else { return 1 }

        let remaining = delay - Date().timeIntervalSince(annotation.createdAt)
        guard remaining > 0 else { return 0 }

        let fadeWindow = min(delay, 0.75)
        return CGFloat(min(1, max(0, remaining / fadeWindow)))
    }

    private func drawBackground() {
        switch settings.background {
        case .transparent:
            break
        case .whiteboard:
            NSColor.white.withAlphaComponent(0.96).setFill()
            bounds.fill()
        case .blackboard:
            NSColor.black.withAlphaComponent(0.92).setFill()
            bounds.fill()
        }
    }

    private func resolvedTool(for event: NSEvent) -> AnnotationTool {
        if event.modifierFlags.contains(.control), event.modifierFlags.contains(.shift) {
            return .arrow
        }

        if event.modifierFlags.contains(.control) {
            return .rectangle
        }

        if event.modifierFlags.contains(.option) {
            return .ellipse
        }

        if event.modifierFlags.contains(.shift) {
            return .line
        }

        return settings.tool
    }

    private func style(for tool: AnnotationTool) -> AnnotationStyle {
        let width = tool == .highlighter ? settings.lineWidth * 1.6 : settings.lineWidth
        let alpha: CGFloat = tool == .highlighter ? 0.55 : 0.95

        return AnnotationStyle(
            color: settings.color.nsColor.withAlphaComponent(alpha),
            lineWidth: width,
            textSize: settings.textSize
        )
    }

    private func initialShape(for tool: AnnotationTool, at point: CGPoint) -> AnnotationShape {
        switch tool {
        case .pen, .highlighter:
            return .freehand([point])
        case .text:
            return .text("", at: point)
        case .line:
            return .line(start: point, end: point)
        case .arrow:
            return .arrow(start: point, end: point)
        case .rectangle:
            return .rectangle(CGRect(origin: point, size: .zero))
        case .ellipse:
            return .ellipse(CGRect(origin: point, size: .zero))
        }
    }

    private func updatedShape(_ shape: AnnotationShape, for tool: AnnotationTool, currentPoint: CGPoint) -> AnnotationShape {
        switch shape {
        case .freehand(var points):
            points.append(currentPoint)
            return .freehand(points)
        case .text:
            return shape
        case .line(let start, _):
            return .line(start: start, end: currentPoint)
        case .arrow(let start, _):
            return .arrow(start: start, end: currentPoint)
        case .rectangle(let rect):
            return .rectangle(rectFrom(origin: rect.origin, to: currentPoint))
        case .ellipse(let rect):
            return .ellipse(rectFrom(origin: rect.origin, to: currentPoint))
        }
    }

    private func rectFrom(origin: CGPoint, to point: CGPoint) -> CGRect {
        CGRect(
            x: min(origin.x, point.x),
            y: min(origin.y, point.y),
            width: abs(point.x - origin.x),
            height: abs(point.y - origin.y)
        )
    }

    private func draw(_ annotation: AnnotationElement, opacity: CGFloat) {
        guard opacity > 0 else { return }

        annotation.style.color.withAlphaComponent(annotation.style.color.alphaComponent * opacity).setStroke()

        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = annotation.style.lineWidth

        switch annotation.shape {
        case .freehand(let points):
            guard points.count > 1 else { return }
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.line(to: point)
            }
            path.stroke()
        case .text(let text, let origin):
            drawText(text, at: origin, style: annotation.style, opacity: opacity)
        case .line(let start, let end):
            path.move(to: start)
            path.line(to: end)
            path.stroke()
        case .arrow(let start, let end):
            drawArrow(from: start, to: end, style: annotation.style, opacity: opacity)
        case .rectangle(let rect):
            path.appendRect(rect)
            path.stroke()
        case .ellipse(let rect):
            path.appendOval(in: rect)
            path.stroke()
        }
    }

    private func drawText(_ text: String, at origin: CGPoint, style: AnnotationStyle, opacity: CGFloat) {
        let font = NSFont.systemFont(ofSize: style.textSize, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.color.withAlphaComponent(style.color.alphaComponent * opacity),
            .paragraphStyle: paragraphStyle,
            .shadow: textShadow(opacity: opacity)
        ]

        let maxWidth = min(max(bounds.width - origin.x - 20, 120), 560)
        let textRect = NSString(string: text).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let drawRect = CGRect(
            x: origin.x,
            y: origin.y,
            width: ceil(textRect.width) + 2,
            height: ceil(textRect.height) + 2
        )

        NSString(string: text).draw(
            with: drawRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
    }

    private func textShadow(opacity: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5 * opacity)
        return shadow
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, style: AnnotationStyle, opacity: CGFloat) {
        style.color.withAlphaComponent(style.color.alphaComponent * opacity).setStroke()

        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = style.lineWidth
        path.move(to: start)
        path.line(to: end)
        path.stroke()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength = max(style.lineWidth * 3, 14)
        let headAngle = CGFloat.pi / 7

        let left = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let right = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )

        let head = NSBezierPath()
        head.lineCapStyle = .round
        head.lineJoinStyle = .round
        head.lineWidth = style.lineWidth
        head.move(to: left)
        head.line(to: end)
        head.line(to: right)
        head.stroke()
    }
}

private final class TextAnnotationField: NSTextField, NSTextFieldDelegate {
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        isBezeled = false
        drawsBackground = false
        backgroundColor = .clear
        focusRingType = .none
        usesSingleLineMode = true
        lineBreakMode = .byTruncatingTail
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 3
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.18).cgColor
        (cell as? NSTextFieldCell)?.drawsBackground = false
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            onCommit?(stringValue)
        case kVK_Escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            onCommit?(stringValue)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            onCancel?()
            return true
        default:
            return false
        }
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        configureFieldEditor(notification)
    }

    func controlTextDidChange(_ notification: Notification) {
        configureFieldEditor(notification)
    }

    private func configureFieldEditor(_ notification: Notification) {
        guard let textView = notification.userInfo?["NSFieldEditor"] as? NSTextView else { return }
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.insertionPointColor = textColor ?? .labelColor
        textView.textColor = textColor
    }
}

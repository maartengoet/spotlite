import AppKit
import ApplicationServices

@MainActor
final class CursorFocusController {
    var onModeChanged: ((CursorFocusMode) -> Void)?
    var onSettingsChanged: (() -> Void)?
    let settings = CursorFocusSettings()

    init() {
        settings.onChange = { [weak self] in
            self?.applySettings()
            self?.onSettingsChanged?()
        }
    }

    var mode: CursorFocusMode = .off {
        didSet {
            guard oldValue != mode else { return }
            applyMode()
            onModeChanged?(mode)
        }
    }

    private var windows: [CursorFocusWindow] = []
    private var timer: Timer?

    func toggleTypingFocus() {
        mode = mode == .typingFocus ? .off : .typingFocus
    }

    func toggleSpotlight() {
        mode = mode == .spotlight ? .off : .spotlight
    }

    func stop() {
        mode = .off
    }

    func increaseSpotlightRadius() {
        settings.increaseSpotlightRadius()
    }

    func decreaseSpotlightRadius() {
        settings.decreaseSpotlightRadius()
    }

    func rebuildOverlaysIfNeeded() {
        let currentMode = mode
        destroyOverlays()

        if currentMode != .off {
            mode = currentMode
            showOverlays()
            startTimer()
        }
    }

    private func applyMode() {
        if mode == .off {
            hideOverlays()
            stopTimer()
        } else {
            showOverlays()
            startTimer()
        }
    }

    private func showOverlays() {
        if windows.isEmpty {
            windows = NSScreen.screens.map { screen in
                let view = CursorFocusView(screen: screen)
                view.mode = mode
                view.spotlightRadius = settings.spotlightRadius
                return CursorFocusWindow(screen: screen, contentView: view)
            }
        }

        for window in windows {
            if let view = window.contentView as? CursorFocusView {
                view.mode = mode
                view.spotlightRadius = settings.spotlightRadius
                update(view: view)
            }
            window.orderFrontRegardless()
        }
    }

    private func hideOverlays() {
        for window in windows {
            window.orderOut(nil)
        }
    }

    private func destroyOverlays() {
        stopTimer()
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }

    private func startTimer() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateActiveFocus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateActiveFocus() {
        for window in windows {
            guard let view = window.contentView as? CursorFocusView else { continue }
            update(view: view)
        }
    }

    private func applySettings() {
        for window in windows {
            guard let view = window.contentView as? CursorFocusView else { continue }
            view.spotlightRadius = settings.spotlightRadius
        }
    }

    private func update(view: CursorFocusView) {
        switch mode {
        case .off:
            view.clearFocus()
        case .typingFocus:
            view.update(typingTarget: Self.currentTypingFocusTarget())
        case .spotlight:
            view.update(mouseLocation: NSEvent.mouseLocation)
        }
    }

    private static func currentTypingFocusTarget() -> TypingFocusTarget? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWideElement = AXUIElementCreateSystemWide()
        guard let focusedElement = focusedUIElement(from: systemWideElement) else { return nil }

        let candidates = candidateTextElements(startingAt: focusedElement)
        let frontmostAppIsTerminal = isFrontmostTerminalApp()

        for element in candidates {
            let target = frontmostAppIsTerminal
                ? directCaretTarget(in: element)
                : caretTarget(in: element)

            if let caretTarget = target {
                return caretTarget
            }
        }

        if !frontmostAppIsTerminal {
            for element in candidates {
                if let fallbackTarget = textInputFallbackTarget(in: element) {
                    return fallbackTarget
                }
            }
        }

        return nil
    }

    private static func focusedUIElement(from systemWideElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        guard status == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private static func caretTarget(in element: AXUIElement) -> TypingFocusTarget? {
        if let target = textMarkerTarget(in: element) {
            return target
        }

        if let target = textRangeTarget(in: element) {
            return target
        }

        return nil
    }

    private static func directCaretTarget(in element: AXUIElement) -> TypingFocusTarget? {
        if let target = textMarkerTarget(in: element) {
            return target
        }

        guard let selectedRange = selectedTextRange(in: element) else { return nil }

        if selectedRange.length > 0,
           let selectionRect = bounds(for: selectedRange, in: element) {
            return TypingFocusTarget(rect: selectionRect, kind: .selection)
        }

        guard let caretRect = bounds(for: selectedRange, in: element),
              caretRect.width <= 24 else {
            return nil
        }

        return TypingFocusTarget(rect: normalizedCaretRect(caretRect), kind: .caret)
    }

    private static func textRangeTarget(in element: AXUIElement) -> TypingFocusTarget? {
        guard let selectedRange = selectedTextRange(in: element) else { return nil }

        if selectedRange.length > 0,
           let selectionRect = bounds(for: selectedRange, in: element) {
            return TypingFocusTarget(rect: selectionRect, kind: .selection)
        }

        let contextRect = trailingContextRect(before: selectedRange.location, in: element)

        if let caretRect = bounds(for: selectedRange, in: element),
           caretRect.width <= 24 {
            return TypingFocusTarget(
                rect: normalizedCaretRect(caretRect),
                kind: .caret,
                contextRect: contextRect
            )
        }

        if selectedRange.location > 0 {
            let previousCharacterRange = CFRange(location: selectedRange.location - 1, length: 1)
            if let previousCharacterRect = bounds(for: previousCharacterRange, in: element) {
                return TypingFocusTarget(
                    rect: trailingCaretRect(from: previousCharacterRect),
                    kind: .caret,
                    contextRect: contextRect
                )
            }
        } else {
            let firstCharacterRange = CFRange(location: 0, length: 1)
            if let firstCharacterRect = bounds(for: firstCharacterRange, in: element) {
                return TypingFocusTarget(
                    rect: leadingCaretRect(from: firstCharacterRect),
                    kind: .caret
                )
            }
        }

        return nil
    }

    private static func textMarkerTarget(in element: AXUIElement) -> TypingFocusTarget? {
        guard let selectedTextMarkerRange = selectedTextMarkerRange(in: element),
              let rect = bounds(forTextMarkerRange: selectedTextMarkerRange, in: element) else {
            return nil
        }

        let standardized = rect.standardized
        let kind: TypingFocusKind = standardized.width <= 8 ? .caret : .selection
        let targetRect = kind == .caret ? normalizedCaretRect(standardized) : standardized
        return TypingFocusTarget(rect: targetRect, kind: kind)
    }

    private static func textInputFallbackTarget(in element: AXUIElement) -> TypingFocusTarget? {
        guard isTextInputElement(element),
              let elementRect = elementRect(element) else {
            return nil
        }

        return TypingFocusTarget(rect: fallbackCaretRect(in: elementRect), kind: .caret)
    }

    private static func candidateTextElements(startingAt element: AXUIElement) -> [AXUIElement] {
        var candidates: [AXUIElement] = []
        var queue = [element]
        var visited = Set<UInt>()

        while !queue.isEmpty, candidates.count < 120 {
            let current = queue.removeFirst()
            let identifier = CFHash(current)
            guard !visited.contains(identifier) else { continue }
            visited.insert(identifier)
            candidates.append(current)

            queue.append(contentsOf: childElements(of: current))
        }

        return candidates
    }

    private static func childElements(of element: AXUIElement) -> [AXUIElement] {
        let attributes: [CFString] = [
            kAXChildrenAttribute as CFString,
            "AXVisibleChildren" as CFString
        ]

        var children: [AXUIElement] = []

        for attribute in attributes {
            var value: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(element, attribute, &value)

            guard status == .success,
                  let values = value as? [Any] else {
                continue
            }

            for value in values {
                let object = value as CFTypeRef
                if CFGetTypeID(object) == AXUIElementGetTypeID() {
                    children.append(object as! AXUIElement)
                }
            }
        }

        return children
    }

    private static func selectedTextRange(in element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        )

        guard status == .success,
              let axValue = axValue(from: value),
              AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }

        return range
    }

    private static func bounds(for range: CFRange, in element: AXUIElement) -> CGRect? {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else { return nil }

        var value: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        )

        guard status == .success,
              let rect = cgRect(from: value) else {
            return nil
        }

        guard rect.isFinite,
              !rect.isNull,
              !rect.isInfinite else {
            return nil
        }

        return rect.standardized
    }

    private static func trailingContextRect(before location: CFIndex, in element: AXUIElement) -> CGRect? {
        guard location > 0 else { return nil }

        let contextLength = min(location, 36)
        let contextRange = CFRange(location: location - contextLength, length: contextLength)
        guard let rect = bounds(for: contextRange, in: element),
              rect.width > 2,
              rect.height > 2 else {
            return nil
        }

        return rect
    }

    private static func selectedTextMarkerRange(in element: AXUIElement) -> AXTextMarkerRange? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            "AXSelectedTextMarkerRange" as CFString,
            &value
        )

        guard status == .success,
              let value,
              CFGetTypeID(value) == AXTextMarkerRangeGetTypeID() else {
            return nil
        }

        return (value as! AXTextMarkerRange)
    }

    private static func bounds(forTextMarkerRange range: AXTextMarkerRange, in element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXBoundsForTextMarkerRange" as CFString,
            range,
            &value
        )

        guard status == .success,
              let rect = cgRect(from: value),
              rect.isFinite,
              !rect.isNull,
              !rect.isInfinite else {
            return nil
        }

        return rect.standardized
    }

    private static func isTextInputElement(_ element: AXUIElement) -> Bool {
        let role = stringAttribute(kAXRoleAttribute as CFString, in: element)
        let subrole = stringAttribute(kAXSubroleAttribute as CFString, in: element)

        if role == (kAXTextFieldRole as String)
            || role == (kAXTextAreaRole as String)
            || role == (kAXComboBoxRole as String) {
            return true
        }

        if subrole == "AXSearchField" {
            return true
        }

        if selectedTextRange(in: element) != nil || selectedTextMarkerRange(in: element) != nil {
            return true
        }

        return false
    }

    private static func isFrontmostTerminalApp() -> Bool {
        guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }

        let terminalBundleIdentifiers: Set<String> = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.mitchellh.ghostty",
            "com.github.wez.wezterm",
            "org.alacritty",
            "net.kovidgoyal.kitty"
        ]

        return terminalBundleIdentifiers.contains(bundleIdentifier)
    }

    private static func stringAttribute(_ attribute: CFString, in element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard status == .success else {
            return nil
        }

        return value as? String
    }

    private static func elementRect(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let positionStatus = AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        )
        let sizeStatus = AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &sizeValue
        )

        guard positionStatus == .success,
              sizeStatus == .success,
              let positionAXValue = axValue(from: positionValue),
              let sizeAXValue = axValue(from: sizeValue),
              AXValueGetType(positionAXValue) == .cgPoint,
              AXValueGetType(sizeAXValue) == .cgSize else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue, .cgSize, &size),
              size.width > 0,
              size.height > 0 else {
            return nil
        }

        let rect = CGRect(origin: position, size: size).standardized
        guard rect.isFinite,
              !rect.isNull,
              !rect.isInfinite else {
            return nil
        }

        return rect
    }

    private static func axValue(from value: CFTypeRef?) -> AXValue? {
        guard let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        return (value as! AXValue)
    }

    private static func cgRect(from value: CFTypeRef?) -> CGRect? {
        guard let value else { return nil }

        if CFGetTypeID(value) == AXValueGetTypeID() {
            let axValue = value as! AXValue
            guard AXValueGetType(axValue) == .cgRect else { return nil }

            var rect = CGRect.zero
            guard AXValueGetValue(axValue, .cgRect, &rect) else { return nil }
            return rect
        }

        if let nsValue = value as? NSValue {
            return nsValue.rectValue
        }

        return nil
    }

    private static func normalizedCaretRect(_ rect: CGRect) -> CGRect {
        var normalized = rect.standardized
        normalized.size.width = max(normalized.width, 2)
        normalized.size.height = max(normalized.height, 18)
        return normalized
    }

    private static func trailingCaretRect(from rect: CGRect) -> CGRect {
        let standardized = rect.standardized
        return CGRect(
            x: standardized.maxX,
            y: standardized.minY,
            width: 2,
            height: max(standardized.height, 18)
        )
    }

    private static func leadingCaretRect(from rect: CGRect) -> CGRect {
        let standardized = rect.standardized
        return CGRect(
            x: standardized.minX,
            y: standardized.minY,
            width: 2,
            height: max(standardized.height, 18)
        )
    }

    private static func fallbackCaretRect(in elementRect: CGRect) -> CGRect {
        let standardized = elementRect.standardized
        let caretHeight = min(max(standardized.height - 16, 22), 42)
        let verticalInset = max((standardized.height - caretHeight) / 2, 0)

        return CGRect(
            x: standardized.minX + min(max(standardized.width * 0.02, 8), 18),
            y: standardized.minY + verticalInset,
            width: 2,
            height: caretHeight
        )
    }

}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
    }
}

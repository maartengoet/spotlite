import AppKit

@MainActor
final class ShortcutGuideController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 650),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Spotlite Keyboard Shortcuts"
            window.center()
            window.contentView = ShortcutGuideView()
            window.delegate = self
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

private struct ShortcutSection {
    var title: String
    var rows: [ShortcutRow]
}

private struct ShortcutRow {
    var action: String
    var shortcut: String
}

private final class ShortcutGuideView: NSView {
    private let sections: [ShortcutSection] = [
        ShortcutSection(title: "Global", rows: [
            ShortcutRow(action: "Show keyboard shortcuts", shortcut: "Control + Option + Command + /"),
            ShortcutRow(action: "Start drawing", shortcut: "Control + Option + Command + 2"),
            ShortcutRow(action: "Typing Focus", shortcut: "Control + Option + Command + T"),
            ShortcutRow(action: "Spotlight", shortcut: "Control + Option + Command + S"),
            ShortcutRow(action: "Click Indicators", shortcut: "Control + Option + Command + K"),
            ShortcutRow(action: "Start or stop selected timer", shortcut: "Control + Option + Command + 3"),
            ShortcutRow(action: "Stop Typing Focus, spotlight, click indicators, or timer", shortcut: "Esc"),
            ShortcutRow(action: "Clear annotations", shortcut: "Control + Option + Command + C"),
            ShortcutRow(action: "Undo annotation", shortcut: "Control + Option + Command + Z")
        ]),
        ShortcutSection(title: "Drawing", rows: [
            ShortcutRow(action: "Exit drawing", shortcut: "Esc"),
            ShortcutRow(action: "Clear annotations", shortcut: "E"),
            ShortcutRow(action: "Undo annotation", shortcut: "Z"),
            ShortcutRow(action: "Pen, Highlighter, Text", shortcut: "P / H / N"),
            ShortcutRow(action: "Line, Arrow, Rectangle, Oval", shortcut: "L / A / R / O"),
            ShortcutRow(action: "Palette colors", shortcut: "1 / 2 / 3 / 4 / 5 / 6"),
            ShortcutRow(action: "Matching highlighter color", shortcut: "Shift + palette number"),
            ShortcutRow(action: "Text annotation", shortcut: "N, then click and type"),
            ShortcutRow(action: "Place text annotation", shortcut: "Return"),
            ShortcutRow(action: "Cancel text annotation", shortcut: "Esc"),
            ShortcutRow(action: "Text size", shortcut: "Menu > Text Size, or Control + scroll with Text selected"),
            ShortcutRow(action: "Whiteboard", shortcut: "W"),
            ShortcutRow(action: "Blackboard", shortcut: "K"),
            ShortcutRow(action: "Transparent background", shortcut: "T"),
            ShortcutRow(action: "Auto-Erase delay", shortcut: "Menu > Auto-Erase")
        ]),
        ShortcutSection(title: "Drawing Modifiers", rows: [
            ShortcutRow(action: "Straight line", shortcut: "Hold Shift while dragging"),
            ShortcutRow(action: "Rectangle", shortcut: "Hold Control while dragging"),
            ShortcutRow(action: "Ellipse", shortcut: "Hold Option while dragging"),
            ShortcutRow(action: "Arrow", shortcut: "Hold Control + Shift while dragging"),
            ShortcutRow(action: "Adjust stroke width or text size", shortcut: "Hold Control and scroll")
        ]),
        ShortcutSection(title: "Spotlight", rows: [
            ShortcutRow(action: "Smaller spotlight", shortcut: "Control + Option + Command + ["),
            ShortcutRow(action: "Larger spotlight", shortcut: "Control + Option + Command + ]")
        ]),
        ShortcutSection(title: "Timer", rows: [
            ShortcutRow(action: "Choose preset duration", shortcut: "Menu > Timer Duration"),
            ShortcutRow(action: "Choose custom duration", shortcut: "Menu > Timer Duration > Custom...")
        ])
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildLayout() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 26, left: 28, bottom: 26, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stack

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        stack.addArrangedSubview(titleBlock())

        for section in sections {
            stack.addArrangedSubview(sectionView(section))
        }
    }

    private func titleBlock() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let title = NSTextField(labelWithString: "Keyboard Shortcuts")
        title.font = .systemFont(ofSize: 28, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: "Spotlite is built for live use. Keep this window open while learning the shortcuts, or open it again from the menu bar item.")
        body.font = .systemFont(ofSize: 13)
        body.textColor = .secondaryLabelColor
        body.maximumNumberOfLines = 2

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(body)
        return stack
    }

    private func sectionView(_ section: ShortcutSection) -> NSView {
        let outer = NSStackView()
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = 10
        outer.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        outer.wantsLayer = true
        outer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        outer.layer?.cornerRadius = 8

        let title = NSTextField(labelWithString: section.title)
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        outer.addArrangedSubview(title)

        for row in section.rows {
            outer.addArrangedSubview(rowView(row))
        }

        NSLayoutConstraint.activate([
            outer.widthAnchor.constraint(equalToConstant: 624)
        ])

        return outer
    }

    private func rowView(_ row: ShortcutRow) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12

        let action = NSTextField(labelWithString: row.action)
        action.font = .systemFont(ofSize: 13)
        action.textColor = .labelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let shortcut = NSTextField(labelWithString: row.shortcut)
        shortcut.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        shortcut.textColor = .secondaryLabelColor
        shortcut.alignment = .right

        stack.addArrangedSubview(action)
        stack.addArrangedSubview(spacer)
        stack.addArrangedSubview(shortcut)

        NSLayoutConstraint.activate([
            action.widthAnchor.constraint(lessThanOrEqualToConstant: 350),
            shortcut.widthAnchor.constraint(greaterThanOrEqualToConstant: 190)
        ])

        return stack
    }
}

import AppKit

@MainActor
final class StatusMenuController: NSObject {
    var onToggleDrawMode: (() -> Void)?
    var onClearAnnotations: (() -> Void)?
    var onUndoAnnotation: (() -> Void)?
    var onToggleTypingFocus: (() -> Void)?
    var onToggleSpotlight: (() -> Void)?
    var onToggleClickIndicators: (() -> Void)?
    var onToggleBreakTimer: (() -> Void)?
    var onStartTimerMinutes: ((Int) -> Void)?
    var onShowCustomTimer: (() -> Void)?
    var onToggleLaunchAtLogin: (() -> Void)?
    var onRefreshLaunchAtLogin: (() -> Void)?
    var onShowShortcuts: (() -> Void)?
    var onShowPermissions: (() -> Void)?
    var onShowAbout: (() -> Void)?
    var onSelectTool: ((AnnotationTool) -> Void)?
    var onSelectColor: ((AnnotationColor) -> Void)?
    var onSelectBackground: ((DrawingBackground) -> Void)?
    var onSelectAutoEraseDelay: ((AnnotationAutoEraseDelay) -> Void)?
    var onIncreaseLineWidth: (() -> Void)?
    var onDecreaseLineWidth: (() -> Void)?
    var onIncreaseTextSize: (() -> Void)?
    var onDecreaseTextSize: (() -> Void)?
    var onIncreaseSpotlightSize: (() -> Void)?
    var onDecreaseSpotlightSize: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let drawMenuItem = NSMenuItem(title: "Start Drawing", action: #selector(toggleDrawMode), keyEquivalent: "2")
    private let typingFocusMenuItem = NSMenuItem(title: "Typing Focus", action: #selector(toggleTypingFocus), keyEquivalent: "t")
    private let spotlightMenuItem = NSMenuItem(title: "Spotlight", action: #selector(toggleSpotlight), keyEquivalent: "s")
    private let clickIndicatorsMenuItem = NSMenuItem(title: "Click Indicators", action: #selector(toggleClickIndicators), keyEquivalent: "k")
    private let breakTimerMenuItem = NSMenuItem(title: "Start 5-Minute Timer", action: #selector(toggleBreakTimer), keyEquivalent: "3")
    private let launchAtLoginMenuItem = NSMenuItem(title: "Auto Start at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let undoMenuItem = NSMenuItem(title: "Undo Last Annotation", action: #selector(undoAnnotation), keyEquivalent: "z")
    private let clearMenuItem = NSMenuItem(title: "Clear Annotations", action: #selector(clearAnnotations), keyEquivalent: "c")
    private var toolMenuItems: [NSMenuItem] = []
    private var colorMenuItems: [NSMenuItem] = []
    private var backgroundMenuItems: [NSMenuItem] = []
    private var autoEraseMenuItems: [NSMenuItem] = []
    private var timerDurationMenuItems: [NSMenuItem] = []
    private let lineWidthMenuItem = NSMenuItem(title: "Line Width: 8 pt", action: nil, keyEquivalent: "")
    private let textSizeMenuItem = NSMenuItem(title: "Text Size: 36 pt", action: nil, keyEquivalent: "")
    private let autoEraseMenuItem = NSMenuItem(title: "Auto-Erase: Off", action: nil, keyEquivalent: "")
    private let spotlightSizeMenuItem = NSMenuItem(title: "Spotlight Size: 115 pt", action: nil, keyEquivalent: "")
    private var isDrawingEnabled = false
    private var isBreakTimerRunning = false
    private var clickIndicatorsEnabled = false
    private var selectedTimerMinutes = 5
    private var cursorFocusMode: CursorFocusMode = .off
    private var currentTool: AnnotationTool = .highlighter

    override init() {
        super.init()

        configureStatusItem()
        configureMenu()
    }

    func setDrawingEnabled(_ isDrawingEnabled: Bool) {
        self.isDrawingEnabled = isDrawingEnabled
        drawMenuItem.title = isDrawingEnabled ? "Stop Drawing" : "Start Drawing"
        drawMenuItem.state = isDrawingEnabled ? .on : .off

        if let button = statusItem.button {
            refreshStatusIcon(button: button)
        }
    }

    func setSelectedTimerMinutes(_ minutes: Int) {
        selectedTimerMinutes = minutes
        refreshTimerMenuItems()

        if !isBreakTimerRunning {
            breakTimerMenuItem.title = "Start \(timerStartLabel(minutes: minutes)) Timer"
        }
    }

    func setCursorFocusMode(_ mode: CursorFocusMode) {
        cursorFocusMode = mode
        typingFocusMenuItem.state = mode == .typingFocus ? .on : .off
        spotlightMenuItem.state = mode == .spotlight ? .on : .off

        if let button = statusItem.button {
            refreshStatusIcon(button: button)
        }
    }

    func setBreakTimerRunning(_ isRunning: Bool) {
        isBreakTimerRunning = isRunning
        breakTimerMenuItem.title = isRunning ? "Stop Timer" : "Start \(timerStartLabel(minutes: selectedTimerMinutes)) Timer"
        breakTimerMenuItem.state = isRunning ? .on : .off

        if let button = statusItem.button {
            refreshStatusIcon(button: button)
        }
    }

    func setClickIndicatorsEnabled(_ isEnabled: Bool) {
        clickIndicatorsEnabled = isEnabled
        clickIndicatorsMenuItem.state = isEnabled ? .on : .off

        if let button = statusItem.button {
            refreshStatusIcon(button: button)
        }
    }

    func updateAnnotationState(settings: AnnotationSettings) {
        currentTool = settings.tool

        for item in toolMenuItems {
            item.state = item.tag == AnnotationTool.allCases.firstIndex(of: settings.tool) ? .on : .off
        }

        for item in colorMenuItems {
            item.state = item.tag == AnnotationColor.allCases.firstIndex(of: settings.color) ? .on : .off
        }

        for item in backgroundMenuItems {
            item.state = item.tag == DrawingBackground.allCases.firstIndex(of: settings.background) ? .on : .off
        }

        for item in autoEraseMenuItems {
            item.state = item.tag == AnnotationAutoEraseDelay.allCases.firstIndex(of: settings.autoEraseDelay) ? .on : .off
        }

        lineWidthMenuItem.title = "Line Width: \(Int(settings.lineWidth)) pt"
        textSizeMenuItem.title = "Text Size: \(Int(settings.textSize)) pt"
        autoEraseMenuItem.title = "Auto-Erase: \(settings.autoEraseDelay.title)"

        if let button = statusItem.button {
            refreshStatusIcon(button: button)
        }
    }

    func updateCursorFocusState(settings: CursorFocusSettings) {
        spotlightSizeMenuItem.title = "Spotlight Size: \(Int(settings.spotlightRadius)) pt"
    }

    func setLaunchAtLoginStatus(_ status: LaunchAtLoginStatus) {
        switch status {
        case .enabled:
            launchAtLoginMenuItem.title = "Auto Start at Login"
            launchAtLoginMenuItem.state = .on
            launchAtLoginMenuItem.isEnabled = true
            launchAtLoginMenuItem.toolTip = "Spotlite will open automatically after you sign in."
        case .disabled:
            launchAtLoginMenuItem.title = "Auto Start at Login"
            launchAtLoginMenuItem.state = .off
            launchAtLoginMenuItem.isEnabled = true
            launchAtLoginMenuItem.toolTip = "Open Spotlite automatically after you sign in."
        case .requiresApproval:
            launchAtLoginMenuItem.title = "Auto Start at Login (Needs Approval)"
            launchAtLoginMenuItem.state = .mixed
            launchAtLoginMenuItem.isEnabled = true
            launchAtLoginMenuItem.toolTip = "macOS needs approval in Login Items before Spotlite can start at login."
        case .unavailable:
            launchAtLoginMenuItem.title = "Auto Start at Login (Unavailable)"
            launchAtLoginMenuItem.state = .off
            launchAtLoginMenuItem.isEnabled = true
            launchAtLoginMenuItem.toolTip = "Build and open Spotlite as an app bundle to use login items."
        }
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.toolTip = "Spotlite"
            button.image = statusImage(named: "highlighter")
            button.imagePosition = .imageOnly
        }
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self

        drawMenuItem.target = self
        drawMenuItem.keyEquivalentModifierMask = [.control, .option, .command]
        drawMenuItem.toolTip = "Control + Option + Command + 2"
        menu.addItem(drawMenuItem)

        typingFocusMenuItem.target = self
        typingFocusMenuItem.keyEquivalentModifierMask = [.control, .option, .command]
        typingFocusMenuItem.toolTip = "Control + Option + Command + T - highlight the active text caret"
        menu.addItem(typingFocusMenuItem)

        spotlightMenuItem.target = self
        spotlightMenuItem.keyEquivalentModifierMask = [.control, .option, .command]
        spotlightMenuItem.toolTip = "Control + Option + Command + S - dim screen around cursor"
        menu.addItem(spotlightMenuItem)

        clickIndicatorsMenuItem.target = self
        clickIndicatorsMenuItem.keyEquivalentModifierMask = [.control, .option, .command]
        clickIndicatorsMenuItem.toolTip = "Control + Option + Command + K - show animated rings on mouse clicks"
        menu.addItem(clickIndicatorsMenuItem)

        breakTimerMenuItem.target = self
        breakTimerMenuItem.keyEquivalentModifierMask = [.control, .option, .command]
        breakTimerMenuItem.toolTip = "Control + Option + Command + 3"
        menu.addItem(breakTimerMenuItem)

        menu.addItem(.separator())
        menu.addItem(makeTimerMenu())

        undoMenuItem.target = self
        undoMenuItem.keyEquivalentModifierMask = [.control, .option, .command]
        undoMenuItem.toolTip = "Control + Option + Command + Z"
        menu.addItem(undoMenuItem)

        clearMenuItem.target = self
        clearMenuItem.keyEquivalentModifierMask = [.control, .option, .command]
        clearMenuItem.toolTip = "Control + Option + Command + C"
        menu.addItem(clearMenuItem)

        menu.addItem(.separator())
        menu.addItem(makeToolMenu())
        menu.addItem(makeColorMenu())
        menu.addItem(makeBackgroundMenu())
        menu.addItem(makeWidthMenu())
        menu.addItem(makeTextSizeMenu())
        menu.addItem(makeAutoEraseMenu())
        menu.addItem(makeSpotlightSizeMenu())

        menu.addItem(.separator())

        let shortcutsItem = NSMenuItem(title: "Keyboard Shortcuts...", action: #selector(showShortcuts), keyEquivalent: "/")
        shortcutsItem.target = self
        shortcutsItem.keyEquivalentModifierMask = [.control, .option, .command]
        shortcutsItem.toolTip = "Control + Option + Command + /"
        menu.addItem(shortcutsItem)

        let permissionsItem = NSMenuItem(title: "Permissions...", action: #selector(showPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        let aboutItem = NSMenuItem(title: "About Spotlite", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Spotlite", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeToolMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Tool", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for (index, tool) in AnnotationTool.allCases.enumerated() {
            let item = NSMenuItem(title: "\(tool.title) (\(tool.drawingShortcut))", action: #selector(selectTool(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.image = statusImage(named: tool.symbolName, accessibilityDescription: tool.title)
            submenu.addItem(item)
            toolMenuItems.append(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func makeTimerMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Timer Duration", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for minutes in [1, 2, 5, 10, 15, 30] {
            let item = NSMenuItem(title: timerMenuLabel(minutes: minutes), action: #selector(startTimerPreset(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            submenu.addItem(item)
            timerDurationMenuItems.append(item)
        }

        submenu.addItem(.separator())

        let custom = NSMenuItem(title: "Custom...", action: #selector(showCustomTimer), keyEquivalent: "")
        custom.target = self
        submenu.addItem(custom)

        parent.submenu = submenu
        refreshTimerMenuItems()
        return parent
    }

    private func makeColorMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for (index, color) in AnnotationColor.allCases.enumerated() {
            let item = NSMenuItem(title: color.title, action: #selector(selectColor(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            submenu.addItem(item)
            colorMenuItems.append(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func makeWidthMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Line Width", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        lineWidthMenuItem.isEnabled = false
        submenu.addItem(lineWidthMenuItem)

        let thinner = NSMenuItem(title: "Thinner", action: #selector(decreaseLineWidth), keyEquivalent: "-")
        thinner.target = self
        thinner.keyEquivalentModifierMask = [.control, .option, .command]
        submenu.addItem(thinner)

        let thicker = NSMenuItem(title: "Thicker", action: #selector(increaseLineWidth), keyEquivalent: "=")
        thicker.target = self
        thicker.keyEquivalentModifierMask = [.control, .option, .command]
        submenu.addItem(thicker)

        parent.submenu = submenu
        return parent
    }

    private func makeTextSizeMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Text Size", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        textSizeMenuItem.isEnabled = false
        submenu.addItem(textSizeMenuItem)

        let smaller = NSMenuItem(title: "Smaller Text", action: #selector(decreaseTextSize), keyEquivalent: "")
        smaller.target = self
        submenu.addItem(smaller)

        let larger = NSMenuItem(title: "Larger Text", action: #selector(increaseTextSize), keyEquivalent: "")
        larger.target = self
        submenu.addItem(larger)

        parent.submenu = submenu
        return parent
    }

    private func makeAutoEraseMenu() -> NSMenuItem {
        let submenu = NSMenu()

        for (index, delay) in AnnotationAutoEraseDelay.allCases.enumerated() {
            let item = NSMenuItem(title: delay.title, action: #selector(selectAutoEraseDelay(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            submenu.addItem(item)
            autoEraseMenuItems.append(item)
        }

        autoEraseMenuItem.submenu = submenu
        return autoEraseMenuItem
    }

    private func makeSpotlightSizeMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Spotlight Size", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        spotlightSizeMenuItem.isEnabled = false
        submenu.addItem(spotlightSizeMenuItem)

        let smaller = NSMenuItem(title: "Smaller Spotlight", action: #selector(decreaseSpotlightSize), keyEquivalent: "[")
        smaller.target = self
        smaller.keyEquivalentModifierMask = [.control, .option, .command]
        submenu.addItem(smaller)

        let larger = NSMenuItem(title: "Larger Spotlight", action: #selector(increaseSpotlightSize), keyEquivalent: "]")
        larger.target = self
        larger.keyEquivalentModifierMask = [.control, .option, .command]
        submenu.addItem(larger)

        parent.submenu = submenu
        return parent
    }

    private func makeBackgroundMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Drawing Background", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for (index, background) in DrawingBackground.allCases.enumerated() {
            let item = NSMenuItem(title: background.title, action: #selector(selectBackground(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            submenu.addItem(item)
            backgroundMenuItems.append(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func refreshStatusIcon(button: NSStatusBarButton) {
        button.contentTintColor = nil

        if isDrawingEnabled {
            button.image = statusImage(named: currentTool.symbolName)
            return
        }

        switch cursorFocusMode {
        case .off:
            button.image = statusImage(named: "highlighter")
        case .typingFocus:
            button.image = statusImage(named: "text.cursor")
        case .spotlight:
            button.image = statusImage(named: "scope")
        }

        if cursorFocusMode == .off, isBreakTimerRunning {
            button.image = statusImage(named: "timer")
        }

        if cursorFocusMode == .off, !isBreakTimerRunning, clickIndicatorsEnabled {
            button.image = statusImage(named: "cursorarrow.click.2")
        }
    }

    @objc
    private func toggleDrawMode() {
        onToggleDrawMode?()
    }

    @objc
    private func clearAnnotations() {
        onClearAnnotations?()
    }

    @objc
    private func undoAnnotation() {
        onUndoAnnotation?()
    }

    @objc
    private func toggleTypingFocus() {
        onToggleTypingFocus?()
    }

    @objc
    private func toggleSpotlight() {
        onToggleSpotlight?()
    }

    @objc
    private func toggleClickIndicators() {
        onToggleClickIndicators?()
    }

    @objc
    private func toggleBreakTimer() {
        onToggleBreakTimer?()
    }

    @objc
    private func startTimerPreset(_ sender: NSMenuItem) {
        onStartTimerMinutes?(sender.tag)
    }

    @objc
    private func showCustomTimer() {
        onShowCustomTimer?()
    }

    @objc
    private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin?()
    }

    @objc
    private func showShortcuts() {
        onShowShortcuts?()
    }

    @objc
    private func showPermissions() {
        onShowPermissions?()
    }

    @objc
    private func showAbout() {
        onShowAbout?()
    }

    @objc
    private func selectTool(_ sender: NSMenuItem) {
        guard AnnotationTool.allCases.indices.contains(sender.tag) else { return }
        onSelectTool?(AnnotationTool.allCases[sender.tag])
    }

    @objc
    private func selectColor(_ sender: NSMenuItem) {
        guard AnnotationColor.allCases.indices.contains(sender.tag) else { return }
        onSelectColor?(AnnotationColor.allCases[sender.tag])
    }

    @objc
    private func selectBackground(_ sender: NSMenuItem) {
        guard DrawingBackground.allCases.indices.contains(sender.tag) else { return }
        onSelectBackground?(DrawingBackground.allCases[sender.tag])
    }

    @objc
    private func selectAutoEraseDelay(_ sender: NSMenuItem) {
        guard AnnotationAutoEraseDelay.allCases.indices.contains(sender.tag) else { return }
        onSelectAutoEraseDelay?(AnnotationAutoEraseDelay.allCases[sender.tag])
    }

    @objc
    private func increaseLineWidth() {
        onIncreaseLineWidth?()
    }

    @objc
    private func decreaseLineWidth() {
        onDecreaseLineWidth?()
    }

    @objc
    private func increaseTextSize() {
        onIncreaseTextSize?()
    }

    @objc
    private func decreaseTextSize() {
        onDecreaseTextSize?()
    }

    @objc
    private func increaseSpotlightSize() {
        onIncreaseSpotlightSize?()
    }

    @objc
    private func decreaseSpotlightSize() {
        onDecreaseSpotlightSize?()
    }

    private func refreshTimerMenuItems() {
        for item in timerDurationMenuItems {
            item.state = item.tag == selectedTimerMinutes ? .on : .off
        }
    }

    private func timerMenuLabel(minutes: Int) -> String {
        minutes == 1 ? "1 Minute" : "\(minutes) Minutes"
    }

    private func timerStartLabel(minutes: Int) -> String {
        "\(minutes)-Minute"
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        onRefreshLaunchAtLogin?()
    }
}

private func statusImage(named symbolName: String, accessibilityDescription: String = "Spotlite") -> NSImage? {
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
        ?? NSImage(systemSymbolName: "highlighter", accessibilityDescription: accessibilityDescription)
    image?.isTemplate = true
    return image
}

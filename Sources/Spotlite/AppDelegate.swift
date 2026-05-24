import AppKit
import ApplicationServices
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController?
    private let overlayController = OverlayController()
    private let cursorFocusController = CursorFocusController()
    private let clickIndicatorController = ClickIndicatorController()
    private let breakTimerController = BreakTimerController()
    private let shortcutGuideController = ShortcutGuideController()
    private let permissionsGuideController = PermissionsGuideController()
    private let launchAtLoginController = LaunchAtLoginController()
    private let hotKeyManager = HotKeyManager()
    private var escapeHotKeyID: UInt32?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusMenuController = StatusMenuController()
        statusMenuController.onToggleDrawMode = { [weak self] in
            self?.toggleDrawMode()
        }
        statusMenuController.onClearAnnotations = { [weak self] in
            self?.clearAnnotations()
        }
        statusMenuController.onUndoAnnotation = { [weak self] in
            self?.undoAnnotation()
        }
        statusMenuController.onToggleTypingFocus = { [weak self] in
            self?.toggleTypingFocus()
        }
        statusMenuController.onToggleSpotlight = { [weak self] in
            self?.cursorFocusController.toggleSpotlight()
        }
        statusMenuController.onToggleClickIndicators = { [weak self] in
            self?.clickIndicatorController.toggle()
        }
        statusMenuController.onToggleBreakTimer = { [weak self] in
            self?.breakTimerController.toggleDefaultTimer()
        }
        statusMenuController.onStartTimerMinutes = { [weak self] minutes in
            self?.breakTimerController.start(minutes: minutes)
        }
        statusMenuController.onShowCustomTimer = { [weak self] in
            self?.showCustomTimerPrompt()
        }
        statusMenuController.onToggleLaunchAtLogin = { [weak self] in
            self?.toggleLaunchAtLogin()
        }
        statusMenuController.onRefreshLaunchAtLogin = { [weak self] in
            self?.refreshLaunchAtLoginState()
        }
        statusMenuController.onShowShortcuts = { [weak self] in
            self?.shortcutGuideController.show()
        }
        statusMenuController.onShowPermissions = { [weak self] in
            self?.permissionsGuideController.show()
        }
        statusMenuController.onShowAbout = { [weak self] in
            self?.showAbout()
        }
        statusMenuController.onSelectTool = { [weak self] tool in
            self?.overlayController.settings.tool = tool
        }
        statusMenuController.onSelectColor = { [weak self] color in
            self?.overlayController.settings.color = color
        }
        statusMenuController.onSelectBackground = { [weak self] background in
            self?.overlayController.settings.background = background
        }
        statusMenuController.onSelectAutoEraseDelay = { [weak self] delay in
            self?.overlayController.setAutoEraseDelay(delay)
        }
        statusMenuController.onIncreaseLineWidth = { [weak self] in
            self?.overlayController.settings.increaseLineWidth()
        }
        statusMenuController.onDecreaseLineWidth = { [weak self] in
            self?.overlayController.settings.decreaseLineWidth()
        }
        statusMenuController.onIncreaseTextSize = { [weak self] in
            self?.overlayController.settings.increaseTextSize()
        }
        statusMenuController.onDecreaseTextSize = { [weak self] in
            self?.overlayController.settings.decreaseTextSize()
        }
        statusMenuController.onIncreaseSpotlightSize = { [weak self] in
            self?.cursorFocusController.increaseSpotlightRadius()
        }
        statusMenuController.onDecreaseSpotlightSize = { [weak self] in
            self?.cursorFocusController.decreaseSpotlightRadius()
        }
        self.statusMenuController = statusMenuController
        statusMenuController.setSelectedTimerMinutes(breakTimerController.selectedDurationMinutes)
        overlayController.onSettingsChanged = { [weak self] in
            self?.refreshAnnotationState()
        }
        overlayController.onDrawingStateChanged = { [weak self] isDrawingEnabled in
            self?.statusMenuController?.setDrawingEnabled(isDrawingEnabled)
        }
        cursorFocusController.onModeChanged = { [weak self] mode in
            self?.statusMenuController?.setCursorFocusMode(mode)
            self?.updateEscapeHotKeyRegistration()
        }
        cursorFocusController.onSettingsChanged = { [weak self] in
            guard let self else { return }
            self.statusMenuController?.updateCursorFocusState(settings: cursorFocusController.settings)
        }
        breakTimerController.onRunningStateChanged = { [weak self] isRunning in
            self?.statusMenuController?.setBreakTimerRunning(isRunning)
            self?.updateEscapeHotKeyRegistration()
        }
        clickIndicatorController.onEnabledChanged = { [weak self] isEnabled in
            self?.statusMenuController?.setClickIndicatorsEnabled(isEnabled)
            self?.updateEscapeHotKeyRegistration()
        }
        breakTimerController.onDurationChanged = { [weak self] minutes in
            self?.statusMenuController?.setSelectedTimerMinutes(minutes)
        }
        overlayController.settings.onChange = { [weak self] in
            guard let self else { return }
            self.overlayController.refreshCanvasesForSettingsChange()
            self.refreshAnnotationState()
        }
        refreshAnnotationState()
        statusMenuController.updateCursorFocusState(settings: cursorFocusController.settings)
        refreshLaunchAtLoginState()

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_D),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.toggleDrawMode() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_2),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.toggleDrawMode() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.clearAnnotations() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_Z),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.undoAnnotation() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_T),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.toggleTypingFocus() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_S),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.cursorFocusController.toggleSpotlight() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.clickIndicatorController.toggle() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_3),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.breakTimerController.toggleDefaultTimer() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_Minus),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.overlayController.settings.decreaseLineWidth() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_Equal),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.overlayController.settings.increaseLineWidth() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_LeftBracket),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.cursorFocusController.decreaseSpotlightRadius() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_RightBracket),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.cursorFocusController.increaseSpotlightRadius() }
        )

        hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_Slash),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            action: { [weak self] in self?.shortcutGuideController.show() }
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        permissionsGuideController.refreshIfVisible()
        refreshLaunchAtLoginState()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc
    private func screenParametersDidChange() {
        overlayController.rebuildOverlaysIfNeeded()
        cursorFocusController.rebuildOverlaysIfNeeded()
        clickIndicatorController.rebuildOverlaysIfNeeded()
        breakTimerController.rebuildWindowIfNeeded()
    }

    private func toggleDrawMode() {
        overlayController.isDrawingEnabled.toggle()
    }

    private func clearAnnotations() {
        overlayController.clearAnnotations()
    }

    private func undoAnnotation() {
        overlayController.undoLastAnnotation()
    }

    private func toggleTypingFocus() {
        if cursorFocusController.mode == .typingFocus {
            cursorFocusController.stop()
            return
        }

        guard AXIsProcessTrusted() else {
            permissionsGuideController.show()
            return
        }

        cursorFocusController.toggleTypingFocus()
    }

    private func updateEscapeHotKeyRegistration() {
        let shouldRegisterEscape = cursorFocusController.mode != .off
            || clickIndicatorController.isEnabled
            || breakTimerController.isRunning

        if shouldRegisterEscape, escapeHotKeyID == nil {
            escapeHotKeyID = hotKeyManager.register(
                keyCode: UInt32(kVK_Escape),
                modifiers: 0,
                action: { [weak self] in self?.stopPresenterEffectsFromEscape() }
            )
        } else if !shouldRegisterEscape, let escapeHotKeyID {
            hotKeyManager.unregister(id: escapeHotKeyID)
            self.escapeHotKeyID = nil
        }
    }

    private func stopPresenterEffectsFromEscape() {
        if cursorFocusController.mode != .off {
            cursorFocusController.stop()
        }

        if breakTimerController.isRunning {
            breakTimerController.stop()
        }

        if clickIndicatorController.isEnabled {
            clickIndicatorController.isEnabled = false
        }

        updateEscapeHotKeyRegistration()
    }

    private func refreshAnnotationState() {
        statusMenuController?.updateAnnotationState(settings: overlayController.settings)
    }

    private func showCustomTimerPrompt() {
        NSApp.activate(ignoringOtherApps: true)

        while true {
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
            input.stringValue = String(breakTimerController.selectedDurationMinutes)

            let alert = NSAlert()
            alert.messageText = "Custom Timer"
            alert.informativeText = "Enter a timer duration in minutes, from 1 to 240."
            alert.accessoryView = input
            alert.addButton(withTitle: "Start Timer")
            alert.addButton(withTitle: "Cancel")

            input.selectText(nil)

            guard alert.runModal() == .alertFirstButtonReturn else {
                return
            }

            let trimmedValue = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let minutes = Int(trimmedValue), (1...240).contains(minutes) else {
                showInvalidTimerAlert()
                continue
            }

            breakTimerController.start(minutes: minutes)
            return
        }
    }

    private func showInvalidTimerAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Use a whole number from 1 to 240."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func refreshLaunchAtLoginState() {
        statusMenuController?.setLaunchAtLoginStatus(launchAtLoginController.status)
    }

    private func toggleLaunchAtLogin() {
        switch launchAtLoginController.status {
        case .enabled:
            do {
                try launchAtLoginController.disable()
            } catch {
                showLaunchAtLoginError(error)
            }
        case .disabled:
            do {
                let status = try launchAtLoginController.enable()
                if status == .requiresApproval {
                    showLaunchAtLoginApprovalAlert()
                }
            } catch {
                showLaunchAtLoginError(error)
            }
        case .requiresApproval:
            showLaunchAtLoginApprovalAlert()
        case .unavailable:
            showLaunchAtLoginUnavailableAlert()
        }

        refreshLaunchAtLoginState()
    }

    private func showLaunchAtLoginApprovalAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Approve Spotlite in Login Items"
        alert.informativeText = "macOS has the login item request, but it still needs approval before Spotlite can open automatically at sign-in."
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            launchAtLoginController.openLoginItemsSettings()
        }
    }

    private func showLaunchAtLoginUnavailableAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Auto Start needs the app bundle"
        alert.informativeText = "Build and open build/Spotlite.app before enabling Auto Start at Login."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showLaunchAtLoginError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert(error: error)
        alert.messageText = "Could not update Auto Start at Login"
        alert.runModal()
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Spotlite",
            .applicationVersion: "0.1.0",
            .version: "Open source preview",
            .credits: NSAttributedString(
                string: "A free, MIT-licensed macOS presenter overlay.",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        ])
    }
}

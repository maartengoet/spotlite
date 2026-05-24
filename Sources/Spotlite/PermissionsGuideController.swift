import AppKit
import ApplicationServices

@MainActor
final class PermissionsGuideController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var contentView: PermissionsGuideView?
    private var refreshTimer: Timer?

    func show() {
        if window == nil {
            let contentView = PermissionsGuideView()
            contentView.onRequestAccessibility = requestAccessibility
            contentView.onOpenAccessibilitySettings = {
                Self.openSettingsPane("Privacy_Accessibility")
            }
            contentView.onRequestScreenRecording = requestScreenRecording
            contentView.onOpenScreenRecordingSettings = {
                Self.openSettingsPane("Privacy_ScreenCapture")
            }
            contentView.onRestartApp = restartApp
            contentView.onRevealApp = revealCurrentApp
            contentView.onResetPermissions = resetPermissions
            self.contentView = contentView

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 650),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Spotlite Permissions"
            window.center()
            window.contentView = contentView
            window.delegate = self
            self.window = window
        }

        refresh()
        startRefreshTimer()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshIfVisible() {
        guard window?.isVisible == true else { return }
        refresh()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        stopRefreshTimer()
        return false
    }

    private func refresh() {
        contentView?.update(
            accessibilityGranted: Self.isAccessibilityGranted,
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
    }

    private func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    private func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        refresh()
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }

        let timer = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.window?.isVisible == true else { return }
                self.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private static func openSettingsPane(_ pane: String) {
        let paneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
        let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.preference.security")

        if let paneURL, NSWorkspace.shared.open(paneURL) {
            return
        }

        if let fallbackURL {
            NSWorkspace.shared.open(fallbackURL)
        }
    }

    private func revealCurrentApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    private func resetPermissions() {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "dev.maartengoet.spotlite"
        Self.runTCCReset(service: "Accessibility", bundleIdentifier: bundleIdentifier)
        Self.runTCCReset(service: "ScreenCapture", bundleIdentifier: bundleIdentifier)
        refresh()
    }

    private func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [bundleURL.path]

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            try? process.run()
        }

        NSApp.terminate(nil)
    }

    private static var isAccessibilityGranted: Bool {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func runTCCReset(service: String, bundleIdentifier: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service, bundleIdentifier]
        try? process.run()
        process.waitUntilExit()
    }
}

private final class PermissionsGuideView: NSView {
    var onRequestAccessibility: (() -> Void)?
    var onOpenAccessibilitySettings: (() -> Void)?
    var onRequestScreenRecording: (() -> Void)?
    var onOpenScreenRecordingSettings: (() -> Void)?
    var onRestartApp: (() -> Void)?
    var onRevealApp: (() -> Void)?
    var onResetPermissions: (() -> Void)?

    private let accessibilityStatus = NSTextField(labelWithString: "")
    private let screenRecordingStatus = NSTextField(labelWithString: "")
    private let accessibilityIcon = NSImageView()
    private let screenRecordingIcon = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(accessibilityGranted: Bool, screenRecordingGranted: Bool) {
        updateStatus(
            icon: accessibilityIcon,
            label: accessibilityStatus,
            isGranted: accessibilityGranted,
            grantedText: "Enabled",
            missingText: "Needed for Typing Focus"
        )
        updateStatus(
            icon: screenRecordingIcon,
            label: screenRecordingStatus,
            isGranted: screenRecordingGranted,
            grantedText: "Enabled",
            missingText: "Needed later for zoom, snips, OCR, and recording"
        )
    }

    private func buildLayout() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -28)
        ])

        stack.addArrangedSubview(titleBlock())
        stack.addArrangedSubview(currentFeaturesRow())
        stack.addArrangedSubview(permissionRow(
            iconView: accessibilityIcon,
            title: "Accessibility",
            body: "Required for Typing Focus, keystroke display, and later DemoType-style presenter actions.",
            statusLabel: accessibilityStatus,
            buttons: [
                actionButton(title: "Request", action: #selector(requestAccessibility)),
                actionButton(title: "Open Settings", action: #selector(openAccessibilitySettings))
            ]
        ))
        stack.addArrangedSubview(permissionRow(
            iconView: screenRecordingIcon,
            title: "Screen Recording",
            body: "Required for true live zoom, magnifier, screenshots, OCR, and recording.",
            statusLabel: screenRecordingStatus,
            buttons: [
                actionButton(title: "Request", action: #selector(requestScreenRecording)),
                actionButton(title: "Open Settings", action: #selector(openScreenRecordingSettings))
            ]
        ))
        stack.addArrangedSubview(troubleshootingRow())
        stack.addArrangedSubview(footerText())
    }

    private func titleBlock() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let title = NSTextField(labelWithString: "Permissions")
        title.font = .systemFont(ofSize: 28, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: "Spotlite asks for macOS permissions only when a feature needs them. This page shows what is already ready and what unlocks future presenter tools.")
        body.font = .systemFont(ofSize: 13)
        body.textColor = .secondaryLabelColor
        body.maximumNumberOfLines = 3

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(body)
        return stack
    }

    private func currentFeaturesRow() -> NSView {
        let icon = NSImageView(image: statusImage(systemName: "checkmark.circle.fill", color: .systemGreen))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let status = NSTextField(labelWithString: "Ready")
        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.textColor = .systemGreen

        return row(
            icon: icon,
            title: "Drawing and spotlight",
            body: "The current annotation and pointer-based spotlight tools do not require extra macOS permissions.",
            statusLabel: status,
            buttons: []
        )
    }

    private func troubleshootingRow() -> NSView {
        let icon = NSImageView(image: statusImage(systemName: "arrow.clockwise.circle.fill", color: .controlAccentColor))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let status = NSTextField(labelWithString: "Use after changing permissions")
        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.textColor = .secondaryLabelColor

        return row(
            icon: icon,
            title: "Settings show enabled, but no checkmark?",
            body: "Restart Spotlite after changing privacy settings. Local development builds are ad-hoc signed, so after rebuilding you may need to remove the old Spotlite entry and add this app bundle again.",
            statusLabel: status,
            buttons: [
                actionButton(title: "Reset Spotlite Permissions", action: #selector(resetPermissions)),
                actionButton(title: "Restart Spotlite", action: #selector(restartApp)),
                actionButton(title: "Reveal App", action: #selector(revealApp))
            ]
        )
    }

    private func permissionRow(
        iconView: NSImageView,
        title: String,
        body: String,
        statusLabel: NSTextField,
        buttons: [NSButton]
    ) -> NSView {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 26).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 26).isActive = true

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        return row(icon: iconView, title: title, body: body, statusLabel: statusLabel, buttons: buttons)
    }

    private func row(
        icon: NSView,
        title: String,
        body: String,
        statusLabel: NSTextField,
        buttons: [NSButton]
    ) -> NSView {
        let outer = NSStackView()
        outer.orientation = .horizontal
        outer.alignment = .top
        outer.spacing = 12
        outer.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        outer.wantsLayer = true
        outer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        outer.layer?.cornerRadius = 8

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 3

        let bottomStack = NSStackView()
        bottomStack.orientation = .horizontal
        bottomStack.alignment = .centerY
        bottomStack.spacing = 8
        bottomStack.addArrangedSubview(statusLabel)
        for button in buttons {
            bottomStack.addArrangedSubview(button)
        }

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(bodyLabel)
        textStack.addArrangedSubview(bottomStack)

        outer.addArrangedSubview(icon)
        outer.addArrangedSubview(textStack)

        NSLayoutConstraint.activate([
            outer.widthAnchor.constraint(equalToConstant: 504),
            textStack.widthAnchor.constraint(equalToConstant: 438)
        ])

        return outer
    }

    private func footerText() -> NSView {
        let label = NSTextField(wrappingLabelWithString: "After changing macOS privacy settings, quit and reopen Spotlite if macOS asks you to restart the app.")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        label.maximumNumberOfLines = 2
        return label
    }

    private func actionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        return button
    }

    private func updateStatus(
        icon: NSImageView,
        label: NSTextField,
        isGranted: Bool,
        grantedText: String,
        missingText: String
    ) {
        icon.image = NSImage(
            systemSymbolName: isGranted ? "checkmark.circle.fill" : "circle",
            accessibilityDescription: isGranted ? "Enabled" : "Not enabled"
        )
        icon.symbolConfiguration = .init(pointSize: 24, weight: .regular)
        icon.contentTintColor = isGranted ? .systemGreen : .tertiaryLabelColor
        label.stringValue = isGranted ? grantedText : missingText
        label.textColor = isGranted ? .systemGreen : .secondaryLabelColor
    }

    private func statusImage(systemName: String, color: NSColor) -> NSImage {
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? NSImage()
        image.isTemplate = true
        image.size = NSSize(width: 24, height: 24)
        return image.withSymbolConfiguration(.init(paletteColors: [color])) ?? image
    }

    @objc
    private func requestAccessibility() {
        onRequestAccessibility?()
    }

    @objc
    private func openAccessibilitySettings() {
        onOpenAccessibilitySettings?()
    }

    @objc
    private func requestScreenRecording() {
        onRequestScreenRecording?()
    }

    @objc
    private func openScreenRecordingSettings() {
        onOpenScreenRecordingSettings?()
    }

    @objc
    private func restartApp() {
        onRestartApp?()
    }

    @objc
    private func revealApp() {
        onRevealApp?()
    }

    @objc
    private func resetPermissions() {
        onResetPermissions?()
    }
}

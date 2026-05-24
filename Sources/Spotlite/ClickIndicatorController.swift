import AppKit

@MainActor
final class ClickIndicatorController {
    var onEnabledChanged: ((Bool) -> Void)?

    var isEnabled = false {
        didSet {
            guard oldValue != isEnabled else { return }
            isEnabled ? start() : stop()
            onEnabledChanged?(isEnabled)
        }
    }

    private var windows: [ClickIndicatorWindow] = []
    private var eventMonitors: [Any] = []
    private var timer: Timer?

    func toggle() {
        isEnabled.toggle()
    }

    func rebuildOverlaysIfNeeded() {
        let wasEnabled = isEnabled
        destroyOverlays()

        if wasEnabled {
            showOverlays()
        }
    }

    private func start() {
        showOverlays()
        installEventMonitors()
    }

    private func stop() {
        removeEventMonitors()
        stopTimer()
        hideOverlays()
    }

    private func showOverlays() {
        if windows.isEmpty {
            windows = NSScreen.screens.map { screen in
                let view = ClickIndicatorView(frame: NSRect(origin: .zero, size: screen.spotliteOverlayFrame.size))
                return ClickIndicatorWindow(screen: screen, contentView: view)
            }
        }

        for window in windows {
            window.orderFrontRegardless()
        }
    }

    private func hideOverlays() {
        for window in windows {
            window.orderOut(nil)
        }
    }

    private func destroyOverlays() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }

    private func installEventMonitors() {
        guard eventMonitors.isEmpty else { return }

        let leftMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor in
                self?.recordClick(from: event, button: .left)
            }
        }

        let rightMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            Task { @MainActor in
                self?.recordClick(from: event, button: .right)
            }
        }

        let otherMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            Task { @MainActor in
                self?.recordClick(from: event, button: .other)
            }
        }

        eventMonitors = [leftMonitor, rightMonitor, otherMonitor].compactMap { $0 }
    }

    private func removeEventMonitors() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
    }

    private func recordClick(from event: NSEvent, button: ClickIndicatorButton) {
        let screenPoint = event.locationInWindow

        guard let view = view(containing: screenPoint) else { return }
        view.addClick(at: screenPoint, button: button)
        startTimer()
    }

    private func view(containing screenPoint: CGPoint) -> ClickIndicatorView? {
        windows
            .first { $0.frame.contains(screenPoint) }?
            .contentView as? ClickIndicatorView
    }

    private func startTimer() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let hasActiveIndicators = windows
            .compactMap { $0.contentView as? ClickIndicatorView }
            .map { $0.tick() }
            .contains(true)

        if !hasActiveIndicators {
            stopTimer()
        }
    }
}

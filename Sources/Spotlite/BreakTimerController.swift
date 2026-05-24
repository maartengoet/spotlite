import AppKit

@MainActor
final class BreakTimerController {
    var onRunningStateChanged: ((Bool) -> Void)?
    var onDurationChanged: ((Int) -> Void)?

    private let defaults: UserDefaults
    private var selectedDurationSeconds = 5 * 60
    private var endDate: Date?
    private var timer: Timer?
    private var window: BreakTimerWindow?
    private var timerView: BreakTimerView?

    var isRunning: Bool {
        endDate != nil
    }

    var selectedDurationMinutes: Int {
        max(selectedDurationSeconds / 60, 1)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedMinutes = defaults.integer(forKey: "breakTimer.selectedDurationMinutes")
        if storedMinutes > 0 {
            selectedDurationSeconds = min(max(storedMinutes, 1), 240) * 60
        }
    }

    func toggleDefaultTimer() {
        isRunning ? stop() : start(durationSeconds: selectedDurationSeconds)
    }

    func setSelectedDuration(minutes: Int) {
        selectedDurationSeconds = min(max(minutes, 1), 240) * 60
        defaults.set(selectedDurationMinutes, forKey: "breakTimer.selectedDurationMinutes")
        onDurationChanged?(selectedDurationMinutes)
    }

    func start(minutes: Int) {
        let seconds = min(max(minutes, 1), 240) * 60
        start(durationSeconds: seconds)
    }

    func start(durationSeconds: Int) {
        selectedDurationSeconds = min(max(durationSeconds, 60), 240 * 60)
        defaults.set(selectedDurationMinutes, forKey: "breakTimer.selectedDurationMinutes")
        onDurationChanged?(selectedDurationMinutes)
        endDate = Date().addingTimeInterval(TimeInterval(selectedDurationSeconds))
        showWindow()
        startTicker()
        update()
        onRunningStateChanged?(true)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        window?.orderOut(nil)
        window?.close()
        window = nil
        timerView = nil
        onRunningStateChanged?(false)
    }

    func rebuildWindowIfNeeded() {
        guard isRunning else { return }
        window?.orderOut(nil)
        window?.close()
        window = nil
        timerView = nil
        showWindow()
        update()
    }

    private func showWindow() {
        guard window == nil else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let view = BreakTimerView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.autoresizingMask = [.width, .height]
        let window = BreakTimerWindow(screen: screen, contentView: view)
        window.orderFrontRegardless()
        self.window = window
        timerView = view
    }

    private func startTicker() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func update() {
        guard let endDate else { return }

        let remaining = Int(ceil(endDate.timeIntervalSinceNow))
        timerView?.update(remainingSeconds: remaining)

        if remaining <= -60 {
            stop()
        }
    }
}

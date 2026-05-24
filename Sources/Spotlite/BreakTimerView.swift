import AppKit

final class BreakTimerView: NSView {
    private let titleLabel = NSTextField(labelWithString: "Break")
    private let timeLabel = NSTextField(labelWithString: "05:00")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(remainingSeconds: Int) {
        let minutes = max(remainingSeconds, 0) / 60
        let seconds = max(remainingSeconds, 0) % 60
        timeLabel.stringValue = String(format: "%02d:%02d", minutes, seconds)

        if remainingSeconds <= 0 {
            titleLabel.stringValue = "Time"
        } else {
            titleLabel.stringValue = "Break"
        }
    }

    private func buildLayout() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        titleLabel.font = .systemFont(ofSize: 34, weight: .semibold)
        titleLabel.textColor = .white.withAlphaComponent(0.74)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 170, weight: .bold)
        timeLabel.textColor = .white
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(timeLabel)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40)
        ])
    }
}

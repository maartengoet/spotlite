import AppKit

enum ClickIndicatorButton {
    case left
    case right
    case other
}

private struct ClickIndicator {
    var point: CGPoint
    var button: ClickIndicatorButton
    var createdAt: TimeInterval
}

final class ClickIndicatorView: NSView {
    private let duration: TimeInterval = 0.75
    private var indicators: [ClickIndicator] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addClick(at screenPoint: CGPoint, button: ClickIndicatorButton) {
        guard let window else { return }

        let localPoint = CGPoint(
            x: screenPoint.x - window.frame.minX,
            y: screenPoint.y - window.frame.minY
        )

        indicators.append(
            ClickIndicator(
                point: localPoint,
                button: button,
                createdAt: CACurrentMediaTime()
            )
        )
        needsDisplay = true
    }

    func tick() -> Bool {
        let now = CACurrentMediaTime()
        indicators.removeAll { now - $0.createdAt > duration }
        needsDisplay = !indicators.isEmpty
        return !indicators.isEmpty
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let now = CACurrentMediaTime()

        for indicator in indicators {
            let progress = min(max((now - indicator.createdAt) / duration, 0), 1)
            draw(indicator: indicator, progress: progress)
        }
    }

    private func draw(indicator: ClickIndicator, progress: CGFloat) {
        let baseColor = color(for: indicator.button)
        let alpha = max(0, 1 - progress)
        let outerRadius = 18 + (progress * 30)
        let innerRadius = max(3, 7 - (progress * 3))

        let outerRect = CGRect(
            x: indicator.point.x - outerRadius,
            y: indicator.point.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        )

        let outerPath = NSBezierPath(ovalIn: outerRect)
        outerPath.lineWidth = 4
        baseColor.withAlphaComponent(alpha * 0.85).setStroke()
        outerPath.stroke()

        let innerRect = CGRect(
            x: indicator.point.x - innerRadius,
            y: indicator.point.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        )

        let innerPath = NSBezierPath(ovalIn: innerRect)
        baseColor.withAlphaComponent(alpha * 0.95).setFill()
        innerPath.fill()
    }

    private func color(for button: ClickIndicatorButton) -> NSColor {
        switch button {
        case .left:
            return .systemYellow
        case .right:
            return .systemBlue
        case .other:
            return .systemPink
        }
    }
}

import CoreGraphics
import Foundation

enum CursorFocusMode: Equatable {
    case off
    case typingFocus
    case spotlight

    var title: String {
        switch self {
        case .off: "Off"
        case .typingFocus: "Typing Focus"
        case .spotlight: "Spotlight"
        }
    }
}

enum TypingFocusKind {
    case caret
    case selection
}

struct TypingFocusTarget {
    var rect: CGRect
    var kind: TypingFocusKind
    var contextRect: CGRect?

    init(rect: CGRect, kind: TypingFocusKind, contextRect: CGRect? = nil) {
        self.rect = rect
        self.kind = kind
        self.contextRect = contextRect
    }
}

@MainActor
final class CursorFocusSettings {
    var onChange: (() -> Void)?
    private let defaults: UserDefaults
    private var storedSpotlightRadius: CGFloat = 115

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedSpotlightRadius = defaults.double(forKey: "cursorFocus.spotlightRadius")
        if storedSpotlightRadius > 0 {
            self.storedSpotlightRadius = min(max(storedSpotlightRadius, 60), 260)
        }
    }

    var spotlightRadius: CGFloat {
        get { storedSpotlightRadius }
        set {
            let clamped = min(max(newValue, 60), 260)
            guard storedSpotlightRadius != clamped else { return }
            storedSpotlightRadius = clamped
            defaults.set(Double(clamped), forKey: "cursorFocus.spotlightRadius")
            onChange?()
        }
    }

    func increaseSpotlightRadius() {
        spotlightRadius += 20
    }

    func decreaseSpotlightRadius() {
        spotlightRadius -= 20
    }
}

import AppKit

enum AnnotationTool: String, CaseIterable, Equatable {
    case pen
    case highlighter
    case text
    case line
    case arrow
    case rectangle
    case ellipse

    var title: String {
        switch self {
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .text: "Text"
        case .line: "Line"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        }
    }

    var symbolName: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .text: "textformat"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "oval"
        }
    }

    var drawingShortcut: String {
        switch self {
        case .pen: "P"
        case .highlighter: "H"
        case .text: "N"
        case .line: "L"
        case .arrow: "A"
        case .rectangle: "R"
        case .ellipse: "O"
        }
    }
}

enum AnnotationColor: String, CaseIterable, Equatable {
    case red
    case green
    case blue
    case yellow
    case orange
    case pink

    var title: String {
        switch self {
        case .red: "Red"
        case .green: "Green"
        case .blue: "Blue"
        case .yellow: "Yellow"
        case .orange: "Orange"
        case .pink: "Pink"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .red: .systemRed
        case .green: .systemGreen
        case .blue: .systemBlue
        case .yellow: .systemYellow
        case .orange: .systemOrange
        case .pink: .systemPink
        }
    }

    var paletteShortcut: String {
        guard let index = Self.allCases.firstIndex(of: self) else { return "" }
        return String(index + 1)
    }
}

enum DrawingBackground: String, CaseIterable, Equatable {
    case transparent
    case whiteboard
    case blackboard

    var title: String {
        switch self {
        case .transparent: "Transparent"
        case .whiteboard: "Whiteboard"
        case .blackboard: "Blackboard"
        }
    }
}

enum AnnotationAutoEraseDelay: String, CaseIterable, Equatable {
    case off
    case seconds5
    case seconds10
    case seconds30

    var title: String {
        switch self {
        case .off: "Off"
        case .seconds5: "5 Seconds"
        case .seconds10: "10 Seconds"
        case .seconds30: "30 Seconds"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .off: nil
        case .seconds5: 5
        case .seconds10: 10
        case .seconds30: 30
        }
    }
}

@MainActor
final class AnnotationSettings {
    var onChange: (() -> Void)?
    private let defaults: UserDefaults
    private var storedLineWidth: CGFloat = 8
    private var storedTextSize: CGFloat = 36

    var tool: AnnotationTool = .highlighter {
        didSet {
            defaults.set(tool.rawValue, forKey: "annotation.tool")
            onChange?()
        }
    }

    var color: AnnotationColor = .yellow {
        didSet {
            defaults.set(color.rawValue, forKey: "annotation.color")
            onChange?()
        }
    }

    var background: DrawingBackground = .transparent {
        didSet {
            defaults.set(background.rawValue, forKey: "annotation.background")
            onChange?()
        }
    }

    var autoEraseDelay: AnnotationAutoEraseDelay = .off {
        didSet {
            defaults.set(autoEraseDelay.rawValue, forKey: "annotation.autoEraseDelay")
            onChange?()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let rawValue = defaults.string(forKey: "annotation.tool"),
           let tool = AnnotationTool(rawValue: rawValue) {
            self.tool = tool
        }

        if let rawValue = defaults.string(forKey: "annotation.color"),
           let color = AnnotationColor(rawValue: rawValue) {
            self.color = color
        }

        if let rawValue = defaults.string(forKey: "annotation.background"),
           let background = DrawingBackground(rawValue: rawValue) {
            self.background = background
        }

        if let rawValue = defaults.string(forKey: "annotation.autoEraseDelay"),
           let autoEraseDelay = AnnotationAutoEraseDelay(rawValue: rawValue) {
            self.autoEraseDelay = autoEraseDelay
        }

        let storedLineWidth = defaults.double(forKey: "annotation.lineWidth")
        if storedLineWidth > 0 {
            self.storedLineWidth = min(max(storedLineWidth, 2), 32)
        }

        let storedTextSize = defaults.double(forKey: "annotation.textSize")
        if storedTextSize > 0 {
            self.storedTextSize = min(max(storedTextSize, 16), 96)
        }
    }

    var lineWidth: CGFloat {
        get { storedLineWidth }
        set {
            let clamped = min(max(newValue, 2), 32)
            guard storedLineWidth != clamped else { return }
            storedLineWidth = clamped
            defaults.set(Double(clamped), forKey: "annotation.lineWidth")
            onChange?()
        }
    }

    var textSize: CGFloat {
        get { storedTextSize }
        set {
            let clamped = min(max(newValue, 16), 96)
            guard storedTextSize != clamped else { return }
            storedTextSize = clamped
            defaults.set(Double(clamped), forKey: "annotation.textSize")
            onChange?()
        }
    }

    func increaseLineWidth() {
        lineWidth += 2
    }

    func decreaseLineWidth() {
        lineWidth -= 2
    }

    func increaseTextSize() {
        textSize += 4
    }

    func decreaseTextSize() {
        textSize -= 4
    }
}

struct AnnotationStyle {
    var color: NSColor
    var lineWidth: CGFloat
    var textSize: CGFloat
}

enum AnnotationShape {
    case freehand([CGPoint])
    case text(String, at: CGPoint)
    case line(start: CGPoint, end: CGPoint)
    case arrow(start: CGPoint, end: CGPoint)
    case rectangle(CGRect)
    case ellipse(CGRect)
}

struct AnnotationElement {
    var shape: AnnotationShape
    var style: AnnotationStyle
    var createdAt: Date
}

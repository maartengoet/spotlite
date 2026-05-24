import AppKit

extension NSScreen {
    var spotliteOverlayFrame: NSRect {
        let visibleFrame = visibleFrame

        if visibleFrame.width > 0, visibleFrame.height > 0 {
            return visibleFrame
        }

        return frame
    }
}

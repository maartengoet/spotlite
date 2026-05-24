import AppKit
import ServiceManagement

enum LaunchAtLoginStatus {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
}

@MainActor
final class LaunchAtLoginController {
    private var isRunningFromAppBundle: Bool {
        let bundleURL = Bundle.main.bundleURL
        let packageType = Bundle.main.object(forInfoDictionaryKey: "CFBundlePackageType") as? String
        return bundleURL.pathExtension == "app" && packageType == "APPL"
    }

    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return isRunningFromAppBundle ? .disabled : .unavailable
        @unknown default:
            return .unavailable
        }
    }

    @discardableResult
    func enable() throws -> LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return status
        case .notRegistered, .notFound:
            try SMAppService.mainApp.register()
            return status
        @unknown default:
            try SMAppService.mainApp.register()
            return status
        }
    }

    func disable() throws {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            try SMAppService.mainApp.unregister()
        case .notRegistered, .notFound:
            return
        @unknown default:
            return
        }
    }

    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}

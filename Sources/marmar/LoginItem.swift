import Foundation
import ServiceManagement

/// Launch-at-login control via `SMAppService` (the modern, self-contained
/// replacement for hand-managed LaunchAgents). Registers *this* app bundle as a
/// login item, so it must be run from a stable location (e.g. ~/Applications).
enum LoginItem {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled:          return "Enabled"
        case .requiresApproval: return "Needs approval in System Settings"
        case .notRegistered:    return "Not enabled"
        case .notFound:         return "Not installed"
        @unknown default:       return "Unknown"
        }
    }

    /// Returns nil on success, or an error message on failure.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

import ServiceManagement

/// Launch at login through SMAppService. The system owns this state, so it is
/// read back each time rather than stored in Settings.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggle() throws {
        let service = SMAppService.mainApp
        switch service.status {
        case .enabled:
            try service.unregister()
        case .requiresApproval:
            // Registered already, but switched off in System Settings; only the user can turn it on there.
            SMAppService.openSystemSettingsLoginItems()
        default:
            try service.register()
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}

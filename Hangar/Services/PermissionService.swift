import Foundation
import UIKit
import ActivityKit

@MainActor
final class PermissionService: ObservableObject {
    static let shared = PermissionService()

    
    
    @Published var pending: Permission?

    
    private var alreadyPrompted: Set<Permission> = []

    enum Permission: String, Identifiable, CaseIterable {
        case liveActivities

        var id: String { rawValue }

        var title: String {
            switch self {
            case .liveActivities:
                return isGranted ? "Live Activities are on" : "Live Activities are off"
            }
        }

        
        var message: String {
            switch self {
            case .liveActivities:
                let what = "Hangar shows a running command on your Lock Screen and in the Dynamic Island, so you can watch a deploy land without opening the app."
                return isGranted
                    ? "\(what)\n\nYou have already allowed this. You can turn it off in Settings → Hangar."
                    : "\(what) iOS keeps this behind a switch that only you can turn on.\n\nOpen Settings → Hangar and turn on Live Activities."
            }
        }

        var settingsLabel: String { "Open Settings" }

        
        var rowTitle: String {
            switch self {
            case .liveActivities: return "Live Activities"
            }
        }

        var rowDetail: String {
            switch self {
            case .liveActivities: return "Track a running command on the Lock Screen."
            }
        }

        var isGranted: Bool {
            switch self {
            case .liveActivities:
                return ActivityAuthorizationInfo().areActivitiesEnabled
            }
        }
    }

    
    @discardableResult
    func flag(_ permission: Permission) -> Bool {
        guard !permission.isGranted else { return false }
        guard !alreadyPrompted.contains(permission) else { return false }
        alreadyPrompted.insert(permission)
        pending = permission
        return true
    }

    
    func explain(_ permission: Permission) {
        pending = permission
    }

    func dismiss() {
        pending = nil
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        pending = nil
    }
}

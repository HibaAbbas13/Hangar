import Foundation

enum AuthErrorMapper {
    static func message(for error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17008: return "That email address is not valid."
        case 17007: return "That email already has a hangar. Sign in instead."
        case 17009, 17004: return "Email or password is incorrect."
        case 17011: return "No hangar with that email. Tap Register below."
        case 17026: return "Password must be at least 6 characters."
        case 17006: return "Email sign-in is off in Firebase. Enable Authentication → Email/Password."
        case 17020: return "No network. Check the simulator connection and try again."
        case 17995, -34018: return "Simulator keychain blocked this install. Delete the app from the simulator and try Create hangar again."
        case 17010: return "Too many attempts. Wait a moment and retry."
        case 17005: return "This hangar has been disabled."
        case 17014: return "Session is too old. Confirm your identity and try again."
        default:
            return (error as NSError).localizedDescription
        }
    }

    static func isUserNotFound(_ error: Error) -> Bool {
        (error as NSError).code == 17011
    }

    static func isEmailInUse(_ error: Error) -> Bool {
        (error as NSError).code == 17007
    }

    static func requiresRecentLogin(_ error: Error) -> Bool {
        (error as NSError).code == 17014
    }
}

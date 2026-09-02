import Foundation
import FirebaseFunctions

enum AppErrorMapper {
    static func message(for error: Error) -> String {
        if let webhook = error as? WebhookServiceError {
            return webhook.errorDescription ?? "Command failed."
        }
        if let auth = error as? AuthServiceError {
            return auth.errorDescription ?? "Authentication failed."
        }
        if let widget = error as? WidgetTriggerError {
            return widget.errorDescription ?? "Widget trigger failed."
        }
        if let url = error as? URLError {
            return urlMessage(url)
        }
        let ns = error as NSError
        if ns.domain == FunctionsErrorDomain {
            return functionsMessage(ns)
        }
        if ns.domain.contains("FirebaseAuth") || (17000...18000).contains(ns.code) {
            return AuthErrorMapper.message(for: error)
        }
        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Something went wrong. Try again." : text
    }

    private static func urlMessage(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "No network. Check the connection and try again."
        case .timedOut:
            return "The endpoint timed out. Raise the command timeout or check the hook."
        case .cannotFindHost, .dnsLookupFailed:
            return "Could not reach that host. Check the webhook URL."
        case .cannotConnectToHost:
            return "Could not connect to the endpoint."
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return "TLS failed for that endpoint. Use a valid HTTPS certificate."
        case .badURL, .unsupportedURL:
            return "Webhook URL is not valid."
        case .cancelled:
            return "Request cancelled."
        default:
            return "Network fault: \(error.localizedDescription)"
        }
    }

    private static func functionsMessage(_ error: NSError) -> String {
        if let detail = error.userInfo[FunctionsErrorDetailsKey] as? String, detail.isEmpty == false {
            return detail
        }
        let localized = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if localized.isEmpty == false,
           localized.uppercased() != "INTERNAL",
           localized.uppercased() != "UNAVAILABLE" {
            return localized
        }
        switch FunctionsErrorCode(rawValue: error.code) {
        case .unavailable, .deadlineExceeded:
            return "Hangar Cloud is unreachable. Switch to On device or deploy Cloud Functions."
        case .unauthenticated:
            return "Session expired. Sign in again."
        case .permissionDenied:
            return "You do not have access to fire this command."
        case .notFound:
            return "Command or deck was not found."
        case .resourceExhausted:
            return "Too many requests. Wait a moment and retry."
        case .failedPrecondition, .invalidArgument:
            return localized.isEmpty ? "That command could not be run." : localized
        case .unimplemented:
            return "Hangar Cloud is not deployed yet. Use On device mode."
        default:
            return "Hangar Cloud could not complete that command."
        }
    }
}

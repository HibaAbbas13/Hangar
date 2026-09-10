import Foundation
import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore

enum AuthServiceError: LocalizedError {
    case firebaseNotConfigured
    case invalidCredential
    case cancelled
    case missingUser
    case needsReauthentication

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase is not configured. Add GoogleService-Info.plist from your Firebase console."
        case .invalidCredential:
            return "Apple could not verify this sign-in."
        case .cancelled:
            return "Sign in was cancelled."
        case .missingUser:
            return "No authenticated operator."
        case .needsReauthentication:
            return "For security, confirm your identity before deleting the hangar."
        }
    }
}

final class AuthService: NSObject {
    static let shared = AuthService()

    
    
    private(set) var pendingDisplayName: String?

    private var currentNonce: String?
    private var continuation: CheckedContinuation<AuthCredential, Error>?

    var userId: String? { Auth.auth().currentUser?.uid }
    var isConfigured: Bool { FirebaseApp.app() != nil }

    
    var providerIds: [String] {
        Auth.auth().currentUser?.providerData.map(\.providerID) ?? []
    }

    var hasPasswordProvider: Bool { providerIds.contains("password") }
    var hasAppleProvider: Bool { providerIds.contains("apple.com") }

    func currentUser() -> User? {
        Auth.auth().currentUser
    }

    func idToken(forcingRefresh: Bool = false) async throws -> String {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.missingUser }
        return try await user.getIDTokenResult(forcingRefresh: forcingRefresh).token
    }

    func signInWithApple() async throws {
        let credential = try await appleCredential()
        _ = try await Auth.auth().signIn(with: credential)
    }

    func signIn(email: String, password: String) async throws {
        guard isConfigured else { throw AuthServiceError.firebaseNotConfigured }
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func register(email: String, password: String, displayName: String) async throws {
        guard isConfigured else { throw AuthServiceError.firebaseNotConfigured }
        pendingDisplayName = displayName
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let change = result.user.createProfileChangeRequest()
        change.displayName = displayName
        try await change.commitChanges()
    }

    func sendPasswordReset(email: String) async throws {
        guard isConfigured else { throw AuthServiceError.firebaseNotConfigured }
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func signOut() throws {
        pendingDisplayName = nil
        try Auth.auth().signOut()
        AppGroupStore.defaults.removeObject(forKey: SharedConstants.DefaultsKey.idToken)
        AppGroupStore.persist()
    }

    func persistToken() async {
        guard let token = try? await idToken() else { return }
        AppGroupStore.defaults.set(token, forKey: SharedConstants.DefaultsKey.idToken)
        WebhookService.shared.persistBaseURL()
        AppGroupStore.persist()
    }

    

    func reauthenticate(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw AuthServiceError.missingUser
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        _ = try await user.reauthenticate(with: credential)
    }

    func reauthenticateWithApple() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.missingUser }
        let credential = try await appleCredential()
        _ = try await user.reauthenticate(with: credential)
    }

    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.missingUser }
        do {
            try await user.delete()
        } catch {
            if AuthErrorMapper.requiresRecentLogin(error) {
                throw AuthServiceError.needsReauthentication
            }
            throw error
        }
        AppGroupStore.defaults.removeObject(forKey: SharedConstants.DefaultsKey.idToken)
        AppGroupStore.persist()
    }

    

    @MainActor
    private func appleCredential() async throws -> AuthCredential {
        guard isConfigured else { throw AuthServiceError.firebaseNotConfigured }
        let nonce = CryptoService.randomNonce()
        currentNonce = nonce
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = CryptoService.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AuthCredential, Error>) in
            self.continuation = cont
            controller.performRequests()
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: AuthServiceError.invalidCredential)
            continuation = nil
            return
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        continuation?.resume(returning: firebaseCredential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let ns = error as NSError
        if ns.code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: AuthServiceError.cancelled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

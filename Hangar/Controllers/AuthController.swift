import Foundation
import Combine

@MainActor
final class AuthController: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var displayName = ""
    @Published var isRegistering = true
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var showResetSheet = false
    @Published var resetEmail = ""
    @Published var isSendingReset = false
    @Published var resetError: String?
    @Published var resetSent = false

    private let auth = AuthService.shared

    func signInApple() async {
        #if targetEnvironment(simulator)
        errorMessage = "Apple Sign-In does not work in the Simulator. Create a hangar with email below."
        return
        #else
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await auth.signInWithApple()
            await auth.persistToken()
        } catch AuthServiceError.cancelled {
            errorMessage = nil
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
        #endif
    }

    func submitEmail() async {
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pass = password
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard mail.contains("@"), mail.contains(".") else {
            errorMessage = "Enter a valid email."
            return
        }
        guard pass.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            if isRegistering {
                try await auth.register(
                    email: mail,
                    password: pass,
                    displayName: name.isEmpty ? String(mail.split(separator: "@").first ?? "Operator") : name
                )
            } else {
                try await auth.signIn(email: mail, password: pass)
            }
            await auth.persistToken()
        } catch {
            if AuthErrorMapper.isUserNotFound(error) {
                isRegistering = true
                errorMessage = "No hangar with that email. Fill a callsign and tap Create hangar."
                return
            }
            if AuthErrorMapper.isEmailInUse(error) {
                isRegistering = false
                errorMessage = "That email already has a hangar. Sign in instead."
                return
            }
            errorMessage = AuthErrorMapper.message(for: error)
        }
    }

    func openReset() {
        resetEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        resetError = nil
        resetSent = false
        showResetSheet = true
    }

    func sendPasswordReset() async {
        let mail = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard mail.contains("@"), mail.contains(".") else {
            resetError = "Enter the email on your hangar."
            return
        }
        isSendingReset = true
        resetError = nil
        defer { isSendingReset = false }
        do {
            try await auth.sendPasswordReset(email: mail)
            resetSent = true
        } catch {
            
            
            if AuthErrorMapper.isUserNotFound(error) {
                resetSent = true
                return
            }
            resetError = AuthErrorMapper.message(for: error)
        }
    }

    func enterSampleHangar() async {
        guard !isWorking else { return }
        guard Constants.Demo.isConfigured else {
            errorMessage = "Sample hangar credentials are not configured for this build."
            return
        }
        UserDefaults.standard.set(false, forKey: Constants.Demo.autoHangarFlag)
        email = Constants.Demo.email
        password = Constants.Demo.password
        displayName = Constants.Demo.callsign
        isRegistering = false
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await auth.signIn(email: Constants.Demo.email, password: Constants.Demo.password)
            await auth.persistToken()
        } catch {
            if AuthErrorMapper.isUserNotFound(error) {
                do {
                    try await auth.register(
                        email: Constants.Demo.email,
                        password: Constants.Demo.password,
                        displayName: Constants.Demo.callsign
                    )
                    await auth.persistToken()
                } catch {
                    errorMessage = AuthErrorMapper.message(for: error)
                }
                return
            }
            errorMessage = AuthErrorMapper.message(for: error)
        }
    }
}

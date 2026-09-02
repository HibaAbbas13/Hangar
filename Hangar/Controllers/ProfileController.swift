import Foundation
import Combine

@MainActor
final class ProfileController: ObservableObject {
    enum DeleteStage: Equatable {
        case idle
        case confirming
        
        case needsPassword
        case working
    }

    @Published var displayName = ""
    @Published var isSavingName = false
    @Published var nameNotice: String?

    @Published var deleteStage: DeleteStage = .idle
    @Published var reauthPassword = ""
    @Published var deleteError: String?

    private let users = UserRepository()
    private let account = AccountRepository()
    private let auth = AuthService.shared

    var usesApplePasswordless: Bool { !auth.hasPasswordProvider && auth.hasAppleProvider }

    func load(_ profile: UserProfile?) {
        guard displayName.isEmpty else { return }
        displayName = profile?.displayName ?? ""
    }

    func saveName(profile: UserProfile) async -> UserProfile {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameNotice = "Callsign cannot be empty."
            return profile
        }
        isSavingName = true
        nameNotice = nil
        defer { isSavingName = false }
        var next = profile
        next.displayName = trimmed
        do {
            try await users.save(next)
            nameNotice = "Callsign saved."
            HapticService.success()
            return next
        } catch {
            nameNotice = error.localizedDescription
            return profile
        }
    }

    func beginDelete() {
        deleteError = nil
        reauthPassword = ""
        deleteStage = .confirming
    }

    func cancelDelete() {
        deleteStage = .idle
        reauthPassword = ""
        deleteError = nil
    }

    
    
    func confirmDelete(userId: String) async -> Bool {
        deleteStage = .working
        deleteError = nil
        do {
            try await account.purge(userId: userId)
            try await auth.deleteAccount()
            HapticService.success()
            return true
        } catch AuthServiceError.needsReauthentication {
            return await reauthenticateThenDelete(userId: userId)
        } catch {
            deleteError = AuthErrorMapper.message(for: error)
            deleteStage = .confirming
            HapticService.error()
            return false
        }
    }

    
    
    private func reauthenticateThenDelete(userId: String) async -> Bool {
        guard usesApplePasswordless else {
            deleteStage = .needsPassword
            deleteError = "Enter your passcode to confirm."
            return false
        }
        do {
            try await auth.reauthenticateWithApple()
            try? await account.purge(userId: userId)
            try await auth.deleteAccount()
            HapticService.success()
            deleteStage = .idle
            return true
        } catch AuthServiceError.cancelled {
            deleteStage = .confirming
            deleteError = nil
            return false
        } catch {
            deleteStage = .confirming
            deleteError = AuthErrorMapper.message(for: error)
            return false
        }
    }

    func confirmDeleteWithPassword(userId: String) async -> Bool {
        guard !reauthPassword.isEmpty else {
            deleteError = "Enter your passcode."
            return false
        }
        deleteStage = .working
        deleteError = nil
        do {
            try await auth.reauthenticate(password: reauthPassword)
            try await account.purge(userId: userId)
            try await auth.deleteAccount()
            HapticService.success()
            reauthPassword = ""
            return true
        } catch {
            deleteError = AuthErrorMapper.message(for: error)
            deleteStage = .needsPassword
            HapticService.error()
            return false
        }
    }
}

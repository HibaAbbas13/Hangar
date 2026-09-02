import Foundation

@MainActor
final class SettingsController: ObservableObject {
    @Published var errorMessage: String?

    private let users = UserRepository()

    func updateTheme(_ preference: ThemePreference, profile: UserProfile) async -> UserProfile {
        var next = profile
        next.themePreference = preference
        do {
            try await users.save(next)
            errorMessage = nil
            return next
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            HapticService.error()
            return profile
        }
    }

    func updateMode(_ mode: ExecutionMode, profile: UserProfile) async -> UserProfile {
        var next = profile
        next.executionMode = mode
        do {
            try await users.save(next)
            errorMessage = nil
            HapticService.select()
            return next
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            HapticService.error()
            return profile
        }
    }
}

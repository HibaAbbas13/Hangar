import Foundation
import FirebaseFirestore

@MainActor
final class TeamController: ObservableObject {
    @Published var members: [TeamMember] = []
    @Published var invite: DeckInvite?
    @Published var joinCode = ""
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var isWorking = false

    private let repo = TeamRepository()
    private var listener: ListenerRegistration?
    private var ownerId = ""
    private var deckId = ""

    func start(ownerId: String, deckId: String) {
        if self.ownerId == ownerId && self.deckId == deckId { return }
        listener?.remove()
        self.ownerId = ownerId
        self.deckId = deckId
        errorMessage = nil
        listener = repo.observeMembers(ownerId: ownerId, deckId: deckId) { [weak self] members in
            Task { @MainActor in self?.members = members }
        } onError: { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = AppErrorMapper.message(for: error)
            }
        }
    }

    func createInvite(deck: Deck) async {
        isWorking = true
        errorMessage = nil
        notice = nil
        defer { isWorking = false }
        do {
            invite = try await repo.createInvite(deck: deck)
            notice = "Invite ready"
            HapticService.success()
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            HapticService.error()
        }
    }

    func join(userId: String, displayName: String, email: String) async {
        isWorking = true
        errorMessage = nil
        notice = nil
        defer { isWorking = false }
        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.isEmpty == false else {
            errorMessage = "Enter an invite code."
            return
        }
        do {
            try await repo.join(code: code, userId: userId, displayName: displayName, email: email)
            joinCode = ""
            notice = "Joined deck"
            HapticService.success()
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            HapticService.error()
        }
    }

    func remove(_ member: TeamMember) async {
        errorMessage = nil
        notice = nil
        do {
            try await repo.removeMember(ownerId: ownerId, deckId: deckId, memberId: member.id)
            notice = "Operator removed"
            HapticService.medium()
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            HapticService.error()
        }
    }
}

import Foundation
import AVFoundation

@MainActor
final class SoundService: ObservableObject {
    static let shared = SoundService()

    enum Cue: String, CaseIterable {
        case press = "fd_press"
        case success = "fd_success"
        case fault = "fd_fault"
    }

    private static let enabledKey = "fd.sound.enabled"

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    private var players: [Cue: AVAudioPlayer] = [:]
    private var sessionReady = false

    private init() {
        
        
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    func play(_ cue: Cue) {
        guard isEnabled else { return }
        prepareSessionIfNeeded()
        guard let player = player(for: cue) else { return }
        player.currentTime = 0
        player.play()
    }

    
    func preview(_ cue: Cue) {
        prepareSessionIfNeeded()
        guard let player = player(for: cue) else { return }
        player.currentTime = 0
        player.play()
    }

    private func prepareSessionIfNeeded() {
        guard !sessionReady else { return }
        sessionReady = true
        
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func player(for cue: Cue) -> AVAudioPlayer? {
        if let existing = players[cue] { return existing }
        guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        players[cue] = player
        return player
    }
}

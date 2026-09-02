import Foundation

enum AppTier: String, Codable, CaseIterable, Hashable {
    case free
    case premium
}

enum ServiceProvider: String, Codable, CaseIterable, Identifiable, Hashable {
    case vercel
    case github
    case netlify
    case supabase
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vercel: return "Vercel"
        case .github: return "GitHub"
        case .netlify: return "Netlify"
        case .supabase: return "Supabase"
        case .custom: return "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .vercel: return "triangle.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .netlify: return "dot.radiowaves.up.forward"
        case .supabase: return "cylinder.split.1x2"
        case .custom: return "slider.horizontal.2.square"
        }
    }

    var shortCallsign: String {
        switch self {
        case .vercel: return "VCL"
        case .github: return "GHB"
        case .netlify: return "NTL"
        case .supabase: return "SAB"
        case .custom: return "CST"
        }
    }
}

enum HTTPMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case GET, POST, PUT, PATCH, DELETE
    var id: String { rawValue }
}

enum TriggerStatus: String, Codable, Hashable {
    case idle
    case queued
    case running
    case succeeded
    case failed
    case blocked
}

enum MemberRole: String, Codable, Hashable {
    case owner
    case operatorRole = "operator"
}

enum ExecutionMode: String, Codable, CaseIterable, Identifiable {
    case onDevice
    case cloudProxy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onDevice: return "On device"
        case .cloudProxy: return "Hangar Cloud"
        }
    }

    var subtitle: String {
        switch self {
        case .onDevice: return "Fires webhooks from this iPhone. Works without Cloud Functions."
        case .cloudProxy: return "Fires through Hangar Cloud so widgets and Siri stay secret-safe."
        }
    }
}

enum ThemePreference: String, Codable, CaseIterable, Identifiable {
    case night
    case day
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .night: return "Night ops"
        case .day: return "Day ops"
        case .system: return "Match system"
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case decks
    case console
    case flows
    case hangar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .decks: return "Decks"
        case .console: return "Console"
        case .flows: return "Flows"
        case .hangar: return "Account"
        }
    }

    var symbolName: String {
        switch self {
        case .decks: return "square.grid.2x2"
        case .console: return "terminal"
        case .flows: return "arrow.triangle.branch"
        case .hangar: return "person.crop.square"
        }
    }
}

enum PremiumGate: String {
    case extraDeck
    case extraButton
    case liveActivity
    case siriMacro
    case teamSync
    case automation
}

enum ButtonIcon: String, CaseIterable, Identifiable, Hashable {
    case bolt = "bolt.fill"
    case rollback = "arrow.uturn.backward.circle.fill"
    case rocket = "paperplane.fill"
    case pause = "pause.fill"
    case play = "play.fill"
    case flame = "flame.fill"
    case shield = "lock.shield.fill"
    case antenna = "antenna.radiowaves.left.and.right"
    case cloud = "cloud.fill"
    case wrench = "wrench.and.screwdriver.fill"
    case banner = "flag.fill"
    case skull = "exclamationmark.octagon.fill"
    case sync = "arrow.triangle.2.circlepath"
    case database = "externaldrive.fill"
    case branch = "arrow.triangle.branch"
    case check = "checkmark.seal.fill"

    var id: String { rawValue }
}

enum InviteStatus: String, Codable {
    case active
    case revoked
    case consumed
}

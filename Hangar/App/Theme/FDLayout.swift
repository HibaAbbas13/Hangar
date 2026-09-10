import SwiftUI

/// The spacing scale. Every gap in the app is one of these, so screens that
/// were built months apart still line up with each other.
enum FDSpace {
    /// Between a label and the thing it labels.
    static let hair: CGFloat = 4
    /// Inside a chip or a tight stack.
    static let tight: CGFloat = 8
    /// The default gap between siblings.
    static let snug: CGFloat = 12
    /// Card padding, and the gap between cards.
    static let base: CGFloat = 16
    /// Screen gutter.
    static let gutter: CGFloat = 20
    /// Between sections of a screen.
    static let section: CGFloat = 24
    /// Above a section heading that starts a new idea.
    static let major: CGFloat = 32
}

/// The floating tab bar is drawn over the content, so every scroll view owes
/// its last row this much clearance. Hard-coding it in each screen is how rows
/// ended up hidden behind the bar.
enum FDChromeInset {
    /// Tab bar height + its own padding + room for the run HUD above it.
    static let bottom: CGFloat = 108
}

/// The outcome of the last run of a command, in the form the pad shows it.
///
/// A status code and a duration are the two things an operator actually reads
/// after a press, and they were previously only visible in History. The age
/// matters as much as the result: a green tick from yesterday should not read
/// like one from ten seconds ago.
struct FDRunOutcome: Equatable {
    var status: TriggerStatus
    var statusCode: Int?
    var durationMs: Int
    var at: Date?

    /// True while the result is fresh enough to colour the key. After this the
    /// key goes back to neutral and the outcome reads as history, not state.
    var isRecent: Bool {
        guard let at else { return false }
        return Date().timeIntervalSince(at) < 600
    }

    var hasRun: Bool { at != nil && status != .idle }

    /// "200" — or a word, when there is no code to show. Records written
    /// before the code was stored still say something truthful rather than a
    /// dash that reads like an error.
    var codeText: String {
        if let statusCode { return "\(statusCode)" }
        switch status {
        case .succeeded: return "OK"
        case .failed: return "No reply"
        case .blocked: return "Blocked"
        default: return "—"
        }
    }

    var durationText: String {
        if durationMs <= 0 { return "" }
        if durationMs < 1000 { return "\(durationMs) ms" }
        return String(format: "%.1f s", Double(durationMs) / 1000)
    }

    static func format(duration ms: Int) -> String {
        if ms < 1000 { return "\(ms) ms" }
        return String(format: "%.1f s", Double(ms) / 1000)
    }

    /// "just now" / "4 min ago" / "2 hr ago".
    ///
    /// The system relative formatter renders a run that just landed as
    /// "0 sec ago", and a Firestore server timestamp a few hundred milliseconds
    /// ahead of the phone's clock as "in 0 sec" — both of which read like bugs.
    /// Anything under a minute, in either direction, is simply now.
    static func relative(_ date: Date, from now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 60 { return "just now" }
        return date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }
}

extension TriggerStatus {
    /// The colour for this status. Kept in one place because status colour was
    /// being re-derived, slightly differently, in five separate views.
    func tint(_ theme: FDPalette) -> Color {
        switch self {
        case .succeeded: return theme.moss
        case .failed, .blocked: return theme.rust
        case .running, .queued: return theme.brass
        case .idle: return theme.fog
        }
    }

    /// Shape as well as colour, so status survives colour blindness and
    /// greyscale. Never rely on `tint` alone.
    var symbolName: String {
        switch self {
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .blocked: return "hand.raised.fill"
        case .running, .queued: return "circle.dotted"
        case .idle: return "circle"
        }
    }

    /// What an operator would call it, not what the wire calls it.
    var plainTitle: String {
        switch self {
        case .succeeded: return "OK"
        case .failed: return "Failed"
        case .blocked: return "Blocked"
        case .running: return "In flight"
        case .queued: return "Queued"
        case .idle: return "Not run"
        }
    }
}

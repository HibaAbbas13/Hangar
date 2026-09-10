import SwiftUI
import UIKit

struct FDPalette {
    let void: Color
    let panel: Color
    let raised: Color
    let inset: Color
    let brass: Color
    let brassSoft: Color
    let bone: Color
    let fog: Color
    let rust: Color
    let moss: Color
    let hairline: Color
    let warning: Color
    let chrome: Color

    
    
    
    static let night = FDPalette(
        void: Color(red: 0.055, green: 0.059, blue: 0.067),
        panel: Color(red: 0.090, green: 0.098, blue: 0.110),
        raised: Color(red: 0.122, green: 0.133, blue: 0.149),
        inset: Color(red: 0.035, green: 0.039, blue: 0.047),
        brass: Color(red: 0.298, green: 0.604, blue: 0.941),
        brassSoft: Color(red: 0.435, green: 0.690, blue: 0.961),
        bone: Color(red: 0.910, green: 0.918, blue: 0.929),
        fog: Color(red: 0.486, green: 0.518, blue: 0.549),
        rust: Color(red: 0.878, green: 0.322, blue: 0.322),
        moss: Color(red: 0.310, green: 0.706, blue: 0.467),
        hairline: Color(red: 0.149, green: 0.161, blue: 0.180),
        warning: Color(red: 0.941, green: 0.541, blue: 0.235),
        chrome: Color(red: 0.596, green: 0.631, blue: 0.663)
    )

    static let day = FDPalette(
        void: Color(red: 0.886, green: 0.894, blue: 0.906),
        panel: Color(red: 0.961, green: 0.965, blue: 0.973),
        raised: Color(red: 1.0, green: 1.0, blue: 1.0),
        inset: Color(red: 0.839, green: 0.851, blue: 0.867),
        brass: Color(red: 0.106, green: 0.396, blue: 0.729),
        brassSoft: Color(red: 0.176, green: 0.478, blue: 0.816),
        bone: Color(red: 0.063, green: 0.075, blue: 0.090),
        fog: Color(red: 0.325, green: 0.353, blue: 0.388),
        rust: Color(red: 0.729, green: 0.184, blue: 0.184),
        moss: Color(red: 0.129, green: 0.494, blue: 0.310),
        hairline: Color(red: 0.729, green: 0.745, blue: 0.765),
        warning: Color(red: 0.780, green: 0.396, blue: 0.086),
        chrome: Color(red: 0.286, green: 0.318, blue: 0.353)
    )
}

struct FDThemeKey: EnvironmentKey {
    static let defaultValue = FDPalette.night
}

extension EnvironmentValues {
    var fdTheme: FDPalette {
        get { self[FDThemeKey.self] }
        set { self[FDThemeKey.self] = newValue }
    }
}

/// One corner scale for the whole app. Before this there were four different
/// radii in play and nothing said which to use where.
enum FDRadius {
    /// Inputs and small chips.
    static let field: CGFloat = 14
    /// Command keys — the hero control.
    static let key: CGFloat = 22
    /// Panels and cards.
    static let card: CGFloat = 22
    /// The recessed well the pad sits in.
    static let well: CGFloat = 28
}

/// Depth is a system, not a per-view guess: how far a surface sits above the
/// panel behind it.
enum FDElevation {
    case flush, raised, floating

    var radius: CGFloat {
        switch self {
        case .flush: return 4
        case .raised: return 14
        case .floating: return 26
        }
    }

    var y: CGFloat {
        switch self {
        case .flush: return 1
        case .raised: return 8
        case .floating: return 14
        }
    }

    var opacity: Double {
        switch self {
        case .flush: return 0.22
        case .raised: return 0.34
        case .floating: return 0.46
        }
    }
}

enum FDFont {
    
    
    
    
    private static func scaled(_ size: CGFloat, _ style: UIFont.TextStyle, cap: CGFloat = 1.6) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: style)
        let grown = metrics.scaledValue(for: size)
        return min(grown, size * cap)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: scaled(size, .title1, cap: 1.4), weight: weight, design: .serif)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size, .body), weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size, .body, cap: 1.45), weight: weight, design: .monospaced)
    }

    static func micro(_ size: CGFloat = 11) -> Font {
        .system(size: scaled(size, .caption1, cap: 1.35), weight: .semibold, design: .default)
    }
}

struct FDThemeResolver {
    static func palette(preference: ThemePreference, system: ColorScheme) -> FDPalette {
        switch preference {
        case .night: return .night
        case .day: return .day
        case .system: return system == .dark ? .night : .day
        }
    }
}

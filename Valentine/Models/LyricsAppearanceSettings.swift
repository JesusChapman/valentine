import SwiftUI
import Combine

enum LyricsTransitionStyle: Int, CaseIterable, Identifiable {
    case fade
    case slide
    case spotlight
    case bounce

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fade: return "Fade"
        case .slide: return "Slide"
        case .spotlight: return "Spotlight"
        case .bounce: return "Bounce"
        }
    }

    var animation: Animation {
        switch self {
        case .fade: return .easeInOut(duration: 0.35)
        case .slide: return .easeOut(duration: 0.42)
        case .spotlight: return .easeInOut(duration: 0.38)
        case .bounce: return .spring(response: 0.42, dampingFraction: 0.62)
        }
    }

    var inactiveOpacity: Double {
        switch self {
        case .fade: return 0.18
        case .slide: return 0.42
        case .spotlight: return 0.16
        case .bounce: return 0.30
        }
    }

    var inactiveScale: CGFloat {
        switch self {
        case .fade: return 1
        case .slide: return 0.90
        case .spotlight: return 0.80
        case .bounce: return 0.76
        }
    }

    var activeScale: CGFloat {
        self == .bounce ? 1.14 : (self == .spotlight ? 1.06 : 1)
    }

    var inactiveOffset: CGFloat {
        self == .slide ? 26 : (self == .bounce ? 10 : 0)
    }

    var inactiveBlur: CGFloat {
        self == .spotlight ? 3.5 : (self == .fade ? 0.8 : 0)
    }
}

class LyricsAppearanceManager: ObservableObject {
    static let shared = LyricsAppearanceManager()
    
    @Published var fontDesignLight: Int { didSet { save(fontDesignLight, forKey: "lyricsFontDesignLight") } }
    @Published var fontDesignDark: Int { didSet { save(fontDesignDark, forKey: "lyricsFontDesignDark") } }
    @Published var fontColorLight: String { didSet { save(fontColorLight, forKey: "lyricsFontColorLight") } }
    @Published var fontColorDark: String { didSet { save(fontColorDark, forKey: "lyricsFontColorDark") } }
    @Published var neonColorLight: String { didSet { save(neonColorLight, forKey: "lyricsNeonColorLight") } }
    @Published var neonColorDark: String { didSet { save(neonColorDark, forKey: "lyricsNeonColorDark") } }
    @Published var glowColorLight: String { didSet { save(glowColorLight, forKey: "lyricsGlowColorLight") } }
    @Published var glowColorDark: String { didSet { save(glowColorDark, forKey: "lyricsGlowColorDark") } }
    @Published var usesAlbumColorForNeon: Bool { didSet { save(usesAlbumColorForNeon, forKey: "lyricsUseAlbumColorForNeon") } }
    @Published var usesAlbumColorForGlow: Bool { didSet { save(usesAlbumColorForGlow, forKey: "lyricsUseAlbumColorForGlow") } }
    @Published var lyricsTransitionStyle: Int { didSet { save(lyricsTransitionStyle, forKey: "lyricsTransitionStyle") } }

    private init(defaults: UserDefaults = .standard) {
        fontDesignLight = defaults.object(forKey: "lyricsFontDesignLight") as? Int ?? 1
        fontDesignDark = defaults.object(forKey: "lyricsFontDesignDark") as? Int ?? 1
        fontColorLight = defaults.string(forKey: "lyricsFontColorLight") ?? ""
        fontColorDark = defaults.string(forKey: "lyricsFontColorDark") ?? ""
        neonColorLight = defaults.string(forKey: "lyricsNeonColorLight") ?? "#ffffff"
        neonColorDark = defaults.string(forKey: "lyricsNeonColorDark") ?? "#ffffff"
        glowColorLight = defaults.string(forKey: "lyricsGlowColorLight") ?? ""
        glowColorDark = defaults.string(forKey: "lyricsGlowColorDark") ?? ""
        usesAlbumColorForNeon = defaults.bool(forKey: "lyricsUseAlbumColorForNeon")
        usesAlbumColorForGlow = defaults.bool(forKey: "lyricsUseAlbumColorForGlow")
        lyricsTransitionStyle = defaults.object(forKey: "lyricsTransitionStyle") as? Int ?? LyricsTransitionStyle.fade.rawValue
    }

    private func save(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    var transitionStyle: LyricsTransitionStyle {
        LyricsTransitionStyle(rawValue: lyricsTransitionStyle) ?? .fade
    }
    
    func getFontDesign(isDark: Bool) -> Font.Design {
        let value = isDark ? fontDesignDark : fontDesignLight
        switch value {
        case 0: return .default
        case 1: return .rounded
        case 2: return .monospaced
        case 3: return .serif
        default: return .rounded
        }
    }
    
    func getFontColor(isDark: Bool, isActive: Bool) -> Color {
        let hex = isDark ? fontColorDark : fontColorLight
        if hex.isEmpty {
            return isActive ? .primary : .secondary
        }
        return Color(hex: hex).opacity(isActive ? 1.0 : 0.6)
    }
    
    func getNeonColor(isDark: Bool) -> Color {
        let hex = isDark ? neonColorDark : neonColorLight
        return hex.isEmpty ? .white : Color(hex: hex)
    }
    
    func getGlowColor(isDark: Bool) -> Color {
        let hex = isDark ? glowColorDark : glowColorLight
        return hex.isEmpty ? .accentColor : Color(hex: hex)
    }
    
    func resetToDefaults() {
        let defaults = UserDefaults.standard
        [
            "lyricsFontDesignLight", "lyricsFontDesignDark",
            "lyricsFontColorLight", "lyricsFontColorDark",
            "lyricsNeonColorLight", "lyricsNeonColorDark",
            "lyricsGlowColorLight", "lyricsGlowColorDark",
            "lyricsUseAlbumColorForNeon", "lyricsUseAlbumColorForGlow",
            "lyricsTransitionStyle"
        ].forEach(defaults.removeObject(forKey:))

        fontDesignLight = 1
        fontDesignDark = 1
        fontColorLight = ""
        fontColorDark = ""
        neonColorLight = "#ffffff"
        neonColorDark = "#ffffff"
        glowColorLight = ""
        glowColorDark = ""
        usesAlbumColorForNeon = false
        usesAlbumColorForGlow = false
        lyricsTransitionStyle = LyricsTransitionStyle.fade.rawValue
    }
}

import SwiftUI
import Combine

class LyricsAppearanceManager: ObservableObject {
    static let shared = LyricsAppearanceManager()
    
    @Published var updateTrigger: Bool = false
    
    @AppStorage("lyricsFontDesignLight") var fontDesignLight: Int = 1
    @AppStorage("lyricsFontDesignDark") var fontDesignDark: Int = 1
    
    @AppStorage("lyricsFontColorLight") var fontColorLight: String = ""
    @AppStorage("lyricsFontColorDark") var fontColorDark: String = ""
    
    @AppStorage("lyricsNeonColorLight") var neonColorLight: String = "#ffffff"
    @AppStorage("lyricsNeonColorDark") var neonColorDark: String = "#ffffff"
    
    @AppStorage("lyricsGlowColorLight") var glowColorLight: String = ""
    @AppStorage("lyricsGlowColorDark") var glowColorDark: String = ""
    
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
        fontDesignLight = 1
        fontDesignDark = 1
        fontColorLight = ""
        fontColorDark = ""
        neonColorLight = "#ffffff"
        neonColorDark = "#ffffff"
        glowColorLight = ""
        glowColorDark = ""
    }
}

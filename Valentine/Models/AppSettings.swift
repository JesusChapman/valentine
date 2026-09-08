import Combine
import Foundation

/// Shared settings with immediate view updates and durable UserDefaults storage.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    @Published var standbyAudioRing: Bool {
        didSet { UserDefaults.standard.set(standbyAudioRing, forKey: "standbyAudioRing") }
    }
    @Published var musicReactiveBackground: Bool {
        didSet { UserDefaults.standard.set(musicReactiveBackground, forKey: "musicReactiveBackground") }
    }

    @Published var appTheme: Int {
        didSet { UserDefaults.standard.set(appTheme, forKey: Keys.appTheme) }
    }
    @Published var miniPlayerGlassMode: Int {
        didSet { UserDefaults.standard.set(miniPlayerGlassMode, forKey: Keys.miniPlayerGlassMode) }
    }
    @Published var isGlowEffectEnabled: Bool {
        didSet { UserDefaults.standard.set(isGlowEffectEnabled, forKey: Keys.glowEffect) }
    }
    @Published var isNeonEffectEnabled: Bool {
        didSet { UserDefaults.standard.set(isNeonEffectEnabled, forKey: Keys.neonEffect) }
    }

    private enum Keys {
        static let appTheme = "appTheme"
        static let miniPlayerGlassMode = "miniPlayerGlassMode"
        static let glowEffect = "isGlowEffectEnabled"
        static let neonEffect = "isNeonEffectEnabled"
    }

    private init(defaults: UserDefaults = .standard) {
        standbyAudioRing = defaults.bool(forKey: "standbyAudioRing")
        musicReactiveBackground = defaults.bool(forKey: "musicReactiveBackground")
        appTheme = defaults.integer(forKey: Keys.appTheme)
        miniPlayerGlassMode = defaults.integer(forKey: Keys.miniPlayerGlassMode)
        isGlowEffectEnabled = defaults.bool(forKey: Keys.glowEffect)
        isNeonEffectEnabled = defaults.bool(forKey: Keys.neonEffect)
    }
}

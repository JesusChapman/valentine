import SwiftUI

struct LyricsAppearanceView: View {
    @ObservedObject var settings = LyricsAppearanceManager.shared
    @ObservedObject private var appSettings = AppSettings.shared
    
    @State private var previewIsDark = true
    @State private var applyMode = 0 // 0: Both Themes, 1: Specific Theme
    
    // Bindings for the currently selected theme to edit
    private var isEditingDark: Bool {
        if applyMode == 0 { return previewIsDark }
        return previewIsDark // Wait, if specific theme, it edits the preview's current theme.
    }
    
    private var fontDesignBinding: Binding<Int> {
        Binding(
            get: { isEditingDark ? settings.fontDesignDark : settings.fontDesignLight },
            set: { newValue in
                if applyMode == 0 {
                    settings.fontDesignDark = newValue
                    settings.fontDesignLight = newValue
                } else {
                    if isEditingDark { settings.fontDesignDark = newValue }
                    else { settings.fontDesignLight = newValue }
                }
            }
        )
    }
    
    private func colorBinding(for stringBindingLight: Binding<String>, stringBindingDark: Binding<String>, defaultColor: Color) -> Binding<Color> {
        Binding<Color>(
            get: {
                let hex = isEditingDark ? stringBindingDark.wrappedValue : stringBindingLight.wrappedValue
                return hex.isEmpty ? defaultColor : Color(hex: hex)
            },
            set: { newValue in
                let hex = newValue.toHex()
                if applyMode == 0 {
                    stringBindingDark.wrappedValue = hex
                    stringBindingLight.wrappedValue = hex
                } else {
                    if isEditingDark { stringBindingDark.wrappedValue = hex }
                    else { stringBindingLight.wrappedValue = hex }
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // PREVIEW SECTION
            VStack {
                HStack {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("Dark Mode", isOn: $previewIsDark)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                .padding()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(previewIsDark ? Color(white: 0.1) : Color(white: 0.95))
                    
                    VStack(spacing: 16) {
                        previewText("Lorem ipsum dolor sit amet", index: 0)
                        previewText("Consectetur adipiscing elit", index: 1)
                        previewText("Sed do eiusmod tempor", index: 2)
                    }
                }
                .frame(height: 180)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // SETTINGS SECTION
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Apply to:", selection: $applyMode) {
                        Text("Both Themes").tag(0)
                        Text(previewIsDark ? "Dark Theme Only" : "Light Theme Only").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack {
                        Toggle("Neon Effect", isOn: $appSettings.isNeonEffectEnabled)
                        Spacer()
                        Toggle("Glow Effect", isOn: $appSettings.isGlowEffectEnabled)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Typography")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Picker("Font Design", selection: fontDesignBinding) {
                            Text("Rounded").tag(1)
                            Text("Default").tag(0)
                            Text("Monospaced").tag(2)
                            Text("Serif").tag(3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lyrics Transition")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Picker("Lyrics Transition", selection: $settings.lyricsTransitionStyle) {
                            ForEach(LyricsTransitionStyle.allCases) { style in
                                Text(LocalizedStringKey(style.title)).tag(style.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colors")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ColorPicker("Font Color", selection: colorBinding(for: $settings.fontColorLight, stringBindingDark: $settings.fontColorDark, defaultColor: .primary))
                        VStack(alignment: .leading, spacing: 6) {
                            ColorPicker("Neon Color", selection: colorBinding(for: $settings.neonColorLight, stringBindingDark: $settings.neonColorDark, defaultColor: .white))
                            Toggle("Use Primary Color of Playing Album", isOn: $settings.usesAlbumColorForNeon)
                                .font(.caption)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ColorPicker("Glow Color", selection: colorBinding(for: $settings.glowColorLight, stringBindingDark: $settings.glowColorDark, defaultColor: .accentColor))
                            Toggle("Use Primary Color of Playing Album", isOn: $settings.usesAlbumColorForGlow)
                                .font(.caption)
                        }
                    }
                    
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                        appSettings.isNeonEffectEnabled = false
                        appSettings.isGlowEffectEnabled = false
                        applyMode = 0
                    }
                    .padding(.top, 10)
                }
                .padding(24)
            }
        }
    }
    
    private func previewText(_ text: String, index: Int) -> some View {
        let transition = settings.transitionStyle
        let isActive = index == 1
        let offset: CGFloat
        if transition == .slide {
            offset = isActive ? 0 : (index < 1 ? -transition.inactiveOffset : transition.inactiveOffset)
        } else {
            offset = isActive ? (transition == .bounce ? -6 : 0) : transition.inactiveOffset
        }

        return Text(text)
            .font(.system(size: isActive ? 24 : 18, weight: isActive ? .bold : .medium, design: settings.getFontDesign(isDark: previewIsDark)))
            .foregroundColor((appSettings.isNeonEffectEnabled && isActive) ? settings.getNeonColor(isDark: previewIsDark) : settings.getFontColor(isDark: previewIsDark, isActive: isActive))
            .shadow(color: (appSettings.isNeonEffectEnabled && isActive) ? settings.getNeonColor(isDark: previewIsDark).opacity(0.8) : .clear, radius: 10, x: 0, y: 0)
            .shadow(color: (appSettings.isNeonEffectEnabled && isActive) ? settings.getNeonColor(isDark: previewIsDark).opacity(0.4) : .clear, radius: 20, x: 0, y: 0)
            .shadow(color: (appSettings.isGlowEffectEnabled && isActive) ? settings.getGlowColor(isDark: previewIsDark).opacity(0.8) : .clear, radius: 15, x: 0, y: 0)
            .shadow(color: (appSettings.isGlowEffectEnabled && isActive) ? settings.getGlowColor(isDark: previewIsDark).opacity(0.5) : .clear, radius: 5, x: 0, y: 0)
            .opacity(isActive ? 1 : transition.inactiveOpacity)
            .scaleEffect(isActive ? transition.activeScale : transition.inactiveScale)
            .offset(y: offset)
            .blur(radius: isActive ? 0 : transition.inactiveBlur)
            .animation(transition.animation, value: settings.lyricsTransitionStyle)
    }
}

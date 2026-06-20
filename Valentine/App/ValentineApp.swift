//
//  ValentineApp.swift
//  Valentine
//
//  Created by Jesús David Chapman Vélez on 16/06/26.
//

import SwiftUI

@main
struct ValentineApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            ValentineCommands()
        }
        
        Window("About Valentine", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 650, height: 480)
        
        Window("Modify Appearance", id: "lyricsAppearance") {
            LyricsAppearanceView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 600)
    }
}

struct RootView: View {
    @StateObject private var engine = AudioEngine()
    @AppStorage("isMiniPlayerMode") private var isMiniPlayerMode = false
    @AppStorage("appTheme") private var appTheme = 0
    
    @AppStorage("lastNormalWidth") private var lastNormalWidth: Double = 900
    @AppStorage("lastNormalHeight") private var lastNormalHeight: Double = 600
    
    var body: some View {
        Group {
            if isMiniPlayerMode {
                MiniPlayerView(engine: engine)
            } else {
                ContentView()
                    .environmentObject(engine)
            }
        }
        .preferredColorScheme(appTheme == 1 ? .light : (appTheme == 2 ? .dark : nil))
        .animation(.easeInOut, value: isMiniPlayerMode)
        .onAppear {
            configureWindow(forMiniPlayer: isMiniPlayerMode)
        }
        .onChange(of: isMiniPlayerMode) { newValue in
            configureWindow(forMiniPlayer: newValue)
        }
        .sheet(isPresented: $engine.showLyricsEditor) {
            LyricsEditorView()
                .environmentObject(engine)
        }
        .sheet(isPresented: $engine.showMutagenInstaller) {
            MutagenInstallerView {
                engine.showLyricsEditor = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddFile"))) { _ in engine.showAddFileDialog() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddFolder"))) { _ in engine.showAddFolderDialog() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearPlaylist"))) { _ in engine.clearPlaylist() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EditLyrics"))) { _ in engine.checkAndShowLyricsEditor() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReinstallMutagen"))) { _ in engine.showMutagenInstaller = true }
    }
    
    private func configureWindow(forMiniPlayer: Bool) {
        #if os(macOS)
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                if window.className == "NSWindow" || window.className.contains("SwiftUI") {
                    window.level = forMiniPlayer ? .floating : .normal
                    window.standardWindowButton(.closeButton)?.isHidden = forMiniPlayer
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = forMiniPlayer
                    window.standardWindowButton(.zoomButton)?.isHidden = forMiniPlayer
                    window.isMovableByWindowBackground = true
                    
                    if forMiniPlayer {
                        window.backgroundColor = .clear
                        window.isOpaque = false
                        window.hasShadow = true
                        
                        var newFrame = window.frame
                        let oldHeight = newFrame.size.height
                        newFrame.size = NSSize(width: 480, height: 140)
                        newFrame.origin.y += (oldHeight - 140)
                        window.setFrame(newFrame, display: true, animate: true)
                    } else {
                        window.backgroundColor = .windowBackgroundColor
                        window.isOpaque = true
                        
                        var newFrame = window.frame
                        let oldHeight = newFrame.size.height
                        
                        let targetWidth = max(400, CGFloat(lastNormalWidth))
                        let targetHeight = max(540, CGFloat(lastNormalHeight))
                        
                        newFrame.size = NSSize(width: targetWidth, height: targetHeight)
                        newFrame.origin.y -= (targetHeight - oldHeight)
                        window.setFrame(newFrame, display: true, animate: true)
                    }
                }
            }
        }
        #endif
    }
}

struct ValentineCommands: Commands {
    @AppStorage("isGlowEffectEnabled") private var isGlowEffectEnabled = false
    @AppStorage("isNeonEffectEnabled") private var isNeonEffectEnabled = false
    @AppStorage("isMiniPlayerMode") private var isMiniPlayerMode = false
    @AppStorage("miniPlayerGlassMode") private var miniPlayerGlassMode = 0
    @AppStorage("appTheme") private var appTheme = 0
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(action: {
                openWindow(id: "about")
            }) {
                Label("About Valentine", systemImage: "info.circle")
            }
        }
        
        CommandGroup(replacing: .newItem) {
            Button(action: { NotificationCenter.default.post(name: NSNotification.Name("AddFile"), object: nil) }) {
                Label("Add File...", systemImage: "doc.badge.plus")
            }
            .keyboardShortcut("o", modifiers: [.command])
            
            Button(action: { NotificationCenter.default.post(name: NSNotification.Name("AddFolder"), object: nil) }) {
                Label("Add Folder...", systemImage: "folder.badge.plus")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            
            Divider()
            
            Button(action: { NotificationCenter.default.post(name: NSNotification.Name("ClearPlaylist"), object: nil) }) {
                Label("Clear Playlist", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }
        
        CommandGroup(after: .textEditing) {
            Divider()
            Button(action: { NotificationCenter.default.post(name: NSNotification.Name("EditLyrics"), object: nil) }) {
                Label("Edit Lyrics", systemImage: "music.note.list")
            }
            .keyboardShortcut("e", modifiers: [.command])
            
            Button(action: { openWindow(id: "lyricsAppearance") }) {
                Label("Modify Appearance", systemImage: "textformat.alt")
            }
            
            Button(action: { NotificationCenter.default.post(name: NSNotification.Name("ReinstallMutagen"), object: nil) }) {
                Label("Reinstall Mutagen", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        
        CommandGroup(after: .toolbar) {
            Divider()
            Menu {
                Toggle("Glow Effect", isOn: $isGlowEffectEnabled)
                Toggle("Neon Effect", isOn: $isNeonEffectEnabled)
            } label: {
                Label("Synced Lyrics Settings", systemImage: "sparkles")
            }
            Menu {
                Picker("Mode", selection: $miniPlayerGlassMode) {
                    Text("Tinted (System Theme)").tag(0)
                    Text("Transparent (No Tint)").tag(1)
                }
                .pickerStyle(InlinePickerStyle())
            } label: {
                Label("Mini Player Background", systemImage: "macwindow")
            }
            Menu {
                Picker("Theme", selection: $appTheme) {
                    Text("Follow System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(InlinePickerStyle())
            } label: {
                Label("App Theme", systemImage: "paintpalette")
            }
        }
        
        CommandGroup(after: .windowList) {
            Button(action: { isMiniPlayerMode.toggle() }) {
                Label(isMiniPlayerMode ? "Switch to Full Player" : "Switch to Mini-Player", systemImage: isMiniPlayerMode ? "arrow.up.left.and.arrow.down.right" : "pip.enter")
            }
            .keyboardShortcut("m", modifiers: [.command])
        }
    }
}

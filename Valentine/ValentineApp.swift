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
    }
}

struct RootView: View {
    @StateObject private var engine = AudioEngine()
    @AppStorage("isMiniPlayerMode") private var isMiniPlayerMode = false
    @AppStorage("appTheme") private var appTheme = 0
    
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddFile"))) { _ in engine.showAddFileDialog() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddFolder"))) { _ in engine.showAddFolderDialog() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearPlaylist"))) { _ in engine.clearPlaylist() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EditLyrics"))) { _ in engine.showLyricsEditor = true }
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
                        newFrame.size = NSSize(width: 900, height: 600)
                        newFrame.origin.y -= (600 - oldHeight)
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
            Button("About Valentine") {
                openWindow(id: "about")
            }
        }
        
        CommandGroup(replacing: .newItem) {
            Button("Add File...") { NotificationCenter.default.post(name: NSNotification.Name("AddFile"), object: nil) }
                .keyboardShortcut("o", modifiers: [.command])
            
            Button("Add Folder...") { NotificationCenter.default.post(name: NSNotification.Name("AddFolder"), object: nil) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Clear Playlist") { NotificationCenter.default.post(name: NSNotification.Name("ClearPlaylist"), object: nil) }
                .keyboardShortcut(.delete, modifiers: [.command])
        }
        
        CommandGroup(after: .textEditing) {
            Divider()
            Button("Edit Lyrics") { NotificationCenter.default.post(name: NSNotification.Name("EditLyrics"), object: nil) }
                .keyboardShortcut("e", modifiers: [.command])
        }
        
        CommandGroup(after: .toolbar) {
            Divider()
            Menu("Synced Lyrics Settings") {
                Toggle("Glow Effect", isOn: $isGlowEffectEnabled)
                Toggle("Neon Effect", isOn: $isNeonEffectEnabled)
            }
            Menu("Mini Player Background") {
                Picker("Mode", selection: $miniPlayerGlassMode) {
                    Text("Tinted (System Theme)").tag(0)
                    Text("Transparent (No Tint)").tag(1)
                }
                .pickerStyle(InlinePickerStyle())
            }
            Menu("App Theme") {
                Picker("Theme", selection: $appTheme) {
                    Text("Follow System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(InlinePickerStyle())
            }
        }
        
        CommandGroup(after: .windowList) {
            Button(isMiniPlayerMode ? "Switch to Full Player" : "Switch to Mini-Player") {
                isMiniPlayerMode.toggle()
            }
            .keyboardShortcut("m", modifiers: [.command])
        }
    }
}

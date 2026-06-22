//
//  ValentineApp.swift
//  Valentine
//
//  Created by Jesús David Chapman Vélez on 16/06/26.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}

@main
struct ValentineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appTheme") private var appTheme = 0
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            ValentineCommands()
        }
        
        Window("About Valentine", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 650, height: 480)
        
        Window("Settings", id: "settings") {
            SettingsView()
                .preferredColorScheme(appTheme == 1 ? .light : (appTheme == 2 ? .dark : nil))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
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
        .animation(.easeInOut, value: isMiniPlayerMode)
        .installQuickSearch(engine: engine)
        .preferredColorScheme(appTheme == 1 ? .light : (appTheme == 2 ? .dark : nil))
        .onAppear {
            updateTheme(theme: appTheme)
            configureWindow(forMiniPlayer: isMiniPlayerMode)
        }
        .onChange(of: appTheme) { _, newTheme in
            updateTheme(theme: newTheme)
        }
        .onChange(of: isMiniPlayerMode) { _, newValue in
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
        .onReceive(NotificationCenter.default.publisher(for: .addFile)) { _ in engine.showAddFileDialog() }
        .onReceive(NotificationCenter.default.publisher(for: .addFolder)) { _ in engine.showAddFolderDialog() }
        .onReceive(NotificationCenter.default.publisher(for: .clearPlaylist)) { _ in engine.clearPlaylist() }
        .onReceive(NotificationCenter.default.publisher(for: .editLyrics)) { _ in engine.checkAndShowLyricsEditor() }
        .onReceive(NotificationCenter.default.publisher(for: .reinstallMutagen)) { _ in engine.showMutagenInstaller = true }
    }
    
    private func updateTheme(theme: Int) {
        #if os(macOS)
        DispatchQueue.main.async {
            let appearance: NSAppearance?
            switch theme {
            case 1: appearance = NSAppearance(named: .aqua)
            case 2: appearance = NSAppearance(named: .darkAqua)
            default: appearance = nil
            }
            NSApplication.shared.appearance = appearance
        }
        #endif
    }
    
    private func configureWindow(forMiniPlayer: Bool) {
        #if os(macOS)
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                if window.className == "NSWindow" || window.className.contains("SwiftUI") {
                    let id = window.identifier?.rawValue ?? ""
                    if id.contains("settings") || id.contains("about") { continue }
                    
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
    @AppStorage("isMiniPlayerMode") private var isMiniPlayerMode = false
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(action: {
                openWindow(id: "about")
            }) {
                Label("About Valentine", systemImage: "info.circle")
            }
        }
        
        CommandGroup(replacing: .appSettings) {
            Button(action: { openWindow(id: "settings") }) {
                Label("Settings...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
        

        
        CommandGroup(replacing: .newItem) {
            Button(action: { NotificationCenter.default.post(name: .addFile, object: nil) }) {
                Label("Add File...", systemImage: "doc.badge.plus")
            }
            .keyboardShortcut("o", modifiers: [.command])
            
            Button(action: { NotificationCenter.default.post(name: .addFolder, object: nil) }) {
                Label("Add Folder...", systemImage: "folder.badge.plus")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            
            Divider()
            
            Button(action: { NotificationCenter.default.post(name: .clearPlaylist, object: nil) }) {
                Label("Clear Playlist", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }
        
        CommandGroup(after: .textEditing) {
            Divider()
            Button(action: { NotificationCenter.default.post(name: .editLyrics, object: nil) }) {
                Label("Edit Lyrics", systemImage: "music.note.list")
            }
            .keyboardShortcut("e", modifiers: [.command])
        }
        
        CommandGroup(replacing: .help) {
            Button(action: { NotificationCenter.default.post(name: .reinstallMutagen, object: nil) }) {
                Label("Reinstall Mutagen", systemImage: "arrow.triangle.2.circlepath")
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

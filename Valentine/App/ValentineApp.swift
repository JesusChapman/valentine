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
    @ObservedObject private var settings = AppSettings.shared
    
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
                .preferredColorScheme(settings.appTheme == 1 ? .light : (settings.appTheme == 2 ? .dark : nil))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

struct RootView: View {
    @StateObject private var engine = AudioEngine()
    @AppStorage("isMiniPlayerMode") private var isMiniPlayerMode = false
    @AppStorage("isStandbyMode") private var isStandbyMode = false
    @ObservedObject private var settings = AppSettings.shared
    @State private var windowChromeRevision = 0
    
    @AppStorage("lastNormalWidth") private var lastNormalWidth: Double = 900
    @AppStorage("lastNormalHeight") private var lastNormalHeight: Double = 600
    
    var body: some View {
        Group {
            if isStandbyMode {
                StandbyView(engine: engine, isStandbyMode: $isStandbyMode)
            } else if isMiniPlayerMode {
                MiniPlayerView(engine: engine)
            } else {
                ContentView()
                    .environmentObject(engine)
                    .id(windowChromeRevision)
            }
        }
        .animation(.easeInOut, value: isMiniPlayerMode)
        .animation(.easeInOut, value: isStandbyMode)
        .preferredColorScheme(settings.appTheme == 1 ? .light : (settings.appTheme == 2 ? .dark : nil))
        .onAppear {
            updateTheme(theme: settings.appTheme)
            configureWindow(forMiniPlayer: isMiniPlayerMode, isStandbyMode: isStandbyMode)
        }
        .onChange(of: settings.appTheme) { _, newTheme in
            updateTheme(theme: newTheme)
        }
        .onChange(of: isMiniPlayerMode) { _, newValue in
            if newValue && isStandbyMode {
                isStandbyMode = false
            }
            configureWindow(forMiniPlayer: newValue, isStandbyMode: false)

            if !newValue && !isStandbyMode {
                DispatchQueue.main.async {
                    windowChromeRevision &+= 1
                }
            }
        }
        .onChange(of: isStandbyMode) { oldValue, newValue in
            if newValue && isMiniPlayerMode {
                isMiniPlayerMode = false
            }
            if oldValue && !newValue {
                exitStandbyFullscreen()
            } else {
                configureWindow(forMiniPlayer: false, isStandbyMode: newValue)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
            // A fullscreen window ignores frame changes while its exit animation
            // is running. Apply the pending player mode once AppKit confirms that
            // the transition has finished.
            guard let window = notification.object as? NSWindow else { return }
            let id = window.identifier?.rawValue ?? ""
            guard !id.contains("settings"), !id.contains("about") else { return }

            configureWindow(
                forMiniPlayer: isMiniPlayerMode,
                isStandbyMode: isStandbyMode
            )

            // configureWindow is queued on the main actor and restores the
            // traffic-light buttons first. Rebuild the SwiftUI toolbar on the
            // following pass, once those controls occupy their normal space.
            DispatchQueue.main.async {
                windowChromeRevision &+= 1
            }
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
    
    private func configureWindow(forMiniPlayer: Bool, isStandbyMode: Bool) {
        #if os(macOS)
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                if window.className == "NSWindow" || window.className.contains("SwiftUI") {
                    let id = window.identifier?.rawValue ?? ""
                    if id.contains("settings") || id.contains("about") { continue }
                    
                    window.level = forMiniPlayer ? .floating : .normal
                    window.standardWindowButton(.closeButton)?.isHidden = forMiniPlayer || isStandbyMode
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = forMiniPlayer || isStandbyMode
                    window.standardWindowButton(.zoomButton)?.isHidden = forMiniPlayer || isStandbyMode
                    window.isMovableByWindowBackground = true

                    if isStandbyMode {
                        window.level = .normal
                        if !window.styleMask.contains(.fullScreen) {
                            window.toggleFullScreen(nil)
                        }
                        continue
                    }

                    // Defer normal/mini-player sizing until
                    // NSWindow.didExitFullScreenNotification. Calling setFrame
                    // during the fullscreen transition is silently discarded.
                    if window.styleMask.contains(.fullScreen) {
                        continue
                    }
                    
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

                        DispatchQueue.main.async {
                            window.toolbar?.validateVisibleItems()
                            window.contentView?.superview?.needsLayout = true
                            window.contentView?.superview?.layoutSubtreeIfNeeded()
                            NSApplication.shared.setWindowsNeedUpdate(true)
                        }
                    }
                }
            }
        }
        #endif
    }

    private func exitStandbyFullscreen() {
        #if os(macOS)
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                let id = window.identifier?.rawValue ?? ""
                guard (window.className == "NSWindow" || window.className.contains("SwiftUI")),
                      !id.contains("settings"),
                      !id.contains("about"),
                      window.styleMask.contains(.fullScreen) else {
                    continue
                }
                window.toggleFullScreen(nil)
            }
        }
        #endif
    }
}

struct ValentineCommands: Commands {
    @AppStorage("isMiniPlayerMode") private var isMiniPlayerMode = false
    @AppStorage("isStandbyMode") private var isStandbyMode = false
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
            Button(action: {
                isStandbyMode.toggle()
            }) {
                Label(isStandbyMode ? "Exit Stand By" : "Enter Stand By", systemImage: "music.note.tv")
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Button(action: { isMiniPlayerMode.toggle() }) {
                Label(isMiniPlayerMode ? "Switch to Full Player" : "Switch to Mini-Player", systemImage: isMiniPlayerMode ? "arrow.up.left.and.arrow.down.right" : "pip.enter")
            }
            .keyboardShortcut("m", modifiers: [.command])
        }
    }
}

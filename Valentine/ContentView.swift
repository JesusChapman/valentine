//
//  ContentView.swift
//  Valentine
//
//  Created by Jesús David Chapman Vélez on 16/06/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var engine: AudioEngine
    @State private var isTargeted = false
    @State private var isPlaylistVisible = true
    @State private var wasWide = true
    
    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > 600
            
            Group {
                if engine.queue.isEmpty {
                    emptyStateView
                } else {
                    HStack(spacing: 0) {
                        if isWide {
                            if isPlaylistVisible {
                                PlaylistView(engine: engine)
                                    .frame(width: 280)
                                    .background(Color.black.opacity(0.2))
                                    .transition(.move(edge: .leading))
                            }
                            
                            PlayerView(
                                engine: engine,
                                togglePlaylist: {},
                                isPlaylistVisible: isPlaylistVisible,
                                showToggle: false
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            if isPlaylistVisible {
                                PlaylistView(engine: engine)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.black.opacity(0.2))
                                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                            } else {
                                PlayerView(
                                    engine: engine,
                                    togglePlaylist: {},
                                    isPlaylistVisible: isPlaylistVisible,
                                    showToggle: false
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                            }
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(backgroundLayer)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation(.spring()) {
                            isPlaylistVisible.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
            .onChange(of: geometry.size.width) { newWidth in
                let newIsWide = newWidth >= 600
                if newIsWide != wasWide {
                    wasWide = newIsWide
                    if !newIsWide {
                        isPlaylistVisible = false
                    } else {
                        isPlaylistVisible = true
                    }
                }
            }
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .frame(minWidth: 400, minHeight: 540)
    }
    
    private var backgroundLayer: some View {
        Group {
            if engine.queue.isEmpty {
                Color.clear
            } else if let art = engine.currentTrack?.albumArt {
                art
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 80)
                    .opacity(0.7)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.5), value: engine.currentTrack?.id)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.2, green: 0.1, blue: 0.15), Color(red: 0.1, green: 0.1, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "play.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Text("Valentine")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Select a file or a folder, or drag files from your file manager to\nthe application window to add songs to the playlist")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Button(action: {
                    selectFiles(directories: true)
                }) {
                    Text("Add Folder...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 160, height: 40)
                        .background(Color.accentColor.opacity(0.6))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    selectFiles(directories: false)
                }) {
                    Text("Add File...")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(width: 160, height: 40)
                        .background(Color.secondary.opacity(0.2))
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func selectFiles(directories: Bool) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = directories
        panel.canChooseFiles = !directories
        panel.allowedContentTypes = [.audio]
        
        if panel.runModal() == .OK {
            engine.addTracks(panel.urls)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                if let urlData = urlData as? Data,
                   let urlString = String(data: urlData, encoding: .utf8),
                   let url = URL(string: urlString) {
                    urls.append(url)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            engine.addTracks(urls)
        }
        return true
    }
}

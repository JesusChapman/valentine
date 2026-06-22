//
//  ContentView.swift
//  Valentine
//
//  Created by Jesús David Chapman Vélez on 16/06/26.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine
import CoreSpotlight
struct ContentView: View {
    @EnvironmentObject var engine: AudioEngine
    @Environment(\.colorScheme) var colorScheme
    @State private var isTargeted = false
    @State private var isPlaylistVisible = true
    @State private var selectedTab: LibraryTab = .home
    @State private var showFullPlayer = false

    @AppStorage("lastNormalWidth") private var lastNormalWidth: Double = 900
    @AppStorage("lastNormalHeight") private var lastNormalHeight: Double = 600

    var body: some View {
        Group {
            if engine.queue.isEmpty {
                emptyStateView
            } else {
                // Audirvana layout: library on top, full-width transport bar pinned below.
                VStack(spacing: 0) {
                    LibrarySidebar(engine: engine, selectedTab: $selectedTab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .safeAreaInset(edge: .top) {
                            // Clear the window's traffic-light buttons.
                            Color.clear.frame(height: 28)
                        }

                    BottomBarView(engine: engine) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showFullPlayer.toggle()
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if showFullPlayer {
                        fullPlayerOverlay
                            .transition(.move(edge: .bottom))
                    }
                }
            }
        }
        .background(backgroundLayer)

        .background(backgroundLayer)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    withAnimation(.spring()) { showFullPlayer.toggle() }
                }) {
                    Image(systemName: showFullPlayer ? "chevron.down" : "rectangle.expand.vertical")
                }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .frame(minWidth: 600, minHeight: 540)
        .onAppear { engine.restoreLibrary() }
        .onReceive(engine.$queue) { _ in engine.persistLibrary() }
        .onReceive(engine.$queue) { _ in engine.scheduleSpotlightReindex() }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            engine.handleSpotlightActivity(activity.userInfo ?? [:])
        }

    }

    // Full now-playing view (the original PlayerView), slid up over the library.
    private var fullPlayerOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showFullPlayer = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .padding(.top, 8)
            }

            PlayerView(
                engine: engine,
                togglePlaylist: {},
                isPlaylistVisible: isPlaylistVisible,
                showToggle: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.ultraThinMaterial)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
    }

    private var backgroundLayer: some View {
        Group {
            if engine.queue.isEmpty {
                Color.clear
            } else if let art = engine.currentTrack?.albumArt {
                art
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .blur(radius: 80)
                    .opacity(0.7)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.5), value: engine.currentTrack?.id)
            } else {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.1, blue: 0.15), Color(red: 0.1, green: 0.1, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                } else {
                    Color(NSColor.windowBackgroundColor)
                        .ignoresSafeArea()
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            if let appIcon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .accentColor.opacity(0.4), radius: 25, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .overlay(
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .scaleEffect(x: 1, y: -1)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, .white.opacity(0.3)]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .opacity(0.5)
                            .offset(y: 140)
                    )
                    .padding(.bottom, 60)
            }

            Text("Valentine")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Select a file or a folder, or drag files from your file manager to\nthe application window to add songs to the playlist")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                HoverZoomButton(title: "Add Folder...", isPrimary: true) {
                    selectFiles(directories: true)
                }

                HoverZoomButton(title: "Add File...", isPrimary: false) {
                    selectFiles(directories: false)
                }
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
        // Only restrict to audio when picking files; a folder filter would
        // disable the Open button when choosing directories.
        if !directories {
            panel.allowedContentTypes = [.audio]
        }

        if panel.runModal() == .OK {
            engine.addTracks(panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "dropQueue")
        var urls: [URL] = []

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                defer { group.leave() }
                if let urlData = urlData as? Data,
                   let urlString = String(data: urlData, encoding: .utf8),
                   let url = URL(string: urlString) {
                    queue.async { urls.append(url) }
                } else if let url = urlData as? URL {
                    queue.async { urls.append(url) }
                }
            }
        }

        group.notify(queue: .main) {
            queue.sync {
                if !urls.isEmpty {
                    engine.addTracks(urls)
                }
            }
        }
        return true
    }
}

struct HoverZoomButton: View {
    let title: LocalizedStringKey
    let isPrimary: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isPrimary ? .white : .primary)
                .frame(width: 160, height: 40)
                .background(isPrimary ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2))
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

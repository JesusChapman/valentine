import SwiftUI

struct PlaylistView: View {
    @ObservedObject var engine: AudioEngine
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var isSelectionMode = false
    @State private var selectedTracks = Set<UUID>()
    
    var filteredTracks: [(Int, Track)] {
        let enumerated = Array(engine.queue.enumerated())
        if searchText.isEmpty {
            return enumerated
        } else {
            return enumerated.filter {
                $0.element.title.localizedCaseInsensitiveContains(searchText) ||
                $0.element.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var activeControlTint: Color {
        engine.activeControlTint(for: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if !isSearchVisible {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Playlist")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(Int(engine.duration / 60)) minutes remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.primary)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.medium)
                            .fill(.clear)
                            .liquidGlass(cornerRadius: DesignConstants.CornerRadius.medium)
                    )
                    .padding(.trailing, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                }
                
                Button(action: {
                    withAnimation {
                        isSearchVisible.toggle()
                        if !isSearchVisible {
                            searchText = ""
                        }
                    }
                }) {
                    Image(systemName: isSearchVisible ? "xmark" : "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(isSearchVisible ? activeControlTint : .primary)
                        .frame(width: 28, height: 28)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(LiquidGlassButtonStyle(
                    cornerRadius: DesignConstants.CornerRadius.medium,
                    isActive: isSearchVisible,
                    activeTint: activeControlTint
                ))
                .focusEffectDisabled()
                .accessibilityLabel(isSearchVisible ? "Close Search" : "Search Playlist")
                .keyboardShortcut("f", modifiers: .command)
                .padding(.trailing, 4)
                
                Button(action: {
                    withAnimation {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedTracks.removeAll()
                        }
                    }
                }) {
                    Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundColor(isSelectionMode ? activeControlTint : .primary)
                        .frame(width: 28, height: 28)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(LiquidGlassButtonStyle(
                    cornerRadius: DesignConstants.CornerRadius.medium,
                    isActive: isSelectionMode,
                    activeTint: activeControlTint
                ))
                .focusEffectDisabled()
                .accessibilityLabel(isSelectionMode ? "Exit Selection Mode" : "Select Tracks")
            }
            .padding()
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isSearchVisible)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isSelectionMode)
            
            if isSelectionMode && !selectedTracks.isEmpty {
                Button(action: {
                    withAnimation {
                        engine.removeTracks(withIds: selectedTracks)
                        selectedTracks.removeAll()
                        isSelectionMode = false
                    }
                })
                {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("Delete \(selectedTracks.count)")
                        Spacer()
                    }
                    .padding(8)
                    .foregroundColor(.white)
                    .background(Color.red.opacity(0.8))
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.delete, modifiers: .command)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            if filteredTracks.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: isSearchVisible ? "magnifyingglass" : "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(isSearchVisible ? "No results found" : "Drag & Drop Audio Files Here")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredTracks, id: \.1.id) { index, track in
                            QueueRowView(
                                track: track,
                                isPlaying: engine.currentTrackIndex == index,
                                isSelectionMode: isSelectionMode,
                                isSelected: selectedTracks.contains(track.id),
                                activeTint: activeControlTint
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelectionMode {
                                    if selectedTracks.contains(track.id) {
                                        selectedTracks.remove(track.id)
                                    } else {
                                        selectedTracks.insert(track.id)
                                    }
                                } else {
                                    engine.playTrack(at: index)
                                }
                            }
                            .contextMenu {
                                Button(action: {
                                    if let currentIndex = engine.currentTrackIndex {
                                        let trackIndexInQueue = engine.queue.firstIndex(where: { $0.id == track.id })
                                        if let tIndex = trackIndexInQueue, tIndex != currentIndex {
                                            let t = engine.queue.remove(at: tIndex)
                                            let newCurrentIndex = currentIndex > tIndex ? currentIndex - 1 : currentIndex
                                            engine.currentTrackIndex = newCurrentIndex
                                            let insertIndex = min(newCurrentIndex + 1, engine.queue.count)
                                            engine.queue.insert(t, at: insertIndex)
                                        }
                                    }
                                }) {
                                    Label("Play Next", systemImage: "text.insert")
                                }
                                
                                Button(action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([track.url])
                                }) {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive, action: {
                                    engine.removeTracks(withIds: [track.id])
                                }) {
                                    Label("Remove", systemImage: "trash")
                                }
                                .tint(.red)
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

import SwiftUI

struct PlaylistView: View {
    @ObservedObject var engine: AudioEngine
    
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
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(
                        Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.trailing, 8)
                }
                
                Button(action: {
                    withAnimation {
                        isSearchVisible.toggle()
                        if !isSearchVisible {
                            searchText = ""
                        }
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(isSearchVisible ? .accentColor : .primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .liquidGlass(cornerRadius: 14)
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
                        .foregroundColor(isSelectionMode ? .accentColor : .primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .liquidGlass(cornerRadius: 14)
            }
            .padding()
            
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
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredTracks, id: \.1.id) { index, track in
                        QueueRowView(
                            track: track,
                            isPlaying: engine.currentTrackIndex == index,
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedTracks.contains(track.id)
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
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
        }
    }
}

struct QueueRowView: View {
    let track: Track
    let isPlaying: Bool
    let isSelectionMode: Bool
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            
            if let albumArt = track.albumArt {
                albumArt
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isPlaying && !isSelectionMode {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.primary)
                    .font(.system(size: 12))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPlaying && !isSelectionMode ? Color.white.opacity(0.15) : (isSelected ? Color.blue.opacity(0.2) : Color.clear))
        )
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .animation(.easeInOut(duration: 0.2), value: isSelectionMode)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

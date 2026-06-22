import SwiftUI
import Combine

enum AlbumSort: String, CaseIterable, Identifiable {
    case artist = "Artist"
    case title = "Title"
    case year = "Year"
    case recentlyAdded = "Recently Added"
    var id: String { rawValue }
}

// MARK: - Shared building blocks

/// Square album artwork with a graceful placeholder.
struct AlbumArtView: View {
    let image: Image?
    var size: CGFloat
    var corner: CGFloat = 8

    var body: some View {
        Group {
            if let image {
                image.resizable().aspectRatio(1, contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Image(systemName: "opticaldisc")
                            .font(.system(size: size * 0.28))
                            .foregroundColor(.white.opacity(0.25))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }
}

/// Roon-style numbered track row with right-aligned duration and now-playing accent.
struct RoonTrackRow: View {
    let track: Track
    let displayNumber: Int
    let isPlaying: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                } else if hovering {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                } else {
                    Text("\(track.trackNumber ?? displayNumber)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 22)

            Text(track.title)
                .font(.system(size: 14))
                .fontWeight(isPlaying ? .semibold : .regular)
                .foregroundColor(isPlaying ? .accentColor : .primary)
                .lineLimit(1)

            Spacer()

            Text(track.duration.asClock)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPlaying ? Color.accentColor.opacity(0.12)
                                : (hovering ? Color.primary.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - Albums grid

struct AlbumGridView: View {
    @ObservedObject var engine: AudioEngine
    @State private var selectedAlbum: Album?
    @State private var cachedAlbums: [Album] = []
    @StateObject private var focus = FocusModel()
    @State private var sort: AlbumSort = .artist

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
        Group {
            if let album = selectedAlbum {
                ScrollView {
                    AlbumDetailView(engine: engine, album: album) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedAlbum = nil }
                    }
                }
            } else {
                ScrollView { gridContent }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { if cachedAlbums.isEmpty { cachedAlbums = filteredAlbums() }; consumeNavigation() }
        .onReceive(engine.$queue) { _ in cachedAlbums = filteredAlbums() }
        .onReceive(focus.$active) { _ in cachedAlbums = filteredAlbums() }
        .onChange(of: sort) { _, _ in cachedAlbums = filteredAlbums() }
        .onReceive(engine.objectWillChange) { _ in consumeNavigation() }
    }

    /// If the engine requested navigation to a specific album, open it.
    private func consumeNavigation() {
        guard let targetID = engine.navigateToAlbumID else { return }
        if let match = engine.albums.first(where: { $0.id == targetID }) {
            withAnimation(.easeInOut(duration: 0.2)) { selectedAlbum = match }
        }
        engine.navigateToAlbumID = nil
    }

    private func filteredAlbums() -> [Album] {
        let all = engine.albums
        let filtered = focus.active.isEmpty ? all : all.filter { album in
            !focus.apply(album.trackIndices, in: engine.queue).isEmpty
        }
        switch sort {
        case .artist:
            return filtered // engine.albums is already album-artist sorted
        case .title:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .year:
            return filtered.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        case .recentlyAdded:
            // Higher library index == added more recently.
            return filtered.sorted { ($0.trackIndices.max() ?? 0) > ($1.trackIndices.max() ?? 0) }
        }
    }

    private var gridContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Albums")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(AlbumSort.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sort.rawValue).font(.system(size: 12, weight: .medium))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 6)

            FocusBar(engine: engine, focus: focus)

            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(cachedAlbums) { album in
                    AlbumTile(album: album) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedAlbum = album }
                    }
                    .contextMenu {
                        Button("Play") { engine.playNow(album) }
                        Button("Shuffle") { engine.shuffle(album) }
                        Button("Play Next") { engine.playNext(album) }
                        Button("Add to Queue") { engine.enqueue(album) }
                    }
                }
            }
            .padding(20)
        }
    }
}

/// A grid tile with hover lift + play overlay.
struct AlbumTile: View {
    let album: Album
    let onOpen: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                AlbumArtView(image: album.artwork, size: 150, corner: 10)
                if hovering {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 150, height: 150)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.white)
                        .shadow(radius: 6)
                }
            }
            .shadow(color: .black.opacity(hovering ? 0.4 : 0.2),
                    radius: hovering ? 14 : 6, x: 0, y: hovering ? 8 : 3)
            .scaleEffect(hovering ? 1.03 : 1.0)

            Text(album.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(album.albumArtist).lineLimit(1)
                if let y = album.year { Text("· \(String(y))") }
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
        .frame(width: 150)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.18)) { hovering = h } }
        .onTapGesture(perform: onOpen)
    }
}

// MARK: - Album detail (Roon hero)

struct AlbumDetailView: View {
    @ObservedObject var engine: AudioEngine
    let album: Album
    let onBack: () -> Void
    @State private var editing: EditTarget?
    @ObservedObject private var favorites = FavoritesStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button(action: onBack) {
                Label("Albums", systemImage: "chevron.left").font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            // Hero
            HStack(alignment: .bottom, spacing: 22) {
                AlbumArtView(image: album.artwork, size: 180, corner: 12)
                    .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(album.title)
                        .font(.system(size: 28, weight: .bold))
                        .lineLimit(2)
                    Text(album.albumArtist)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(metaLine)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Button { engine.playNow(album) } label: {
                            Label("Play", systemImage: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: 110)
                        }
                        .buttonStyle(.borderedProminent)

                        Button { engine.shuffle(album) } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(.bordered)

                        Menu {
                            Button("Play Next") { engine.playNext(album) }
                            Button("Add to Queue") { engine.enqueue(album) }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 30)

                        HeartButton(isFavorite: favorites.isFavoriteAlbum(album), action: {
                            favorites.toggleAlbum(album)
                        }, size: 18)
                    }
                    .padding(.top, 6)
                }
                Spacer()
            }

            // Track list
            LazyVStack(spacing: 2) {
                ForEach(Array(album.trackIndices.enumerated()), id: \.element) { pos, index in
                    if engine.queue.indices.contains(index) {
                        RoonTrackRow(
                            track: engine.queue[index],
                            displayNumber: pos + 1,
                            isPlaying: engine.currentTrackIndex == index
                        )
                        .onTapGesture {
                            engine.playNow(indices: Array(album.trackIndices[pos...]))
                        }
                        .contextMenu {
                            Button("Edit Metadata…") { editing = EditTarget(index: index) }
                        }
                    }
                }
            }
        }
        .padding(24)
        .sheet(item: $editing) { target in
            MetadataEditorView(engine: engine, trackIndex: target.index)
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if let y = album.year { parts.append(String(y)) }
        parts.append("\(album.trackIndices.count) tracks")
        parts.append(album.totalDuration.asClock)
        return parts.joined(separator: " · ")
    }
}

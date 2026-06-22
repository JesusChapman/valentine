import SwiftUI

struct ArtistListView: View {
    @ObservedObject var engine: AudioEngine
    @State private var selectedArtist: ArtistGroup?
    @State private var cachedArtists: [ArtistGroup] = []

    var body: some View {
        Group {
            if let artist = selectedArtist {
                ScrollView {
                    ArtistDetailView(engine: engine, artist: artist) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedArtist = nil }
                    }
                }
            } else {
                ScrollView { listContent }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { if cachedArtists.isEmpty { cachedArtists = engine.artists } }
        .onReceive(engine.$queue) { _ in cachedArtists = engine.artists }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Artists")
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 6)

            LazyVStack(spacing: 2) {
                ForEach(cachedArtists) { artist in
                    ArtistRow(artist: artist) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedArtist = artist }
                    }
                    .contextMenu {
                        Button("Play") { engine.playNow(artist) }
                        Button("Shuffle") { engine.shuffle(artist) }
                        Button("Add to Queue") { engine.enqueue(artist) }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }
}

struct ArtistRow: View {
    let artist: ArtistGroup
    let onOpen: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text("\(artist.albumCount) albums · \(artist.trackCount) tracks")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(hovering ? Color.white.opacity(0.06) : .clear))
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .onTapGesture(perform: onOpen)
    }
}

// MARK: - Artist detail = albums grid (Roon style)

struct ArtistDetailView: View {
    @ObservedObject var engine: AudioEngine
    let artist: ArtistGroup
    let onBack: () -> Void

    @State private var openedAlbum: Album?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    var body: some View {
        if let album = openedAlbum {
            AlbumDetailView(engine: engine, album: album) {
                withAnimation(.easeInOut(duration: 0.2)) { openedAlbum = nil }
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: onBack) {
                    Label("Artists", systemImage: "chevron.left").font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary.opacity(0.7))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artist.name).font(.system(size: 26, weight: .bold))
                        Text("\(artist.albumCount) albums · \(artist.trackCount) tracks")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                        HStack(spacing: 10) {
                            Button { engine.playNow(artist) } label: {
                                Label("Play", systemImage: "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            Button { engine.shuffle(artist) } label: {
                                Label("Shuffle", systemImage: "shuffle")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                    }
                    Spacer()
                }

                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(engine.albums(for: artist)) { album in
                        AlbumTile(album: album) {
                            withAnimation(.easeInOut(duration: 0.2)) { openedAlbum = album }
                        }
                        .contextMenu {
                            Button("Play") { engine.playNow(album) }
                            Button("Shuffle") { engine.shuffle(album) }
                            Button("Play Next") { engine.playNext(album) }
                            Button("Add to Queue") { engine.enqueue(album) }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

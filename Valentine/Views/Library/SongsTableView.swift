import SwiftUI

struct EditTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

/// Roon-style sortable track table. Airy rows, art-forward, minimal chrome.
/// Columns: [art] Title · Artist · Album · Duration. Click a header to sort.
struct SongsTableView: View {
    @ObservedObject var engine: AudioEngine

    enum SortField { case title, artist, album, duration }

    @State private var sortField: SortField = .artist
    @State private var ascending = true
    @State private var filter = ""
    @State private var cachedRows: [Int] = []   // library indices, sorted+filtered
    @StateObject private var focus = FocusModel()
    @State private var editing: EditTarget?
    @State private var selectionMode = false
    @State private var selected = Set<Int>()
    @State private var showBatchEditor = false

    var body: some View {
        VStack(spacing: 0) {
            header
            FocusBar(engine: engine, focus: focus)
            if selectionMode { selectionBar }
            Divider().opacity(0.2)
            columnHeader
            Divider().opacity(0.2)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows, id: \.self) { index in
                        if engine.queue.indices.contains(index) {
                            HStack(spacing: 8) {
                                if selectionMode {
                                    Image(systemName: selected.contains(index) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selected.contains(index) ? .accentColor : .secondary)
                                        .padding(.leading, 8)
                                }
                                SongRow(
                                    track: engine.queue[index],
                                    isPlaying: engine.currentTrackIndex == index
                                )
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectionMode { toggle(index) } else { playFrom(index) }
                            }
                            .contextMenu {
                                Button("Play") { playFrom(index) }
                                Button(FavoritesStore.shared.isFavoriteSong(engine.queue[index]) ? "Remove from Favorites" : "Add to Favorites") {
                                    FavoritesStore.shared.toggleSong(engine.queue[index])
                                }
                                Divider()
                                Button("Edit Metadata…") { editing = EditTarget(index: index) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { recompute() }
        .onChange(of: filter) { _, _ in recompute() }
        .onReceive(engine.$queue) { _ in recompute() }
        .onReceive(focus.$active) { _ in recompute() }
        .sheet(item: $editing) { target in
            MetadataEditorView(engine: engine, trackIndex: target.index)
        }
        .sheet(isPresented: $showBatchEditor) {
            BatchEditorView(engine: engine, indices: Array(selected))
        }
    }

    private var selectionBar: some View {
        HStack {
            Text("\(selected.count) selected").font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Button("Select All") { selected = Set(rows) }
                .font(.system(size: 12)).buttonStyle(.plain)
            Button("Edit…") { if !selected.isEmpty { showBatchEditor = true } }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
    }

    private func toggle(_ index: Int) {
        if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
    }

    // MARK: Header + filter

    private var header: some View {
        HStack {
            Text("Songs").font(.system(size: 22, weight: .bold))
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                TextField("Filter", text: $filter)
                    .textFieldStyle(.plain)
                    .frame(width: 160)
                if !filter.isEmpty {
                    Button { filter = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(0.06)))

            Button {
                withAnimation { selectionMode.toggle(); if !selectionMode { selected.removeAll() } }
            } label: {
                Image(systemName: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 16))
                    .foregroundColor(selectionMode ? .accentColor : .primary)
            }
            .buttonStyle(.plain)
            .help("Select multiple")
            ManageOrganizeMenu(engine: engine)
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
    }

    private var columnHeader: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 40, height: 1)           // art column
            sortHeader("TITLE", .title).frame(maxWidth: .infinity, alignment: .leading)
            sortHeader("ARTIST", .artist).frame(width: 180, alignment: .leading)
            sortHeader("ALBUM", .album).frame(width: 180, alignment: .leading)
            sortHeader("TIME", .duration).frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 24).padding(.vertical, 8)
    }

    private func sortHeader(_ label: String, _ field: SortField) -> some View {
        Button {
            if sortField == field { ascending.toggle() } else { sortField = field; ascending = true }
            recompute()
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(sortField == field ? .primary : .secondary)
                if sortField == field {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private var rows: [Int] { cachedRows.isEmpty ? compute() : cachedRows }

    private func compute() -> [Int] {
        var indices = Array(engine.queue.indices)
        indices = focus.apply(indices, in: engine.queue)
        if !filter.isEmpty {
            let f = filter
            indices = indices.filter {
                let t = engine.queue[$0]
                return t.title.localizedCaseInsensitiveContains(f)
                    || t.artist.localizedCaseInsensitiveContains(f)
                    || (t.album ?? "").localizedCaseInsensitiveContains(f)
                    || (t.genre ?? "").localizedCaseInsensitiveContains(f)
            }
        }
        indices.sort { a, b in
            let ta = engine.queue[a], tb = engine.queue[b]
            let result: Bool
            switch sortField {
            case .title:    result = ta.title.localizedCaseInsensitiveCompare(tb.title) == .orderedAscending
            case .artist:   result = ta.artist.localizedCaseInsensitiveCompare(tb.artist) == .orderedAscending
            case .album:    result = (ta.album ?? "").localizedCaseInsensitiveCompare(tb.album ?? "") == .orderedAscending
            case .duration: result = ta.duration < tb.duration
            }
            return ascending ? result : !result
        }
        return indices
    }

    private func recompute() { cachedRows = compute() }

    private func playFrom(_ index: Int) {
        let ordered = rows
        if let start = ordered.firstIndex(of: index) {
            engine.playNow(indices: Array(ordered[start...]))
        } else {
            engine.playTrack(at: index)
        }
    }
}

struct SongRow: View {
    let track: Track
    let isPlaying: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                AlbumArtView(image: track.albumArt, size: 40, corner: 5)
                if hovering {
                    RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.4))
                        .frame(width: 40, height: 40)
                    Image(systemName: "play.fill").font(.system(size: 13)).foregroundColor(.white)
                } else if isPlaying {
                    RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.35))
                        .frame(width: 40, height: 40)
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 12)).foregroundColor(.accentColor)
                }
            }

            Text(track.title)
                .font(.system(size: 14))
                .fontWeight(isPlaying ? .semibold : .regular)
                .foregroundColor(isPlaying ? .accentColor : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(track.artist)
                .font(.system(size: 13)).foregroundColor(.secondary)
                .lineLimit(1).frame(width: 180, alignment: .leading)

            Text(track.album ?? "—")
                .font(.system(size: 13)).foregroundColor(.secondary)
                .lineLimit(1).frame(width: 180, alignment: .leading)

            Text(track.duration.asClock)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPlaying ? Color.accentColor.opacity(0.10)
                                : (hovering ? Color.primary.opacity(0.05) : .clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

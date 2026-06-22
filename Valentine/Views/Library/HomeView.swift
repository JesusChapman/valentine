//  HomeView.swift
//  Landing screen: greeting, library stats, recently-added albums.

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var engine: AudioEngine
    /// Lets Home switch the sidebar to another tab (e.g. open Albums).
    @Binding var selectedTab: LibraryTab

    @AppStorage("userName") private var userName = ""
    @ObservedObject private var lastFM = LastFMService.shared
    @State private var editingName = false
    @State private var fetching = false
    @State private var fetchSummary: String?
    @State private var pendingLastFMToken: String?
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                greeting
                statCards
                if recentAlbums.isEmpty {
                    addMusicCard
                } else {
                    recentSection
                    quickActions
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Complete Last.fm auth after the user approves in the browser.
            guard let token = pendingLastFMToken else { return }
            pendingLastFMToken = nil
            Task {
                try? await lastFM.getSession(token: token)
                fetchSummary = lastFM.isConnected ? "Connected to Last.fm" : "Last.fm not approved yet"
            }
        }
    }

    // MARK: Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if editingName {
                    Text(timeGreeting + ",").font(.system(size: 34, weight: .bold, design: .rounded))
                    TextField("your name", text: $userName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .frame(maxWidth: 260)
                        .focused($nameFieldFocused)
                        .onSubmit { editingName = false }
                    Button { editingName = false } label: {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 20))
                    }.buttonStyle(.plain).foregroundColor(.accentColor)
                } else {
                    Text(fullGreeting).font(.system(size: 34, weight: .bold, design: .rounded))
                    Button {
                        editingName = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { nameFieldFocused = true }
                    } label: {
                        Image(systemName: "pencil").font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit your name")
                }
            }
            if let np = engine.currentTrack {
                Text("Now playing — \(np.title) · \(np.artist)")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            } else {
                Text("Welcome back to Valentine")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 20) }
    }

    private var fullGreeting: String {
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? timeGreeting : "\(timeGreeting), \(name)"
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good night"
        }
    }

    // MARK: Stat cards

    private var statCards: some View {
        HStack(spacing: 14) {
            StatCard(icon: "person.2", value: engine.artists.count, label: "Artists")
            StatCard(icon: "square.stack", value: engine.albums.count, label: "Albums")
            StatCard(icon: "music.note", value: engine.queue.count, label: "Tracks")
        }
    }

    // MARK: Recently added

    /// Albums ordered by most-recently-added (highest library index first).
    private var recentAlbums: [Album] {
        engine.albums
            .sorted { ($0.trackIndices.max() ?? 0) > ($1.trackIndices.max() ?? 0) }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently added").font(.system(size: 18, weight: .semibold))
                Spacer()
                Button("See all") { selectedTab = .albums }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.accentColor)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(Array(recentAlbums.prefix(12))) { album in
                        AlbumTile(album: album) { open(album) }
                            .contextMenu {
                                Button("Play") { engine.playNow(album) }
                                Button("Shuffle") { engine.shuffle(album) }
                                Button("Play Next") { engine.playNext(album) }
                                Button("Add to Queue") { engine.enqueue(album) }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                let all = Array(engine.queue.indices)
                engine.shuffleNow(indices: all)
            } label: {
                Label("Shuffle Library", systemImage: "shuffle")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)

            Button { Task { await addMusic() } } label: {
                Label("Add Music", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)

            Button { Task { await fetchInfo() } } label: {
                if fetching {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Fetching…") }
                        .font(.system(size: 13, weight: .medium))
                } else {
                    Label("Fetch Artwork", systemImage: "wand.and.stars")
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .disabled(fetching)

            lastFMButton

            if let fetchSummary {
                Text(fetchSummary).font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
    }

    // MARK: Last.fm connect

    @ViewBuilder
    private var lastFMButton: some View {
        if lastFM.isConnected {
            Label("Last.fm: \(lastFM.username)", systemImage: "checkmark.seal.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Color.green.opacity(0.12)))
        } else {
            Button { connectLastFM() } label: {
                Label("Connect Last.fm", systemImage: "link")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
        }
    }

    /// Kick off Last.fm web auth (token -> browser). User approves, then the
    /// session completes on next foreground via finishLastFM().
    private func connectLastFM() {
        Task {
            guard let token = try? await lastFM.getToken() else {
                fetchSummary = "Couldn't reach Last.fm."
                return
            }
            let apiKey = Secrets.lastFMApiKey
            if let url = URL(string: "https://www.last.fm/api/auth/?api_key=\(apiKey)&token=\(token)") {
                NSWorkspace.shared.open(url)
            }
            // Complete the session when the user returns to the app.
            pendingLastFMToken = token
        }
    }

    /// Fetch missing cover art via Last.fm (uses the API key — no email needed).
    private func fetchInfo() async {
        fetching = true
        fetchSummary = nil
        let updated = await engine.autoFetchArtworkLastFM()
        fetching = false
        fetchSummary = updated > 0 ? "Added art to \(updated) track\(updated == 1 ? "" : "s")"
                                   : "No new artwork found"
    }

    // MARK: Empty-library add card

    private var addMusicCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 44)).foregroundColor(.accentColor)
            Text("Your library is empty")
                .font(.system(size: 17, weight: .semibold))
            Text("Add a folder of music to get started. Valentine will scan it, read tags, and fetch artwork.")
                .font(.system(size: 13)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
            HStack(spacing: 12) {
                Button { Task { await addMusic(folders: true) } } label: {
                    Text("Add Folder…").frame(width: 130)
                }.buttonStyle(.borderedProminent)
                Button { Task { await addMusic(folders: false) } } label: {
                    Text("Add Files…").frame(width: 130)
                }.buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
    }

    // MARK: Actions

    private func open(_ album: Album) {
        engine.navigateToAlbumID = album.id   // LibrarySidebar routes to Albums tab
    }

    private func addMusic(folders: Bool = true) async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = folders
        panel.canChooseFiles = !folders
        if !folders { panel.allowedContentTypes = [.audio] }
        guard panel.runModal() == .OK else { return }
        let added = await engine.importFromDisk(panel.urls)
        // Auto-grab artwork for the new tracks via Last.fm (no email needed).
        if added > 0 { await fetchInfo() }
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let icon: String
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18)).foregroundColor(.accentColor)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)").font(.system(size: 20, weight: .bold)).monospacedDigit()
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }
}

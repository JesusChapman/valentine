import SwiftUI
import Combine

// MARK: - Foobar-style left navigation rail

enum LibraryTab: String, CaseIterable, Identifiable {
    case home      = "Home"
    case playlist  = "Playlist"
    case favorites = "Favorites"
    case songs     = "Songs"
    case albums    = "Albums"
    case artists   = "Artists"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:      return "house"
        case .playlist:  return "music.note.list"
        case .favorites: return "heart"
        case .songs:     return "music.note"
        case .albums:    return "square.stack"
        case .artists:   return "person.2"
        }
    }
}
struct LibrarySidebar: View {
    @ObservedObject var engine: AudioEngine
    @Binding var selectedTab: LibraryTab

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                ForEach(LibraryTab.allCases) { tab in
                    Button { withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab } } label: {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15))
                            .frame(width: 36, height: 36)
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedTab == tab ? Color.white.opacity(0.12) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(tab.rawValue)
                }
                Spacer()
            }
            .padding(.top, 12)
            .frame(width: 48)

            Divider().opacity(0.15)

            Group {
                switch selectedTab {
                case .home:      HomeView(engine: engine, selectedTab: $selectedTab)
                case .playlist:  PlaylistView(engine: engine)
                case .favorites: FavoritesView(engine: engine)
                case .songs:     SongsTableView(engine: engine)
                case .albums:    AlbumGridView(engine: engine)
                case .artists:   ArtistListView(engine: engine)
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(engine.objectWillChange) { _ in
            if engine.navigateToAlbumID != nil, selectedTab != .albums {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .albums }
            }
        }
    }
}

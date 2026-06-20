import Foundation

struct LRCLibResponse: Codable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}

class LRCLibService {
    static let shared = LRCLibService()
    
    func searchLyrics(trackName: String, artistName: String) async throws -> String? {
        guard var components = URLComponents(string: "https://lrclib.net/api/search") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName)
        ]
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Valentine macOS Music Player", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let responses = try JSONDecoder().decode([LRCLibResponse].self, from: data)
        
        if let synced = responses.first(where: { $0.syncedLyrics != nil && !$0.syncedLyrics!.isEmpty })?.syncedLyrics {
            return synced
        }
        
        return responses.first?.plainLyrics
    }
}

import SwiftUI

struct LyricsSearchView: View {
    @Environment(\.dismiss) var dismiss
    
    @State var trackName: String = ""
    @State var artistName: String = ""
    
    var onSelect: (String) -> Void
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Search Lyrics (LRCLIB)")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Track Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("e.g. My Ordinary Life", text: $trackName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Artist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("e.g. The Living Tombstone", text: $artistName)
                    .textFieldStyle(.roundedBorder)
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: search) {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Search")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(trackName.isEmpty || artistName.isEmpty || isLoading)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 350)
    }
    
    private func search() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if let lyrics = try await LRCLibService.shared.searchLyrics(trackName: trackName, artistName: artistName) {
                    await MainActor.run {
                        onSelect(lyrics)
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "No lyrics found."
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

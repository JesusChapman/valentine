import SwiftUI

struct QueueRowView: View {
    let track: Track
    let isPlaying: Bool
    let isSelectionMode: Bool
    let isSelected: Bool
    let activeTint: Color
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? activeTint : .secondary)
            }
            
            if let albumArt = track.albumArt {
                albumArt
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.primary.opacity(0.3))
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
            
            Text(track.duration.formatTime())
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            
            if isPlaying && !isSelectionMode {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.primary)
                    .font(.system(size: 12))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPlaying && !isSelectionMode ? Color.primary.opacity(0.15) : (isSelected ? activeTint.opacity(0.2) : Color.clear))
        )
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .animation(.easeInOut(duration: 0.2), value: isSelectionMode)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

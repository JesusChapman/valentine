import SwiftUI

struct LyricsEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var engine: AudioEngine
    
    @State private var lyricsText: String = ""
    @State private var showSearch = false
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Lyrics")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    if let string = NSPasteboard.general.string(forType: .string) {
                        lyricsText = string
                    }
                }) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .padding(.horizontal, 8)
                .glassEffect(.regular.interactive())
                
                Button(action: {
                    showSearch = true
                }) {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .padding(.horizontal, 8)
                .glassEffect(.regular.interactive())
                
                Button(action: save) {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 8)
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .glassEffect(.regular.interactive())
                .disabled(isSaving)
                
                Button(action: {
                    dismiss()
                })
                {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .padding(.leading, 8)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .padding()
            }
            
            TextEditor(text: $lyricsText)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color.clear)
        }
        .frame(width: 500, height: 600)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            if let lines = engine.currentTrack?.lyrics {
                lyricsText = lines.map { line in
                    let min = Int(line.time) / 60
                    let sec = Int(line.time) % 60
                    let frac = Int((line.time.truncatingRemainder(dividingBy: 1)) * 100)
                    return String(format: "[%02d:%02d.%02d]%@", min, sec, frac, line.text)
                }.joined(separator: "\n")
            }
        }
        .sheet(isPresented: $showSearch) {
            LyricsSearchView(
                trackName: engine.currentTrack?.title ?? "",
                artistName: engine.currentTrack?.artist ?? "",
                onSelect: { fetchedLyrics in
                    lyricsText = fetchedLyrics
                }
            )
        }
    }
    
    private func save() {
        guard let track = engine.currentTrack else { return }
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                try await LyricsWriter.writeLyrics(to: track.url, lyrics: lyricsText)
                await MainActor.run {
                    engine.updateCurrentTrackLyrics(with: lyricsText)
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

import SwiftUI

/// Inline metadata editor sheet. Writes tags to disk via the engine
/// (which uses the bundled mutagen pipeline).
struct MetadataEditorView: View {
    @ObservedObject var engine: AudioEngine
    let trackIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var artist = ""
    @State private var albumArtist = ""
    @State private var album = ""
    @State private var genre = ""
    @State private var year = ""
    @State private var trackNumber = ""
    @State private var saving = false
    @State private var mutagenMissing = false

    private var track: Track? {
        engine.queue.indices.contains(trackIndex) ? engine.queue[trackIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Metadata").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        AlbumArtView(image: track?.albumArt, size: 72, corner: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track?.title ?? "—").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            Text(track?.url.lastPathComponent ?? "")
                                .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }

                    field("Title", $title)
                    field("Artist", $artist)
                    field("Album Artist", $albumArtist)
                    field("Album", $album)
                    field("Genre", $genre)
                    HStack(spacing: 12) {
                        field("Year", $year).frame(width: 120)
                        field("Track #", $trackNumber).frame(width: 100)
                        Spacer()
                    }

                    if mutagenMissing {
                        Text("Tag editor needs the metadata helper. Open the lyrics editor once to install it, then try again.")
                            .font(.caption).foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button {
                    save()
                } label: {
                    if saving { ProgressView().controlSize(.small) }
                    else { Text("Save") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving)
            }
            .padding()
        }
        .frame(width: 440, height: 560)
        .onAppear(perform: load)
    }

    private func field(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                .foregroundColor(.secondary)
            TextField("", text: binding)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        guard let t = track else { return }
        title = t.title
        artist = t.artist
        albumArtist = t.albumArtist ?? ""
        album = t.album ?? ""
        genre = t.genre ?? ""
        year = t.year.map(String.init) ?? ""
        trackNumber = t.trackNumber.map(String.init) ?? ""
    }

    private func save() {
        // Require the mutagen helper (same gate the lyrics editor uses).
        let path = MutagenInstallerService.mutagenTargetDirectory.appendingPathComponent("mutagen").path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            mutagenMissing = true
            return
        }

        saving = true
        let edit = TrackMetadataEdit(
            title: title, artist: artist, albumArtist: albumArtist,
            album: album, genre: genre, year: year, trackNumber: trackNumber
        )
        engine.applyMetadataEdit(edit, toTrackAt: trackIndex)
        // The disk write runs async; in-memory + persisted update is immediate.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            saving = false
            dismiss()
        }
    }
}

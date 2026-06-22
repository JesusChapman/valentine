import SwiftUI

/// Batch metadata editor. Each field has an enable checkbox — only enabled
/// fields are applied across all selected tracks; the rest are left untouched.
struct BatchEditorView: View {
    @ObservedObject var engine: AudioEngine
    let indices: [Int]
    @Environment(\.dismiss) private var dismiss

    @State private var setAlbumArtist = false
    @State private var setAlbum = false
    @State private var setGenre = false
    @State private var setYear = false

    @State private var albumArtist = ""
    @State private var album = ""
    @State private var genre = ""
    @State private var year = ""

    @State private var saving = false
    @State private var mutagenMissing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit \(indices.count) Tracks").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding()
            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    Text("Only checked fields are applied to every selected track.")
                        .font(.caption).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    row("Album Artist", isOn: $setAlbumArtist, text: $albumArtist)
                    row("Album", isOn: $setAlbum, text: $album)
                    row("Genre", isOn: $setGenre, text: $genre)
                    row("Year", isOn: $setYear, text: $year)

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
                    if saving { ProgressView().controlSize(.small) } else { Text("Apply") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving || !(setAlbumArtist || setAlbum || setGenre || setYear))
            }
            .padding()
        }
        .frame(width: 440, height: 420)
    }

    private func row(_ label: String, isOn: Binding<Bool>, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: isOn).labelsHidden()
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold)).tracking(0.5)
                    .foregroundColor(.secondary)
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!isOn.wrappedValue)
                    .opacity(isOn.wrappedValue ? 1 : 0.4)
            }
        }
    }

    private func save() {
        let path = MutagenInstallerService.mutagenTargetDirectory.appendingPathComponent("mutagen").path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            mutagenMissing = true
            return
        }
        saving = true
        engine.applyBatchEdit(
            albumArtist: setAlbumArtist ? albumArtist : nil,
            album: setAlbum ? album : nil,
            genre: setGenre ? genre : nil,
            year: setYear ? year : nil,
            indices: indices
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            saving = false
            dismiss()
        }
    }
}

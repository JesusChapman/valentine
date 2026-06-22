import Foundation

/// Writes standard tags to an audio file using the bundled mutagen (Python),
/// mirroring LyricsWriter's approach: an embedded script run via Process.
/// Handles MP3 (ID3), MP4/M4A, and FLAC/OGG (Vorbis comments).
struct TrackMetadataEdit {
    var title: String
    var artist: String
    var albumArtist: String
    var album: String
    var genre: String
    var year: String        // string so empty == "leave unset"
    var trackNumber: String
}

enum MetadataWriter {
    static func write(to url: URL, edit: TrackMetadataEdit) async throws {
        let script = """
import sys
mutagen_path = sys.argv[1]
sys.path.insert(0, mutagen_path)

import mutagen
import json

def set_tags(file_path, data):
    f = mutagen.File(file_path)
    if f is None:
        print("Unsupported file format")
        sys.exit(1)

    if f.tags is None:
        f.add_tags()
    tags = f.tags
    tname = type(tags).__name__

    title       = data.get("title", "")
    artist      = data.get("artist", "")
    albumartist = data.get("albumArtist", "")
    album       = data.get("album", "")
    genre       = data.get("genre", "")
    year        = data.get("year", "")
    track       = data.get("trackNumber", "")

    # MP3 / ID3
    if hasattr(tags, "add") and tname == "ID3":
        from mutagen.id3 import TIT2, TPE1, TPE2, TALB, TCON, TDRC, TRCK
        def put(frame_cls, key, value):
            tags.delall(key)
            if value:
                tags.add(frame_cls(encoding=3, text=value))
        put(TIT2, "TIT2", title)
        put(TPE1, "TPE1", artist)
        put(TPE2, "TPE2", albumartist)
        put(TALB, "TALB", album)
        put(TCON, "TCON", genre)
        put(TDRC, "TDRC", year)
        put(TRCK, "TRCK", track)

    # MP4 / M4A
    elif tname == "MP4Tags":
        def setk(k, v):
            if v: tags[k] = [v]
            elif k in tags: del tags[k]
        setk("\\xa9nam", title)
        setk("\\xa9ART", artist)
        setk("aART", albumartist)
        setk("\\xa9alb", album)
        setk("\\xa9gen", genre)
        setk("\\xa9day", year)
        if track:
            try: tags["trkn"] = [(int(track), 0)]
            except: pass

    # FLAC / OGG (Vorbis comments)
    else:
        def setv(k, v):
            if v: tags[k] = [v]
            elif k in tags: del tags[k]
        setv("TITLE", title)
        setv("ARTIST", artist)
        setv("ALBUMARTIST", albumartist)
        setv("ALBUM", album)
        setv("GENRE", genre)
        setv("DATE", year)
        setv("TRACKNUMBER", track)

    f.save()

if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(1)
    file_path = sys.argv[2]
    data = json.loads(sys.argv[3])
    set_tags(file_path, data)
"""

        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("write_metadata.py")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let payload: [String: String] = [
            "title": edit.title,
            "artist": edit.artist,
            "albumArtist": edit.albumArtist,
            "album": edit.album,
            "genre": edit.genre,
            "year": edit.year,
            "trackNumber": edit.trackNumber
        ]
        let json = String(data: try JSONSerialization.data(withJSONObject: payload), encoding: .utf8) ?? "{}"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let mutagenPath = MutagenInstallerService.mutagenLibraryPath
        process.arguments = ["python3", scriptURL.path, mutagenPath, url.path, json]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "MetadataWriter", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}

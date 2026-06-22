//  ArtworkWriter.swift
//  Embeds cover art into files via mutagen (ID3 APIC / MP4 covr / FLAC picture).

import Foundation
import AppKit

enum ArtworkWriter {
    /// Write JPEG/PNG `imageData` as the front cover of the file at `url`.
    static func write(imageData: Data, mime: String = "image/jpeg", to url: URL) async throws {
        let script = """
import sys
mutagen_path = sys.argv[1]
sys.path.insert(0, mutagen_path)

import mutagen

def set_cover(file_path, image_path, mime):
    with open(image_path, "rb") as fh:
        data = fh.read()

    f = mutagen.File(file_path)
    if f is None:
        print("Unsupported file format")
        sys.exit(1)

    tname = type(f.tags).__name__ if f.tags is not None else ""

    # MP3 / ID3 -> APIC
    if tname == "ID3" or file_path.lower().endswith(".mp3"):
        from mutagen.id3 import ID3, APIC, error
        try:
            audio = ID3(file_path)
        except error:
            audio = ID3()
        audio.delall("APIC")
        audio.add(APIC(encoding=3, mime=mime, type=3, desc="Cover", data=data))
        audio.save(file_path)

    # MP4 / M4A -> covr
    elif tname == "MP4Tags" or file_path.lower().endswith((".m4a", ".mp4", ".m4b")):
        from mutagen.mp4 import MP4, MP4Cover
        audio = MP4(file_path)
        fmt = MP4Cover.FORMAT_PNG if mime == "image/png" else MP4Cover.FORMAT_JPEG
        audio["covr"] = [MP4Cover(data, imageformat=fmt)]
        audio.save()

    # FLAC -> Picture block
    elif file_path.lower().endswith(".flac"):
        from mutagen.flac import FLAC, Picture
        audio = FLAC(file_path)
        audio.clear_pictures()
        pic = Picture()
        pic.type = 3
        pic.mime = mime
        pic.desc = "Cover"
        pic.data = data
        audio.add_picture(pic)
        audio.save()

    else:
        print("Artwork embedding not supported for this format")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 5:
        sys.exit(1)
    set_cover(sys.argv[2], sys.argv[3], sys.argv[4])
"""

        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("write_artwork.py")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        // mutagen needs a file path for the image; write it to temp.
        let imgURL = tempDir.appendingPathComponent("cover_\(UUID().uuidString)")
        try imageData.write(to: imgURL)
        defer { try? FileManager.default.removeItem(at: imgURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let mutagenPath = MutagenInstallerService.mutagenLibraryPath
        process.arguments = ["python3", scriptURL.path, mutagenPath, url.path, imgURL.path, mime]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ArtworkWriter", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    /// Convenience: encode an NSImage to JPEG and embed it.
    static func write(image: NSImage, to url: URL) async throws {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            throw NSError(domain: "ArtworkWriter", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not encode image"])
        }
        try await write(imageData: jpeg, mime: "image/jpeg", to: url)
    }
}

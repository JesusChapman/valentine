import Foundation

class LyricsWriter {
    static func writeLyrics(to url: URL, lyrics: String) async throws {
        let script = """
import sys
import os

# Add the newly downloaded mutagen library path to sys.path
mutagen_path = sys.argv[1]
sys.path.insert(0, mutagen_path)

import mutagen

def set_lyrics(file_path, lyrics):
    f = mutagen.File(file_path)
    if f is None:
        print("Unsupported file format")
        sys.exit(1)
    
    tags = f.tags
    if tags is None:
        f.add_tags()
        tags = f.tags
        
    # MP3 (ID3)
    if hasattr(tags, "add"):
        from mutagen.id3 import USLT
        keys_to_remove = [k for k in tags.keys() if k.startswith("USLT") or k.startswith("SYLT")]
        for k in keys_to_remove:
            tags.pop(k)
            
        tags.add(USLT(encoding=3, lang='eng', desc='', text=lyrics))
    # MP4 (M4A)
    elif type(tags).__name__ == "MP4Tags":
        tags['\\xa9lyr'] = lyrics
    # FLAC / OGG
    elif type(tags).__name__ in ["VCFLACDict", "VCOggDict", "OggVorbis", "OggOpus", "OggSpeex"]:
        tags['LYRICS'] = [lyrics]
    # Fallback
    else:
        try:
            tags['LYRICS'] = lyrics
        except:
            pass
        
    f.save()

if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(1)
    
    file_path = sys.argv[2]
    lyrics = sys.argv[3]
    set_lyrics(file_path, lyrics)
"""
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("write_lyrics.py")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        let mutagenPath = MutagenInstallerService.mutagenLibraryPath
        process.arguments = ["python3", scriptURL.path, mutagenPath, url.path, lyrics]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "LyricsWriter", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorString])
        }
    }
}

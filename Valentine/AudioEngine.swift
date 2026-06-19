import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
class AudioEngine: ObservableObject {
    @Published var queue: [Track] = []
    @Published var currentTrackIndex: Int?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var showLyrics: Bool = false
    @Published var showLyricsEditor: Bool = false
    @Published var isGlowEffectEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isGlowEffectEnabled, forKey: "isGlowEffectEnabled")
        }
    }
    @Published var isNeonEffectEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isNeonEffectEnabled, forKey: "isNeonEffectEnabled")
        }
    }
    @Published var volume: Float = 1.0 {
        didSet {
            player?.volume = volume
        }
    }
    
    @Published var waveformPoints: [Float] = []
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    var currentTrack: Track? {
        guard let index = currentTrackIndex, queue.indices.contains(index) else { return nil }
        return queue[index]
    }
    
    init() {
        self.isGlowEffectEnabled = UserDefaults.standard.bool(forKey: "isGlowEffectEnabled")
        self.isNeonEffectEnabled = UserDefaults.standard.bool(forKey: "isNeonEffectEnabled")
        setupAudioSession()
        
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            let newGlow = UserDefaults.standard.bool(forKey: "isGlowEffectEnabled")
            let newNeon = UserDefaults.standard.bool(forKey: "isNeonEffectEnabled")
            if self.isGlowEffectEnabled != newGlow { self.isGlowEffectEnabled = newGlow }
            if self.isNeonEffectEnabled != newNeon { self.isNeonEffectEnabled = newNeon }
        }
    }
    
    private func setupAudioSession() {
    }
    
    #if os(macOS)
    func showAddFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio]
        if panel.runModal() == .OK {
            self.addTracks(panel.urls)
        }
    }
    
    func showAddFolderDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK {
            self.addTracks(panel.urls)
        }
    }
    #endif
    
    func clearPlaylist() {
        self.queue.removeAll()
        self.currentTrackIndex = nil
        self.player?.pause()
        self.isPlaying = false
        self.currentTime = 0
        self.duration = 0
    }
    
    func addTracks(_ urls: [URL]) {
        Task {
            var audioURLs: [URL] = []
            let fileManager = FileManager.default
            let supportedExtensions = Set(["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "alac"])
            
            for url in urls {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                            for case let fileURL as URL in enumerator {
                                let ext = fileURL.pathExtension.lowercased()
                                if supportedExtensions.contains(ext) {
                                    audioURLs.append(fileURL)
                                }
                            }
                        }
                    } else {
                        audioURLs.append(url)
                    }
                }
            }
            
            for url in audioURLs {
                var track = Track(url: url)
                await track.loadMetadata()
                self.queue.append(track)
            }
            if self.currentTrackIndex == nil && !self.queue.isEmpty {
                self.playTrack(at: 0, autoPlay: false)
            }
        }
    }
    
    func playTrack(at index: Int, autoPlay: Bool = true) {
        guard queue.indices.contains(index) else { return }
        let track = queue[index]
        
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        let playerItem = AVPlayerItem(url: track.url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume
        currentTrackIndex = index
        duration = track.duration
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            if self.duration > 0 && self.currentTime >= self.duration - 0.1 {
                self.nextTrack()
            }
        }
        
        generateWaveform(for: track.url)
        if autoPlay {
            play()
        } else {
            isPlaying = false
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func nextTrack() {
        guard let currentIndex = currentTrackIndex else { return }
        if currentIndex + 1 < queue.count {
            playTrack(at: currentIndex + 1)
        } else {
            pause()
            currentTime = 0
            player?.seek(to: .zero)
        }
    }
    
    func previousTrack() {
        guard let currentIndex = currentTrackIndex else { return }
        if currentTime > 3.0 {
            player?.seek(to: .zero)
            currentTime = 0
        } else if currentIndex > 0 {
            playTrack(at: currentIndex - 1)
        }
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
        currentTime = time
    }
    
    func removeTrack(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
    }
    
    func removeTracks(withIds ids: Set<UUID>) {
        let currentTrackId = currentTrack?.id
        
        let indicesToRemove = queue.enumerated().compactMap { index, track in
            ids.contains(track.id) ? index : nil
        }
        
        queue.remove(atOffsets: IndexSet(indicesToRemove))
        
        if let currentId = currentTrackId {
            if ids.contains(currentId) {
                pause()
                currentTrackIndex = queue.isEmpty ? nil : 0
                if !queue.isEmpty {
                    playTrack(at: 0)
                }
            } else {
                currentTrackIndex = queue.firstIndex(where: { $0.id == currentId })
            }
        }
    }
    
    private func generateWaveform(for url: URL) {
        Task.detached {
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let frameCount = AVAudioFrameCount(file.length)
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
                try file.read(into: buffer)
                
                guard let floatChannelData = buffer.floatChannelData else { return }
                
                let channelCount = Int(format.channelCount)
                let length = Int(buffer.frameLength)
                
                let targetSamples = 100
                let samplesPerPoint = max(1, length / targetSamples)
                
                var points: [Float] = []
                
                for i in 0..<targetSamples {
                    let startIdx = i * samplesPerPoint
                    let endIdx = min(startIdx + samplesPerPoint, length)
                    var maxAmplitude: Float = 0
                    
                    for j in startIdx..<endIdx {
                        for channel in 0..<channelCount {
                            let value = abs(floatChannelData[channel][j])
                            if value > maxAmplitude {
                                maxAmplitude = value
                            }
                        }
                    }
                    points.append(maxAmplitude)
                }
                
                let overallMax = points.max() ?? 1.0
                let normalized = points.map { $0 / overallMax }
                
                await MainActor.run {
                    self.waveformPoints = normalized
                }
                
            } catch {
                print("Error generating waveform: \(error)")
            }
        }
    }
    
    func updateCurrentTrackLyrics(with text: String) {
        guard let index = currentTrackIndex else { return }
        var track = queue[index]
        track.updateLyrics(from: text)
        queue[index] = track
    }
}

import Foundation
import AVFoundation
import Combine
import SwiftUI
import MediaPlayer
import AppKit

enum RepeatMode: Int {
    case off = 0
    case one = 1
    case all = 2
}

@MainActor
class AudioEngine: ObservableObject {
    @Published var queue: [Track] = []
    @Published var currentTrackIndex: Int?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var showLyrics: Bool = false
    @Published var showLyricsEditor: Bool = false
    @Published var showMutagenInstaller: Bool = false
    @Published private(set) var currentArtworkColor: NSColor?
    
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffleMode: Bool = false
    @Published var volume: Float = 1.0 {
        didSet {
            player?.volume = volume
        }
    }
    
    @Published var waveformPoints: [Float] = []
    private var musicEnvelope: [Float] = []
    private var spectrumFrames: [[Float]] = []

    var currentSpectrum: [Float] {
        let silence = [Float](repeating: 0, count: SpectrumAnalyzer.bandCount)
        guard isPlaying, let seconds = player?.currentTime().seconds,
              seconds.isFinite, seconds >= 0 else { return silence }
        // FFT windows describe their centers, not their leading edges.
        let position = max(0, seconds / envelopeStep - 0.5)
        guard position < Double(spectrumFrames.count) else { return silence }
        let index = Int(position)
        let next = min(index + 1, spectrumFrames.count - 1)
        let fraction = Float(position - Double(index))
        return zip(spectrumFrames[index], spectrumFrames[next]).map { $0 * (1 - fraction) + $1 * fraction }
    }
    private var envelopeStep: Double = 0.02
    private var waveformTask: Task<Void, Never>?
    private var analysisGeneration = UUID()

    /// Sample the decoded energy envelope at the player's actual position,
    /// rather than the less frequent UI time observer (also handles seeking).
    var backgroundPulse: Float {
        guard isPlaying, !musicEnvelope.isEmpty,
              let seconds = player?.currentTime().seconds,
              seconds.isFinite, seconds >= 0 else { return 0 }
        let position = seconds / envelopeStep
        guard position < Double(musicEnvelope.count) else { return 0 }
        let index = Int(position)
        let next = min(index + 1, musicEnvelope.count - 1)
        let fraction = Float(position - Double(index))
        return musicEnvelope[index] * (1 - fraction) + musicEnvelope[next] * fraction
    }
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var userDefaultsObserver: NSObjectProtocol?
    
    private var hasScrobbledCurrentTrack = false
    private var currentTrackStartTime: Int = 0
    
    var currentTrack: Track? {
        guard let index = currentTrackIndex, queue.indices.contains(index) else { return nil }
        return queue[index]
    }

    /// Exposes the active player read-only so AVKit can present the native
    /// AirPlay route picker without allowing views to control playback state.
    var routePickerPlayer: AVPlayer? {
        player
    }

    /// Preserves the artwork's hue, but adjusts its brightness so it remains
    /// legible on the dynamic background in either system appearance.
    func dominantArtworkColor(for colorScheme: ColorScheme) -> Color? {
        guard let artworkColor = currentArtworkColor,
              let sRGBColor = artworkColor.usingColorSpace(.sRGB) else {
            return nil
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        sRGBColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let adjustedBrightness = colorScheme == .dark
            ? min(max(brightness, 0.65), 0.92)
            : min(max(brightness, 0.28), 0.50)
        return Color(
            hue: Double(hue),
            saturation: Double(max(saturation, 0.55)),
            brightness: Double(adjustedBrightness),
            opacity: Double(alpha)
        )
    }

    func activeControlTint(for colorScheme: ColorScheme) -> Color {
        dominantArtworkColor(for: colorScheme) ?? .accentColor
    }
    
    init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        
    }
    
    deinit {
        waveformTask?.cancel()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let defaultsObserver = userDefaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }
    
    private func setupAudioSession() {
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            Task { @MainActor [weak self] in self?.play() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            Task { @MainActor [weak self] in self?.togglePlayback() }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            Task { @MainActor [weak self] in self?.nextTrack() }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            Task { @MainActor [weak self] in self?.previousTrack() }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = positionEvent.positionTime
            Task { @MainActor [weak self] in self?.seek(to: time) }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        if let track = currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
            if let album = track.album {
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
            }
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            
            if let nsImage = track.nsImage {
                let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
        self.currentArtworkColor = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
                            while let fileURL = enumerator.nextObject() as? URL {
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
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        
        let playerItem = AVPlayerItem(url: track.url)
        
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.nextTrack(isAutomatic: true)
            }
        }
        
        player = AVPlayer(playerItem: playerItem)
        player?.allowsExternalPlayback = true
        player?.volume = volume
        currentTime = 0
        waveformPoints = []
        currentTrackIndex = index
        duration = track.duration
        currentArtworkColor = track.nsImage?.dominantArtworkColor()
        
        hasScrobbledCurrentTrack = false
        currentTrackStartTime = Int(Date().timeIntervalSince1970)
        LastFMService.shared.updateNowPlaying(track: track.title, artist: track.artist, album: track.album, duration: Int(track.duration))
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = time.seconds
                
                if let currentTrack = self.currentTrack, self.duration > 30 && !self.hasScrobbledCurrentTrack {
                    let scrobblePoint = min(self.duration / 2.0, 240.0) // 50% or 4 minutes
                    if self.currentTime >= scrobblePoint {
                        self.hasScrobbledCurrentTrack = true
                        LastFMService.shared.scrobble(track: currentTrack.title, artist: currentTrack.artist, album: currentTrack.album, timestamp: self.currentTrackStartTime)
                    }
                }
            }
        }
        
        generateWaveform(for: track.url)
        if autoPlay {
            play()
        } else {
            isPlaying = false
            updateNowPlayingInfo()
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
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func nextTrack(isAutomatic: Bool = false) {
        guard let currentIndex = currentTrackIndex else { return }
        
        if isAutomatic && repeatMode == .one {
            repeatMode = .off
            playTrack(at: currentIndex)
            return
        }
        
        if shuffleMode {
            if queue.count > 1 {
                var nextIndex = Int.random(in: 0..<queue.count)
                while nextIndex == currentIndex {
                    nextIndex = Int.random(in: 0..<queue.count)
                }
                playTrack(at: nextIndex)
            } else {
                if repeatMode == .all {
                    playTrack(at: currentIndex)
                } else {
                    pause()
                    currentTime = 0
                    player?.seek(to: .zero)
                }
            }
            return
        }
        
        if currentIndex + 1 < queue.count {
            playTrack(at: currentIndex + 1)
        } else {
            if repeatMode == .all {
                playTrack(at: 0)
            } else {
                pause()
                currentTime = 0
                player?.seek(to: .zero)
            }
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
        updateNowPlayingInfo()
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
        waveformTask?.cancel()
        musicEnvelope = []
        spectrumFrames = []
        let generation = UUID()
        analysisGeneration = generation
        waveformTask = Task.detached(priority: .utility) { [weak self] in
            do {
                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                guard format.sampleRate > 0, file.length > 0 else { return }
                // Decode in 20 ms blocks, avoiding a whole-song PCM allocation.
                let capacity = AVAudioFrameCount(max(1, format.sampleRate * 0.02))
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
                let channelCount = Int(format.channelCount)
                let analyzer = SpectrumAnalyzer(sampleRate: format.sampleRate, blockSize: Int(capacity))
                var spectra: [[Float]] = []
                var publishedSpectra = 0
                let analysisStep = Double(capacity) / format.sampleRate
                var points = [Float](repeating: 0, count: 100)
                var envelope: [Float] = []
                while file.framePosition < file.length {
                    try Task.checkCancellation()
                    let offset = file.framePosition
                    try file.read(into: buffer, frameCount: capacity)
                    let length = Int(buffer.frameLength)
                    guard length > 0, let samples = buffer.floatChannelData else { break }
                    var squareSum: Double = 0
                    for j in 0..<length {
                        let bin = min(99, Int((offset + Int64(j)) * 100 / file.length))
                        for channel in 0..<channelCount {
                            let value = samples[channel][j]
                            guard value.isFinite else { continue }
                            points[bin] = max(points[bin], abs(value))
                            squareSum += Double(value) * Double(value)
                        }
                    }
                    envelope.append(Float(sqrt(squareSum / Double(max(1, length * channelCount)))))
                    spectra.append(analyzer?.analyze(channels: samples, count: channelCount, frames: length)
                        ?? [Float](repeating: 0, count: SpectrumAnalyzer.bandCount))
                    // Start reacting after the first second is decoded, not after the whole song.
                    // Subsequent batches amortize actor hops; generation guards reject stale tracks.
                    if spectra.count == 50 || spectra.count.isMultiple(of: 500) {
                        let chunk = Array(spectra[publishedSpectra...])
                        publishedSpectra = spectra.count
                        await MainActor.run { [weak self] in
                            guard let self, self.analysisGeneration == generation,
                                  self.currentTrack?.url == url else { return }
                            self.spectrumFrames.append(contentsOf: chunk)
                            self.envelopeStep = analysisStep
                        }
                    }
                }
                let overallMax = max(points.max() ?? 0, 0.000_001)
                let normalized = points.map { $0 / overallMax }
                let energyMax = max(envelope.max() ?? 0, 0.000_001)
                var smoothed: Float = 0
                for index in envelope.indices {
                    let target = envelope[index] / energyMax
                    // Fast attack and slower release produce a gentle pulse.
                    smoothed += (target - smoothed) * (target > smoothed ? 0.55 : 0.16)
                    envelope[index] = smoothed
                }
                let completedEnvelope = envelope
                let completedSpectra = spectra
                let step = Double(capacity) / format.sampleRate
                await MainActor.run { [weak self] in
                    guard let self, self.analysisGeneration == generation,
                          self.currentTrack?.url == url else { return }
                    self.waveformPoints = normalized
                    self.musicEnvelope = completedEnvelope
                    self.spectrumFrames = completedSpectra
                    self.envelopeStep = step
                }
            } catch is CancellationError {
                // A newer track owns the background now.
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
    
    func checkAndShowLyricsEditor() {
        let path = MutagenInstallerService.mutagenTargetDirectory.appendingPathComponent("mutagen").path
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue {
            showLyricsEditor = true
        } else {
            showMutagenInstaller = true
        }
    }
}

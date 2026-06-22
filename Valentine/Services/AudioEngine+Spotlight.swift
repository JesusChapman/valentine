//  AudioEngine+Spotlight.swift
//  Keeps the Spotlight index in sync and plays tracks from search results.

import Foundation
import CoreSpotlight

extension AudioEngine {

    // Debounce token via associated object (pure extension, no stored prop).
    private static var _spotlightWorkKey = 0
    private var spotlightWorkItem: DispatchWorkItem? {
        get { objc_getAssociatedObject(self, &Self._spotlightWorkKey) as? DispatchWorkItem }
        set { objc_setAssociatedObject(self, &Self._spotlightWorkKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// Rebuild the Spotlight index from the current library, debounced 1.5s.
    /// Call this whenever `queue` changes.
    func scheduleSpotlightReindex() {
        spotlightWorkItem?.cancel()
        let snapshot = queue
        let work = DispatchWorkItem {
            SpotlightIndexer.reindex(snapshot)
        }
        spotlightWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    /// Handle a Spotlight result tap. The activity carries the file path as the
    /// CSSearchableItem identifier. Find that track and play it.
    func handleSpotlightActivity(_ userInfo: [AnyHashable: Any]) {
        guard let path = userInfo[CSSearchableItemActivityIdentifier] as? String else { return }
        playTrackByPath(path)
    }

    /// Play the library track whose file lives at `path` (standardized).
    func playTrackByPath(_ path: String) {
        let target = URL(fileURLWithPath: path).standardizedFileURL.path
        if let index = queue.firstIndex(where: { $0.url.standardizedFileURL.path == target }) {
            playTrack(at: index)
            return
        }
        // Not in the library yet (e.g. external file) — add then play.
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        Task {
            await importFromDisk([url])
            if let index = queue.firstIndex(where: { $0.url.standardizedFileURL.path == target }) {
                playTrack(at: index)
            }
        }
    }
}

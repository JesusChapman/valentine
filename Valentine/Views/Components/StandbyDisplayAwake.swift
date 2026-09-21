import AppKit
import SwiftUI

/// Keeps the display awake only while the Stand By view belongs to a window.
/// This prevents idle display sleep, without changing the user's power settings
/// or preventing an explicit Sleep command. Playback may be paused in Stand By.
struct StandbyDisplayAwake: NSViewRepresentable {
    func makeNSView(context: Context) -> DisplayAwakeView { DisplayAwakeView() }
    func updateNSView(_ nsView: DisplayAwakeView, context: Context) {}
    static func dismantleNSView(_ nsView: DisplayAwakeView, coordinator: ()) {
        nsView.stop()
    }

    final class DisplayAwakeView: NSView {
        // Foundation also ends the activity if this token is deallocated.
        private var activity: NSObjectProtocol?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard let window else { return }
            activity = ProcessInfo.processInfo.beginActivity(
                options: .idleDisplaySleepDisabled,
                reason: "Keep the display awake during Valentine Stand By"
            )
            NotificationCenter.default.addObserver(self, selector: #selector(stop),
                name: NSWindow.willCloseNotification, object: window)
        }

        @objc func stop() {
            NotificationCenter.default.removeObserver(self)
            if let activity {
                ProcessInfo.processInfo.endActivity(activity)
                self.activity = nil
            }
        }
    }
}

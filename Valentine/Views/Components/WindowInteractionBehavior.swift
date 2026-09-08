import SwiftUI
import AppKit

/// Clears only the automatic initial responder. Tab navigation remains available.
struct InitialWindowFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> FocusView { FocusView() }
    func updateNSView(_ nsView: FocusView, context: Context) {}
    static func dismantleNSView(_ nsView: FocusView, coordinator: ()) { nsView.stop() }

    final class FocusView: NSView {
        private var observers: [NSObjectProtocol] = []
        private var inputMonitor: Any?
        private var applied = false
        private var interacted = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            applied = false
            interacted = false
            guard let window else { return }
            inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
                if event.window === self?.window { self?.interacted = true }
                return event
            }
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification,
                object: window, queue: .main) { [weak self] _ in self?.clearInitialFocus() })
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                object: window, queue: .main) { [weak self] _ in
                    self?.applied = false
                    self?.interacted = false
                })
            clearInitialFocus()
        }

        private func clearInitialFocus() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window, window.isKeyWindow,
                      !self.applied, !self.interacted else { return }
                window.initialFirstResponder = nil
                window.makeFirstResponder(nil)
                self.applied = true
            }
        }

        func stop() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
            inputMonitor = nil
        }
    }
}

/// Owns one balanced cursor hide/unhide while the Stand By window is active.
struct StandbyCursorAutoHide: NSViewRepresentable {
    func makeNSView(context: Context) -> CursorView { CursorView() }
    func updateNSView(_ nsView: CursorView, context: Context) {}
    static func dismantleNSView(_ nsView: CursorView, coordinator: ()) { nsView.stop() }

    final class CursorView: NSView {
        private var timer: Timer?
        private var monitor: Any?
        private var observers: [NSObjectProtocol] = []
        private var tracking: NSTrackingArea?
        private var ownsHiddenCursor = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(rect: .zero,
                options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited, .mouseMoved],
                owner: self, userInfo: nil)
            addTrackingArea(area)
            tracking = area
        }
        override func mouseEntered(with event: NSEvent) { restart() }
        override func mouseMoved(with event: NSEvent) { restart() }
        override func mouseExited(with event: NSEvent) { reveal() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard let window else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged,
                .rightMouseDragged, .otherMouseDragged, .leftMouseDown, .rightMouseDown,
                .otherMouseDown, .leftMouseUp, .rightMouseUp, .otherMouseUp,
                .scrollWheel, .keyDown]) { [weak self] event in
                    if event.window === self?.window { self?.restart() }
                    else { self?.reveal() }
                    return event
                }
            let center = NotificationCenter.default
            for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification,
                         NSWindow.didMiniaturizeNotification] {
                observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.reveal()
                })
            }
            observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification,
                object: window, queue: .main) { [weak self] _ in self?.restart() })
            observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification,
                object: nil, queue: .main) { [weak self] _ in self?.reveal() })
            restart()
        }

        private var canHide: Bool {
            guard let window, NSApp.isActive, window.isKeyWindow, window.isVisible,
                  window.attachedSheet == nil, NSApp.modalWindow == nil,
                  NSEvent.pressedMouseButtons == 0 else { return false }
            return bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
        }

        private func restart() {
            reveal()
            guard canHide else { return }
            let timer = Timer(timeInterval: 2, repeats: false) { [weak self] _ in
                guard let self, self.canHide, !self.ownsHiddenCursor else { return }
                NSCursor.hide()
                self.ownsHiddenCursor = true
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        private func reveal() {
            timer?.invalidate()
            timer = nil
            if ownsHiddenCursor {
                NSCursor.unhide()
                ownsHiddenCursor = false
            }
        }

        func stop() {
            reveal()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
        }
    }
}

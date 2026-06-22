//  QuickSearchPalette.swift
//  ⌃Space floating library search. Type to filter, ↑/↓ to move, Return to play.

import SwiftUI
import Combine
import AppKit

// MARK: - Hotkey manager

@MainActor
final class QuickSearchHotkey: ObservableObject {
    static let shared = QuickSearchHotkey()

    /// Toggled when ⌃Space is pressed; the palette window observes this.
    @Published var toggleRequested = 0

    private var localMonitor: Any?
    private var globalMonitor: Any?

    private init() {}

    /// Local monitor: fires when Valentine is frontmost (no permission needed).
    func enableLocal() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isControlSpace(event) {
                self?.toggleRequested += 1
                return nil   // swallow the event
            }
            return event
        }
    }

    /// Global monitor: fires app-wide (requires Accessibility permission).
    func enableGlobal() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isControlSpace(event) {
                Task { @MainActor in
                    NSApp.activate(ignoringOtherApps: true)
                    self?.toggleRequested += 1
                }
            }
        }
    }

    func disable() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }

    private static func isControlSpace(_ event: NSEvent) -> Bool {
        // keyCode 49 == Space. Require Control, exclude Command/Option.
        event.keyCode == 49
            && event.modifierFlags.contains(.control)
            && !event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.option)
    }
}

// MARK: - Palette view

struct QuickSearchPalette: View {
    @ObservedObject var engine: AudioEngine
    let onClose: () -> Void

    @State private var query = ""
    @State private var results: [Int] = []          // library indices
    @State private var selection = 0
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16)).foregroundColor(.secondary)
                TextField("Search your library…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($fieldFocused)
                    .onSubmit { playSelected() }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)

            if !results.isEmpty {
                Divider().opacity(0.2)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element) { pos, index in
                                if engine.queue.indices.contains(index) {
                                    row(track: engine.queue[index], selected: pos == selection)
                                        .id(pos)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selection = pos; playSelected() }
                                }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: selection) { _, new in
                        withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(new, anchor: .center) }
                    }
                }
            } else if !query.isEmpty {
                Divider().opacity(0.2)
                Text("No matches")
                    .font(.system(size: 13)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
        .frame(width: 560)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
        .padding(24)   // room for the shadow inside the borderless panel
        .onAppear {
            recompute()
            // Defer focus until the panel is key, so the field accepts input.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { fieldFocused = true }
        }
        .onChange(of: query) { _, _ in recompute() }
        // Native key handling — no AppKit responder that fights the TextField.
        .onKeyPress(.upArrow)   { move(-1); return .handled }
        .onKeyPress(.downArrow) { move(1);  return .handled }
        .onKeyPress(.escape)    { onClose(); return .handled }
        .onKeyPress(.return)    { playSelected(); return .handled }
    }

    private func row(track: Track, selected: Bool) -> some View {
        HStack(spacing: 12) {
            AlbumArtView(image: track.albumArt, size: 36, corner: 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                Text("\(track.artist)\(track.album.map { " — \($0)" } ?? "")")
                    .font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Text(track.duration.asClock)
                .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor.opacity(0.18) : .clear))
    }

    // MARK: Logic

    private func recompute() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; selection = 0; return }
        results = engine.queue.indices.filter { i in
            let t = engine.queue[i]
            return t.title.localizedCaseInsensitiveContains(q)
                || t.artist.localizedCaseInsensitiveContains(q)
                || (t.album ?? "").localizedCaseInsensitiveContains(q)
                || (t.albumArtist ?? "").localizedCaseInsensitiveContains(q)
                || (t.genre ?? "").localizedCaseInsensitiveContains(q)
        }
        // Title-match-first ordering, then alphabetical.
        results.sort { a, b in
            let ta = engine.queue[a], tb = engine.queue[b]
            let aTitle = ta.title.localizedCaseInsensitiveContains(q)
            let bTitle = tb.title.localizedCaseInsensitiveContains(q)
            if aTitle != bTitle { return aTitle }
            return ta.title.localizedCaseInsensitiveCompare(tb.title) == .orderedAscending
        }
        selection = 0
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = max(0, min(results.count - 1, selection + delta))
    }

    private func playSelected() {
        guard results.indices.contains(selection) else { return }
        let ordered = Array(results[selection...])
        engine.playNow(indices: ordered)
        onClose()
    }
}

// MARK: - Floating panel host

/// Borderless panels can't become key by default, which blocks text input.
/// This subclass opts in so the search field can receive keystrokes.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class QuickSearchWindowController {
    private var panel: NSPanel?
    private let engine: AudioEngine

    init(engine: AudioEngine) { self.engine = engine }

    func toggle() {
        if let panel, panel.isVisible { close(); return }
        show()
    }

    func show() {
        let content = QuickSearchPalette(engine: engine) { [weak self] in self?.close() }
        let hosting = NSHostingController(rootView: content)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 140),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false          // the SwiftUI card draws its own shadow
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.contentViewController = hosting
        // Size the panel to fit the SwiftUI content so the rounded card fills it.
        panel.setContentSize(hosting.view.fittingSize)

        // Position a bit above center, Spotlight-style.
        if let frame = (panel.screen ?? NSScreen.main)?.visibleFrame {
            let size = panel.frame.size
            let x = frame.midX - size.width / 2
            let y = frame.midY + frame.height * 0.12
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }

        // Activate the app and make the panel key so the field gets focus.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

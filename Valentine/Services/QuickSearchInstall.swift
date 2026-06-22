//  QuickSearchInstall.swift
//  Attach .installQuickSearch(engine:) to RootView to wire the ⌃Space palette.

import SwiftUI

extension View {
    /// Install the ⌃Space in-app search palette. Call once, on RootView.
    func installQuickSearch(engine: AudioEngine) -> some View {
        modifier(QuickSearchInstaller(engine: engine))
    }
}

private struct QuickSearchInstaller: ViewModifier {
    let engine: AudioEngine
    @ObservedObject private var hotkey = QuickSearchHotkey.shared
    @State private var controller: QuickSearchWindowController?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if controller == nil { controller = QuickSearchWindowController(engine: engine) }
                hotkey.enableLocal()
                // To allow ⌃Space while Valentine is in the background (needs
                // Accessibility permission), also call: hotkey.enableGlobal()
            }
            .onChange(of: hotkey.toggleRequested) { _, _ in
                controller?.toggle()
            }
    }
}

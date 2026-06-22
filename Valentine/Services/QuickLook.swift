//  QuickLook.swift
//  Native Quick Look previews for audio files.

import SwiftUI
import Combine
import QuickLookUI

// MARK: - Controller

final class QuickLookController: NSObject, ObservableObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    @Published private(set) var urls: [URL] = []
    private var startIndex = 0

    /// Show the Quick Look panel for the given file URLs.
    func preview(_ urls: [URL], startingAt index: Int = 0) {
        self.urls = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        self.startIndex = min(index, max(0, self.urls.count - 1))
        guard !self.urls.isEmpty else { return }
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        if QLPreviewPanel.sharedPreviewPanelExists() && panel.isVisible {
            panel.reloadData()
            panel.currentPreviewItemIndex = startIndex
        } else {
            panel.makeKeyAndOrderFront(nil)
            panel.currentPreviewItemIndex = startIndex
        }
    }

    func toggle(_ urls: [URL], startingAt index: Int = 0) {
        if let panel = QLPreviewPanel.shared(),
           QLPreviewPanel.sharedPreviewPanelExists(), panel.isVisible {
            panel.orderOut(nil)
        } else {
            preview(urls, startingAt: index)
        }
    }

    // MARK: QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel) -> Int { urls.count }

    func previewPanel(_ panel: QLPreviewPanel, previewItemAt index: Int) -> QLPreviewItem {
        urls[index] as NSURL
    }
}

// MARK: - Host (keeps the panel responder chain happy in SwiftUI)

struct QuickLookHost: NSViewControllerRepresentable {
    let controller: QuickLookController

    func makeNSViewController(context: Context) -> QLHostController {
        let vc = QLHostController()
        vc.controller = controller
        return vc
    }

    func updateNSViewController(_ nsViewController: QLHostController, context: Context) {
        nsViewController.controller = controller
    }
}

/// View controller that accepts the Quick Look panel control messages so the
/// panel can take over the responder chain when shown from SwiftUI.
final class QLHostController: NSViewController {
    var controller: QuickLookController?

    override func loadView() { view = NSView() }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel) {
        panel.dataSource = controller
        panel.delegate = controller
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel) {
        panel.dataSource = nil
        panel.delegate = nil
    }
}

// MARK: - Convenience modifier

extension View {
    /// Present a Quick Look preview when `isPresented` becomes true.
    func quickLookPreview(isPresented: Binding<Bool>, urls: [URL]) -> some View {
        modifier(QuickLookModifier(isPresented: isPresented, urls: urls))
    }
}

private struct QuickLookModifier: ViewModifier {
    @Binding var isPresented: Bool
    let urls: [URL]
    @StateObject private var controller = QuickLookController()

    func body(content: Content) -> some View {
        content
            .background(QuickLookHost(controller: controller))
            .onChange(of: isPresented) { _, show in
                if show {
                    controller.preview(urls)
                    // Reset the flag; the panel manages its own lifecycle.
                    DispatchQueue.main.async { isPresented = false }
                }
            }
    }
}

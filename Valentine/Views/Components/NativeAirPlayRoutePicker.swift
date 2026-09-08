import AVKit
import SwiftUI

/// SwiftUI bridge for AppKit's native playback-route menu. AVRoutePickerView
/// owns the interaction and presentation, so the user receives the same
/// AirPlay destinations menu used by system media applications.
struct NativeAirPlayRoutePicker: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        routePicker.player = player
        routePicker.isRoutePickerButtonBordered = false

        let normalColor = NSColor.white.withAlphaComponent(0.90)
        let highlightedColor = NSColor.white
        routePicker.setRoutePickerButtonColor(normalColor, for: .normal)
        routePicker.setRoutePickerButtonColor(highlightedColor, for: .normalHighlighted)
        routePicker.setRoutePickerButtonColor(highlightedColor, for: .active)
        routePicker.setRoutePickerButtonColor(highlightedColor, for: .activeHighlighted)
        return routePicker
    }

    func updateNSView(_ routePicker: AVRoutePickerView, context: Context) {
        if routePicker.player !== player {
            routePicker.player = player
        }
    }
}

import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .glassEffect(.regular)
            )
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 16
    var isActive: Bool = false
    
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .glassEffect((configuration.isPressed || isHovered || isActive) ? .regular.interactive() : .regular)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(isActive ? 0.25 : 0))
                    .blendMode(.overlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isActive ? 0.5 : (isHovered ? 0.3 : 0.1)), lineWidth: isActive ? 1.5 : 1)
                    .blendMode(.overlay)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : (isHovered ? 1.08 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}




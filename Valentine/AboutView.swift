import SwiftUI
import AppKit
import Combine

struct AboutView: View {
    @State private var versionCopied = false
    @State private var creditsOffset: CGFloat = 150
    @State private var contentHeight: CGFloat = 0
    
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var appIcon: NSImage {
        NSApplication.shared.applicationIconImage ?? NSImage()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack {
                    Spacer()
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 128, height: 128)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    
                    Text("Valentine")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.top, 8)
                    
                    HStack(spacing: 4) {
                        Text("Version \(appVersion) - \(buildNumber)")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.primary.opacity(0.7))
                        
                        Button(action: copyVersion) {
                            Image(systemName: versionCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(versionCopied ? .green : .primary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Copy version")
                    }
                    .padding(.top, 4)
                    Spacer()
                }
                .frame(width: 300)
                
                Divider()
                    .padding(.vertical, 30)
                
                GeometryReader { geo in
                    VStack(alignment: .leading, spacing: 20) {
                        CreditSection(title: "ENGINEERING AND DESIGN", items: ["Jesús David Chapman Vélez"])
                        
                        CreditSection(title: "SPECIAL THANKS", items: [
                            "The Amberol Team",
                            "Mutagen",
                            "LRCLIB"
                        ])
                        
                        CreditSection(title: "LICENSE", items: [
                            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                            "",
                            "Copyright © 2026 JesusChapman",
                            "This program is open source ❤️"
                        ])
                    }
                    .padding(.horizontal, 30)
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear.onAppear {
                                contentHeight = contentGeo.size.height
                            }
                        }
                    )
                    .offset(y: creditsOffset)
                    .overlay(
                        ScrollCatcherView(offset: $creditsOffset)
                    )
                    .onReceive(timer) { _ in
                        if creditsOffset < -contentHeight {
                            creditsOffset = geo.size.height
                        } else {
                            creditsOffset -= 0.5
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.15),
                            .init(color: .black, location: 0.85),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 350)
                .clipped()
            }
            .frame(height: 350)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Support this project")
                        .font(.headline)
                    Text("☕️❤️")
                }
                
                HStack(alignment: .bottom) {
                    Text("This project is and always will be open source, free, and ad-free. You can support the development by making a donation to maintain it over time!.")
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 20)
                    
                    HStack(spacing: 12) {
                        Button("Learn more...") {
                            if let url = URL(string: "https://github.com/JesusChapman/valentine") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: {
                            if let url = URL(string: "https://liberapay.com/JesusChapman/donate") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("lp")
                                    .font(.system(size: 12, weight: .bold, design: .serif))
                                    .foregroundColor(.black)
                                Text("Donate")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#F6C915"))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(12)
            .padding(20)
        }
        .frame(width: 650, height: 480)
        .background(WindowAccessor())
        .background(Material.ultraThin)
    }
    
    private func copyVersion() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("Valentine Version \(appVersion) - \(buildNumber)", forType: .string)
        
        withAnimation {
            versionCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                versionCopied = false
            }
        }
    }
}

struct CreditSection: View {
    let title: LocalizedStringKey
    let items: [LocalizedStringKey]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary.opacity(0.6))
                .tracking(1)
            
            ForEach(0..<items.count, id: \.self) { index in
                Text(items[index])
                    .font(.system(size: 13))
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ScrollCatcherView: NSViewRepresentable {
    @Binding var offset: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = ScrollCatchNSView()
        view.onScroll = { deltaY in
            DispatchQueue.main.async {
                offset += deltaY
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class ScrollCatchNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    
    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaY)
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

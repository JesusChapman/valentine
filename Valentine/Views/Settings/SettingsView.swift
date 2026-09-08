import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case lyrics = "Lyrics"
    case integrations = "Integrations"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .lyrics: return "textformat.alt"
        case .integrations: return "network"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .gray
        case .lyrics: return .blue
        case .integrations: return .red
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab? = .general
    @AppStorage("appTheme") private var appTheme = 0
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            Text(LocalizedStringKey(tab.rawValue))
                        } icon: {
                            Image(systemName: tab.icon)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(tab.color, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .listStyle(.sidebar)
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsView()
                    .navigationTitle(LocalizedStringKey(SettingsTab.general.rawValue))
            case .lyrics:
                LyricsAppearanceView()
                    .navigationTitle(LocalizedStringKey(SettingsTab.lyrics.rawValue))
            case .integrations:
                IntegrationsSettingsView()
                    .navigationTitle(LocalizedStringKey(SettingsTab.integrations.rawValue))
            case .none:
                Text("Select a setting")
            }
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 400, idealHeight: 500)
        .background(WindowButtonsHider())
        .background(InitialWindowFocus())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
                .help("Close Settings")
            }
        }
    }
}


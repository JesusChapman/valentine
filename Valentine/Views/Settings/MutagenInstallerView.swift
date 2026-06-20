import SwiftUI

struct MutagenInstallerView: View {
    @StateObject private var installer = MutagenInstallerService()
    @Environment(\.dismiss) private var dismiss
    let onInstalled: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Mutagen Required")
                .font(.title2.bold())
                .padding(.top)
            
            Text("To edit and save lyrics directly to your audio files, Valentine needs the 'mutagen' library. This is a one-time installation.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) {
                switch installer.state {
                case .idle:
                    Text("Ready to install.")
                        .foregroundColor(.secondary)
                case .checkingPython:
                    statusRow(text: "Verifying Python3 installation...", icon: "arrow.triangle.2.circlepath", color: .blue, isSpinning: true)
                case .pythonInstalled(let version):
                    statusRow(text: LocalizedStringKey(String(format: String(localized: "Python3 (%@) is installed"), version)), icon: "checkmark.circle.fill", color: .green)
                case .pythonMissing:
                    VStack(alignment: .leading, spacing: 8) {
                        statusRow(text: "Python3 is not installed. Aborting.", icon: "xmark.circle.fill", color: .red)
                        Text("Please install Python3 via Homebrew to continue:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Link("Download Python", destination: URL(string: "https://www.python.org/downloads/mac-osx/")!)
                            Text("or")
                            Link("Homebrew", destination: URL(string: "https://brew.sh/")!)
                        }
                        .font(.caption.bold())
                    }
                case .installingMutagen:
                    statusRow(text: "Installing mutagen library...", icon: "arrow.triangle.2.circlepath", color: .blue, isSpinning: true)
                case .installed(let version):
                    statusRow(text: LocalizedStringKey(String(format: String(localized: "Mutagen v%@ is installed."), version)), icon: "checkmark.circle.fill", color: .green)
                case .error(let message):
                    statusRow(text: LocalizedStringKey(message), icon: "exclamationmark.triangle.fill", color: .orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.black.opacity(0.1))
            .cornerRadius(12)
            
            // Progress Bar
            let showProgress: Bool = {
                switch installer.state {
                case .idle, .pythonMissing, .error, .installed:
                    return false
                default:
                    return true
                }
            }()
            
            if showProgress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * CGFloat(installer.progress), height: 8)
                            .animation(.linear, value: installer.progress)
                    }
                }
                .frame(height: 8)
            }
            
            Spacer()
            
            switch installer.state {
            case .installed:
                HStack(spacing: 16) {
                    HoverButton(title: "Reinstall", isPrimary: false) {
                        installer.startInstallation()
                    }
                    HoverButton(title: "Close", isPrimary: true) {
                        onInstalled()
                        dismiss()
                    }
                }
            case .checkingPython, .installingMutagen, .pythonInstalled, .pythonMissing:
                EmptyView()
            case .idle:
                HoverButton(title: "Install library", isPrimary: false) {
                    installer.startInstallation()
                }
            case .error:
                HoverButton(title: "Retry", isPrimary: false) {
                    installer.startInstallation()
                }
            }
        }
        .padding()
        .frame(width: 400, height: 400)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow).ignoresSafeArea())
        .task {
            await installer.checkInitialState()
        }
    }
    
    @ViewBuilder
    private func statusRow(text: LocalizedStringKey, icon: String, color: Color, isSpinning: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .symbolEffect(.pulse, options: .repeating, isActive: isSpinning)
            Text(text)
                .font(.body)
        }
    }
    
    // Fallback for raw String interpolation binding
    @ViewBuilder
    private func statusRow(text: String, icon: String, color: Color, isSpinning: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .symbolEffect(.pulse, options: .repeating, isActive: isSpinning)
            Text(text)
                .font(.body)
        }
    }
}

struct HoverButton: View {
    let title: LocalizedStringKey
    let isPrimary: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isPrimary ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isPrimary ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2))
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

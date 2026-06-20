import Foundation
import Combine

enum InstallerState: Equatable {
    case idle
    case checkingPython
    case pythonInstalled(version: String)
    case pythonMissing
    case installingMutagen
    case installed(mutagenVersion: String)
    case error(String)
}

@MainActor
class MutagenInstallerService: ObservableObject {
    @Published var state: InstallerState = .idle
    @Published var progress: Double = 0.0
    
    // Directory where the package will be installed
    static var mutagenTargetDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Valentine", isDirectory: true)
        return appDir.appendingPathComponent("python_libs", isDirectory: true)
    }
    
    // Path to add to sys.path in Python
    static var mutagenLibraryPath: String {
        return mutagenTargetDirectory.path
    }
    
    var isMutagenInstalled: Bool {
        let path = MutagenInstallerService.mutagenTargetDirectory.appendingPathComponent("mutagen").path
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
    
    func checkInitialState() async {
        if isMutagenInstalled {
            let version = await checkMutagenVersion() ?? "unknown"
            self.state = .installed(mutagenVersion: version)
            self.progress = 1.0
        } else {
            self.state = .idle
        }
    }
    
    func startInstallation() {
        switch state {
        case .idle, .error:
            break
        case .installed:
            // This acts as a reinstall
            try? FileManager.default.removeItem(at: MutagenInstallerService.mutagenTargetDirectory)
            break
        default:
            return
        }
        
        Task {
            state = .checkingPython
            progress = 0.1
            
            // Checking Python
            guard let pythonVersion = await checkPython() else {
                state = .pythonMissing
                progress = 0.0
                return
            }
            
            state = .pythonInstalled(version: pythonVersion)
            progress = 0.3
            
            // Wait a bit to let the user read
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            state = .installingMutagen
            progress = 0.6
            
            let success = await installMutagen()
            if success {
                progress = 1.0
                let version = await checkMutagenVersion() ?? "unknown"
                state = .installed(mutagenVersion: version)
            } else {
                progress = 0.0
                state = .error(String(localized: "Error installing Mutagen. Please check your internet connection."))
            }
        }
    }
    
    private func checkMutagenVersion() async -> String? {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", "python3 -c 'import sys; sys.path.insert(0, \"\(MutagenInstallerService.mutagenLibraryPath)\"); import mutagen; print(mutagen.version_string)'"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0, let output = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func checkPython() async -> String? {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", "python3 --version"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0, let output = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func installMutagen() async -> Bool {
        return await withCheckedContinuation { continuation in
            let targetDir = MutagenInstallerService.mutagenTargetDirectory
            
            if !FileManager.default.fileExists(atPath: targetDir.path) {
                try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            let target = targetDir.path
            process.arguments = ["-lc", "python3 -m pip install mutagen --target \"\(target)\" --upgrade"]
            
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus == 0)
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}

//  ManageOrganizeViews.swift
//  Sheets + menu for organize, dedupe, and auto-tag.

import SwiftUI

// MARK: - Menu (drop into a toolbar or header)

struct ManageOrganizeMenu: View {
    @ObservedObject var engine: AudioEngine

    @State private var showOrganize = false
    @State private var showDuplicates = false
    @State private var showAutoTag = false

    var body: some View {
        Menu {
            Button {
                Task { await importFolders() }
            } label: { Label("Add Folder to Library…", systemImage: "folder.badge.plus") }

            Divider()

            Button { showAutoTag = true } label: {
                Label("Auto-tag Missing Metadata…", systemImage: "wand.and.stars")
            }
            Button { showOrganize = true } label: {
                Label("Organize Files…", systemImage: "folder.badge.gearshape")
            }
            Button { showDuplicates = true } label: {
                Label("Find Duplicates…", systemImage: "doc.on.doc")
            }

            Divider()

            Button {
                engine.pruneMissingTracks()
            } label: { Label("Remove Missing Files", systemImage: "trash.slash") }
        } label: {
            Image(systemName: "slider.horizontal.3").font(.system(size: 15))
        }
        .menuStyle(.borderlessButton)
        .help("Manage & Organize")
        .sheet(isPresented: $showOrganize) { OrganizePreviewView(engine: engine) }
        .sheet(isPresented: $showDuplicates) { DuplicatesReviewView(engine: engine) }
        .sheet(isPresented: $showAutoTag) { AutoTagView(engine: engine) }
    }

    private func importFolders() async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK else { return }
        await engine.importFromDisk(panel.urls)
    }
}

// MARK: - Organize preview

struct OrganizePreviewView: View {
    @ObservedObject var engine: AudioEngine
    @Environment(\.dismiss) private var dismiss

    @State private var destinationRoot: URL?
    @State private var patternChoice: PatternChoice = .standard
    @State private var copyInsteadOfMove = false
    @State private var overwrite = false
    @State private var plans: [OrganizePlan] = []
    @State private var running = false
    @State private var resultSummary: String?

    enum PatternChoice: String, CaseIterable, Identifiable {
        case standard = "Artist / Album / 01 - Title"
        case detailed = "Artist / Year - Album / 01 - Title"
        case byGenre  = "Genre / Artist / Album / 01 Title"
        case flat     = "Artist - Title"
        var id: String { rawValue }
        var pattern: NamingPattern {
            switch self {
            case .standard: return .standard
            case .detailed: return .detailed
            case .byGenre:  return .byGenre
            case .flat:     return .flat
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader("Organize Files", dismiss: dismiss)
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Destination").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    Spacer()
                    Button(destinationRoot == nil ? "Choose Folder…" : "Change…") { chooseDestination() }
                        .controlSize(.small)
                }
                if let dest = destinationRoot {
                    Text(dest.path).font(.system(size: 11)).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }

                Picker("Pattern", selection: $patternChoice) {
                    ForEach(PatternChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: patternChoice) { _, _ in rebuildPlans() }

                Toggle("Copy instead of move (keep originals)", isOn: $copyInsteadOfMove)
                    .controlSize(.small)
                Toggle("Overwrite existing files at destination", isOn: $overwrite)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            if plans.isEmpty {
                placeholder("Choose a destination to preview the plan.")
            } else {
                planList
            }

            Divider()
            footer
        }
        .frame(width: 620, height: 560)
    }

    private var planList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(plans) { plan in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.source.lastPathComponent)
                            .font(.system(size: 12, weight: .medium)).lineLimit(1)
                        if let reason = plan.skippedReason {
                            Label(reason, systemImage: "exclamationmark.triangle")
                                .font(.system(size: 10)).foregroundColor(.orange)
                        } else {
                            Text(relativeDest(plan.destination))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(plan.willOverwrite ? .orange : .secondary)
                                .lineLimit(1).truncationMode(.head)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 4)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var footer: some View {
        HStack {
            if let s = resultSummary {
                Text(s).font(.system(size: 11)).foregroundColor(.secondary)
            } else {
                Text(actionableCount == 0 ? "Nothing to organize" :
                        "\(actionableCount) file\(actionableCount == 1 ? "" : "s") will be \(copyInsteadOfMove ? "copied" : "moved")")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            Button("Close") { dismiss() }
            Button {
                apply()
            } label: {
                if running { ProgressView().controlSize(.small) }
                else { Text(copyInsteadOfMove ? "Copy Files" : "Move Files") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(running || actionableCount == 0 || destinationRoot == nil)
        }
        .padding()
    }

    private var actionableCount: Int { plans.filter { $0.skippedReason == nil }.count }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK { destinationRoot = panel.url; rebuildPlans() }
    }

    private func rebuildPlans() {
        guard let dest = destinationRoot else { plans = []; return }
        resultSummary = nil
        plans = engine.planOrganize(destinationRoot: dest,
                                    pattern: patternChoice.pattern,
                                    copy: copyInsteadOfMove)
    }

    private func apply() {
        guard let dest = destinationRoot else { return }
        running = true
        DispatchQueue.global(qos: .userInitiated).async {
            let results = engine.applyOrganize(plans, destinationRoot: dest,
                                               pattern: patternChoice.pattern,
                                               copy: copyInsteadOfMove,
                                               overwrite: overwrite)
            let ok = results.filter { $0.succeeded }.count
            let failed = results.count - ok
            DispatchQueue.main.async {
                running = false
                resultSummary = "\(ok) done" + (failed > 0 ? ", \(failed) skipped/failed" : "")
                rebuildPlans()
            }
        }
    }

    private func relativeDest(_ url: URL) -> String {
        guard let root = destinationRoot else { return url.path }
        return "→ " + url.path.replacingOccurrences(of: root.path + "/", with: "")
    }
}

// MARK: - Duplicates review

struct DuplicatesReviewView: View {
    @ObservedObject var engine: AudioEngine
    @Environment(\.dismiss) private var dismiss

    @State private var strategy: StrategyChoice = .smart
    @State private var keep: KeepChoice = .bestFormat
    @State private var groups: [DuplicateGroup] = []
    @State private var scanned = false
    @State private var running = false
    @State private var summary: String?

    enum StrategyChoice: String, CaseIterable, Identifiable {
        case smart = "Same song (tags + verify)"
        case tags  = "Same tags only"
        case bytes = "Byte-identical only"
        var id: String { rawValue }
        var strategy: DuplicateStrategy {
            switch self {
            case .smart: return .tagsThenBytes(durationToleranceSeconds: 2)
            case .tags:  return .tags(durationToleranceSeconds: 0)
            case .bytes: return .exactBytes
            }
        }
    }

    enum KeepChoice: String, CaseIterable, Identifiable {
        case bestFormat = "Best format"
        case largest    = "Largest file"
        case smallest   = "Smallest file"
        var id: String { rawValue }
        var rule: KeepRule {
            switch self {
            case .bestFormat: return .preferFormat(["flac", "alac", "m4a", "aac", "mp3", "ogg"])
            case .largest:    return .largestFile
            case .smallest:   return .smallestFile
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader("Find Duplicates", dismiss: dismiss)
            Divider()

            HStack(spacing: 12) {
                Picker("Match", selection: $strategy) {
                    ForEach(StrategyChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Keep", selection: $keep) {
                    ForEach(KeepChoice.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .padding()

            Divider()

            if !scanned {
                placeholder("Scan the library to find duplicates.")
            } else if groups.isEmpty {
                placeholder("No duplicates found. 🎉")
            } else {
                groupList
            }

            Divider()
            footer
        }
        .frame(width: 620, height: 560)
    }

    private var groupList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(groups) { group in
                    let keeper = DuplicateFinder().memberToKeep(in: group, rule: keep.rule)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.reason.uppercased())
                            .font(.system(size: 9, weight: .semibold)).tracking(0.5)
                            .foregroundColor(.secondary)
                        ForEach(group.members, id: \.id) { t in
                            HStack(spacing: 6) {
                                Image(systemName: t.id == keeper?.id ? "checkmark.circle.fill" : "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(t.id == keeper?.id ? .green : .red)
                                Text("\(t.artist) — \(t.title)")
                                    .font(.system(size: 12)).lineLimit(1)
                                Spacer()
                                Text(t.url.pathExtension.uppercased())
                                    .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                    .padding(.horizontal, 10)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var footer: some View {
        HStack {
            if let summary {
                Text(summary).font(.system(size: 11)).foregroundColor(.secondary)
            } else if scanned {
                Text("\(removableCount) file\(removableCount == 1 ? "" : "s") will be moved to Trash")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            Button("Close") { dismiss() }
            Button("Scan") { scan() }.disabled(running)
            Button {
                remove()
            } label: {
                if running { ProgressView().controlSize(.small) }
                else { Text("Move Extras to Trash") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(running || removableCount == 0)
        }
        .padding()
    }

    private var removableCount: Int {
        let f = DuplicateFinder()
        return groups.reduce(0) { $0 + f.membersToRemove(in: $1, rule: keep.rule).count }
    }

    private func scan() {
        running = true
        summary = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let found = engine.findDuplicates(strategy: strategy.strategy)
            DispatchQueue.main.async { groups = found; scanned = true; running = false }
        }
    }

    private func remove() {
        running = true
        DispatchQueue.global(qos: .userInitiated).async {
            let count = engine.removeDuplicates(groups, keeping: keep.rule)
            DispatchQueue.main.async {
                running = false
                summary = "Moved \(count) file\(count == 1 ? "" : "s") to Trash"
                groups = []
            }
        }
    }
}

// MARK: - Auto-tag

struct AutoTagView: View {
    @ObservedObject var engine: AudioEngine
    @Environment(\.dismiss) private var dismiss

    @AppStorage("musicbrainzContact") private var contact = ""
    @State private var includeArtwork = true
    @State private var running = false
    @State private var summary: String?
    @State private var mutagenMissing = false

    private var missingCount: Int {
        engine.queue.filter {
            $0.artist == "Unknown Artist" || $0.artist.isEmpty || ($0.album ?? "").isEmpty
                || (includeArtwork && $0.nsImage == nil)
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader("Auto-tag Missing Metadata", dismiss: dismiss)
            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("Looks up missing title/artist/album/year and cover art from MusicBrainz and the Cover Art Archive.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("CONTACT EMAIL (required by MusicBrainz)")
                        .font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundColor(.secondary)
                    TextField("you@example.com", text: $contact).textFieldStyle(.roundedBorder)
                }

                Toggle("Also fetch missing cover art", isOn: $includeArtwork).controlSize(.small)

                Text("\(missingCount) track\(missingCount == 1 ? "" : "s") need metadata.")
                    .font(.system(size: 11)).foregroundColor(.secondary)

                if mutagenMissing {
                    Text("Tag writing needs the metadata helper. Open the lyrics editor once to install it, then try again.")
                        .font(.caption).foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if includeArtwork {
                    Text("Fetched cover art is embedded into the files via the metadata helper.")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()

            Spacer()
            Divider()

            HStack {
                if let summary { Text(summary).font(.system(size: 11)).foregroundColor(.secondary) }
                Spacer()
                Button("Close") { dismiss() }
                Button {
                    start()
                } label: {
                    if running { ProgressView().controlSize(.small) }
                    else { Text("Fetch & Tag") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(running || contact.isEmpty || missingCount == 0)
            }
            .padding()
        }
        .frame(width: 460, height: 420)
    }

    private func start() {
        // Gate on mutagen, same as MetadataEditorView.
        let path = MutagenInstallerService.mutagenTargetDirectory.appendingPathComponent("mutagen").path
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            mutagenMissing = true
            return
        }
        running = true
        summary = nil
        Task {
            let updated = await engine.autoTagMissing(contact: contact, includeArtwork: includeArtwork)
            await MainActor.run {
                running = false
                summary = "Updated \(updated) track\(updated == 1 ? "" : "s")"
            }
        }
    }
}

// MARK: - Shared bits

/// Sheet title bar with a close button. Pass the view's own dismiss action.
@ViewBuilder
func sheetHeader(_ title: String, dismiss: DismissAction) -> some View {
    HStack {
        Text(title).font(.system(size: 16, weight: .semibold))
        Spacer()
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
        }.buttonStyle(.plain)
    }
    .padding()
}

/// Centered placeholder message for empty states.
@ViewBuilder
func placeholder(_ text: String) -> some View {
    VStack { Spacer(); Text(text).font(.system(size: 13)).foregroundColor(.secondary); Spacer() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}

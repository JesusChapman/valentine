import SwiftUI
import Combine

// MARK: - Focus filter model (Roon-style faceted filtering)

enum FocusFacet: Hashable {
    case genre(String)
    case decade(Int)        // e.g. 1980 means 1980–1989
    case artist(String)

    var label: String {
        switch self {
        case .genre(let g):  return g
        case .decade(let d): return "\(d)s"
        case .artist(let a): return a
        }
    }
}

/// Holds the active facets and applies them to a set of library indices.
final class FocusModel: ObservableObject {
    @Published var active: Set<FocusFacet> = []

    func toggle(_ f: FocusFacet) {
        if active.contains(f) { active.remove(f) } else { active.insert(f) }
    }

    func clear() { active.removeAll() }

    /// Filter library indices so each track matches ALL active facet *types*,
    /// where within a type (e.g. multiple genres) ANY match qualifies — the
    /// standard faceted-search behavior.
    func apply(_ indices: [Int], in queue: [Track]) -> [Int] {
        guard !active.isEmpty else { return indices }

        let genres  = active.compactMap { if case .genre(let g) = $0 { return g } else { return nil } }
        let decades = active.compactMap { if case .decade(let d) = $0 { return d } else { return nil } }
        let artists = active.compactMap { if case .artist(let a) = $0 { return a } else { return nil } }

        return indices.filter { i in
            let t = queue[i]
            let gOK = genres.isEmpty  || (t.genre.map { genres.contains($0) } ?? false)
            let dOK = decades.isEmpty || (t.year.map { decades.contains(($0 / 10) * 10) } ?? false)
            let aOK = artists.isEmpty || artists.contains(t.effectiveAlbumArtist)
            return gOK && dOK && aOK
        }
    }
}

// MARK: - Available facets, derived from the library

extension AudioEngine {
    var allGenres: [String] {
        let counts = Dictionary(grouping: queue.compactMap { $0.genre }, by: { $0 }).mapValues { $0.count }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value
                                                    : $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { $0.key }
    }

    var allDecades: [Int] {
        Set(queue.compactMap { $0.year }.map { ($0 / 10) * 10 }).sorted()
    }
}

// MARK: - The pill bar

struct FocusBar: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var focus: FocusModel
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button { withAnimation { expanded.toggle() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Focus").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(expanded ? .accentColor : .primary)
                }
                .buttonStyle(.plain)

                // Active pills (always shown, removable)
                ForEach(Array(focus.active), id: \.self) { facet in
                    Pill(text: facet.label, active: true) { focus.toggle(facet) }
                }

                if !focus.active.isEmpty {
                    Button("Clear") { focus.clear() }
                        .font(.system(size: 12)).buttonStyle(.plain)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if expanded {
                facetGroups
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var facetGroups: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !engine.allGenres.isEmpty {
                facetRow(title: "GENRES", facets: engine.allGenres.prefix(12).map { FocusFacet.genre($0) })
            }
            if !engine.allDecades.isEmpty {
                facetRow(title: "RELEASE DATE", facets: engine.allDecades.map { FocusFacet.decade($0) })
            }
            let artists = engine.artists.prefix(12).map { FocusFacet.artist($0.name) }
            if !artists.isEmpty {
                facetRow(title: "ARTISTS", facets: Array(artists))
            }
        }
        .padding(.top, 2)
    }

    private func facetRow(title: String, facets: [FocusFacet]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold)).tracking(0.6)
                .foregroundColor(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(facets, id: \.self) { f in
                    Pill(text: f.label, active: focus.active.contains(f)) { focus.toggle(f) }
                }
            }
        }
    }
}

private struct Pill: View {
    let text: String
    let active: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    Capsule().fill(active ? Color.accentColor.opacity(0.85)
                                          : Color.primary.opacity(0.08))
                )
                .foregroundColor(active ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple wrapping layout for pills

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

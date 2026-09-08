import SwiftUI

/// Full-screen listening experience inspired by Apple Music's immersive player.
/// The artwork and transport stay on the left while synchronized lyrics occupy
/// the visual center of the larger right-hand pane.
struct StandbyView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject private var settings = AppSettings.shared
    @Binding var isStandbyMode: Bool

    @AppStorage("isMiniPlayerMode") private var isMiniPlayerMode = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPane: StandbyPane = .lyrics

    private enum StandbyPane {
        case lyrics
        case queue
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 1_050 || proxy.size.height < 700
            let isPortrait = proxy.size.height > proxy.size.width
            let outerPadding = isCompact ? 30.0 : 72.0
            let topInset = isCompact ? 88.0 : 112.0
            let bottomInset = isCompact ? 64.0 : 82.0
            let contentWidth = max(proxy.size.width - outerPadding * 2, 320)
            let contentHeight = max(proxy.size.height - topInset - bottomInset, 320)
            let landscapeArtworkSide = min(
                min(proxy.size.width * 0.32, 440),
                max(contentHeight - (isCompact ? 185 : 210), 100)
            )
            let portraitArtworkSide = min(
                proxy.size.width * 0.48,
                max(contentHeight * 0.58 - 185, 100)
            )

            ZStack {
                background

                Group {
                    if isPortrait {
                        VStack(spacing: isCompact ? 24 : 44) {
                            nowPlayingColumn(compact: true, artworkSide: portraitArtworkSide)
                                .frame(
                                    width: min(contentWidth, 560),
                                    height: contentHeight * 0.58,
                                    alignment: .top
                                )

                            detailPane(compact: true)
                                .frame(
                                    width: contentWidth,
                                    height: max(contentHeight * 0.42 - (isCompact ? 24 : 44), 100)
                                )
                        }
                    } else {
                        HStack(spacing: isCompact ? 48 : min(proxy.size.width * 0.095, 140)) {
                            nowPlayingColumn(compact: isCompact, artworkSide: landscapeArtworkSide)
                                .frame(
                                    width: landscapeArtworkSide,
                                    height: contentHeight,
                                    alignment: .top
                                )

                            detailPane(compact: isCompact)
                                .frame(maxWidth: .infinity, maxHeight: contentHeight)
                        }
                    }
                }
                .frame(width: contentWidth, height: contentHeight)
                .position(
                    x: proxy.size.width / 2,
                    y: topInset + contentHeight / 2
                )

                topControls(compact: isCompact)
                    .padding(.horizontal, isCompact ? 26 : 46)
                    .padding(.top, isCompact ? 22 : 34)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                panePicker(compact: isCompact)
                    .padding(.trailing, isCompact ? 26 : 46)
                    .padding(.bottom, isCompact ? 22 : 34)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
        .background(StandbyCursorAutoHide())
        .onChange(of: engine.showLyrics) { _, showLyrics in
            selectedPane = showLyrics ? .lyrics : .queue
        }
        .onChange(of: selectedPane) { _, pane in
            engine.showLyrics = pane == .lyrics
        }
    }

    private var background: some View {
        AnimatedArtworkBackground(
            artwork: engine.currentTrack?.albumArt,
            artworkID: engine.currentTrack?.id,
            engine: engine
        )
    }

    private func nowPlayingColumn(compact: Bool, artworkSide: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: compact ? 16 : 22) {
            artwork(compact: compact, side: artworkSide)

            VStack(alignment: .leading, spacing: 5) {
                Group {
                    if let title = engine.currentTrack?.title {
                        Text(title)
                    } else {
                        Text("No Track Selected")
                    }
                }
                    .font(.system(size: compact ? 22 : 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    if let album = engine.currentTrack?.album, !album.isEmpty {
                        Text(album)
                            .lineLimit(1)

                        Text("•")
                    }

                    if let artist = engine.currentTrack?.artist {
                        Text(artist)
                            .lineLimit(1)
                    } else {
                        Text("Unknown Artist")
                            .lineLimit(1)
                    }
                }
                .font(.system(size: compact ? 14 : 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
            }

            StandbyProgressView(engine: engine, compact: compact)

            StandbyTransportControls(engine: engine, compact: compact)

        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func artwork(compact: Bool, side: CGFloat) -> some View {
        if settings.standbyAudioRing {
            StandbyAudioRingView(engine: engine)
                .frame(width: side, height: side)
        } else {
            albumArtwork(compact: compact, side: side)
        }
    }

    private func albumArtwork(compact: Bool, side: CGFloat) -> some View {
        let radius = compact ? 20.0 : 28.0

        return ZStack {
            if let artwork = engine.currentTrack?.albumArt {
                artwork
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)

                Image(systemName: "music.note")
                    .font(.system(size: compact ? 80 : 120, weight: .light))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 34, x: 0, y: 20)
        .animation(.easeInOut(duration: 0.7), value: engine.currentTrack?.id)
    }

    @ViewBuilder
    private func detailPane(compact: Bool) -> some View {
        switch selectedPane {
        case .lyrics:
            StandbyLyricsView(engine: engine, compact: compact)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        case .queue:
            StandbyQueueView(engine: engine, compact: compact)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private func topControls(compact: Bool) -> some View {
        HStack {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 0) {
                    floatingButton(
                        symbol: "xmark",
                        label: "Exit Stand By",
                        compact: compact
                    ) {
                        isStandbyMode = false
                    }

                    Divider()
                        .frame(height: compact ? 22 : 28)
                        .overlay(.white.opacity(0.25))

                    floatingButton(
                        symbol: "pip.enter",
                        label: "Switch to Mini-Player",
                        compact: compact
                    ) {
                        isStandbyMode = false
                        isMiniPlayerMode = true
                    }
                }
                .padding(.horizontal, 4)
                .glassEffect(.clear, in: Capsule())
            }

            Spacer()

            StandbyVolumeControl(engine: engine, compact: compact)
        }
    }

    private func floatingButton(
        symbol: String,
        label: LocalizedStringKey,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 15 : 18, weight: .semibold))
                .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.92))
        .focusEffectDisabled()
        .accessibilityLabel(label)
    }

    private func panePicker(compact: Bool) -> some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 2) {
                paneButton(.lyrics, symbol: "quote.bubble.fill", label: "Lyrics", compact: compact)
                paneButton(.queue, symbol: "list.bullet", label: "Playlist", compact: compact)
            }
            .padding(4)
            .glassEffect(.clear, in: Capsule())
        }
    }

    private func paneButton(
        _ pane: StandbyPane,
        symbol: String,
        label: LocalizedStringKey,
        compact: Bool
    ) -> some View {
        let isSelected = selectedPane == pane
        let activeTint = engine.activeControlTint(for: colorScheme)

        return Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                selectedPane = pane
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: compact ? 14 : 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: compact ? 36 : 44, height: compact ? 32 : 38)
                .background {
                    Capsule()
                        .fill(activeTint.opacity(isSelected ? 0.34 : 0))
                }
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(label)
    }
}

private struct StandbyProgressView: View {
    @ObservedObject var engine: AudioEngine
    let compact: Bool

    private var duration: TimeInterval {
        max(engine.duration, 1)
    }

    private var currentTime: TimeInterval {
        min(max(engine.currentTime, 0), duration)
    }

    var body: some View {
        VStack(spacing: compact ? 5 : 7) {
            Slider(
                value: Binding(
                    get: { currentTime },
                    set: { engine.seek(to: $0) }
                ),
                in: 0...duration
            )
            .tint(.white.opacity(0.92))
            .controlSize(.small)

            HStack {
                Text(engine.currentTime.formatTime())
                Spacer()
                Text("-\(max(0, engine.duration - engine.currentTime).formatTime())")
            }
            .font(.system(size: compact ? 10 : 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.48))
            .monospacedDigit()
        }
    }
}

private struct StandbyTransportControls: View {
    @ObservedObject var engine: AudioEngine
    let compact: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var activeTint: Color {
        engine.activeControlTint(for: colorScheme)
    }

    var body: some View {
        HStack {
            controlButton(
                symbol: "shuffle",
                size: compact ? 17 : 20,
                label: engine.shuffleMode ? "Shuffle On" : "Shuffle Off",
                isActive: engine.shuffleMode
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    engine.shuffleMode.toggle()
                }
            }

            Spacer()

            controlButton(symbol: "backward.fill", size: compact ? 26 : 31, label: "Previous Track") {
                engine.previousTrack()
            }

            Spacer()

            controlButton(
                symbol: engine.isPlaying ? "pause.fill" : "play.fill",
                size: compact ? 34 : 42,
                label: engine.isPlaying ? "Pause" : "Play"
            ) {
                engine.togglePlayback()
            }

            Spacer()

            controlButton(symbol: "forward.fill", size: compact ? 26 : 31, label: "Next Track") {
                engine.nextTrack()
            }

            Spacer()

            controlButton(
                symbol: engine.repeatMode == .one ? "repeat.1" : "repeat",
                size: compact ? 17 : 20,
                label: "Repeat \(engine.repeatMode == .off ? "Off" : (engine.repeatMode == .one ? "One" : "All"))",
                isActive: engine.repeatMode != .off
            ) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    switch engine.repeatMode {
                    case .off: engine.repeatMode = .one
                    case .one: engine.repeatMode = .all
                    case .all: engine.repeatMode = .off
                    }
                }
            }
        }
        .foregroundStyle(.white.opacity(0.94))
    }

    private func controlButton(
        symbol: String,
        size: CGFloat,
        label: LocalizedStringKey,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(isActive ? activeTint : .white.opacity(0.94))
                .frame(minWidth: 30, minHeight: 34)
                .contentTransition(.symbolEffect(.replace))
                .shadow(color: isActive ? activeTint.opacity(0.65) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(label)
    }
}

private struct StandbyVolumeControl: View {
    @ObservedObject var engine: AudioEngine
    let compact: Bool

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: compact ? 8 : 11) {
                NativeAirPlayRoutePicker(player: engine.routePickerPlayer)
                    .frame(
                        width: compact ? 24 : 28,
                        height: compact ? 24 : 28
                    )
                    .accessibilityLabel("AirPlay")

                Divider()
                    .frame(height: compact ? 20 : 24)
                    .overlay(.white.opacity(0.24))

                Image(systemName: "speaker.fill")
                    .font(.system(size: compact ? 10 : 12))

                Slider(value: $engine.volume, in: 0...1)
                    .tint(.white)
                    .controlSize(.mini)
                    .frame(width: compact ? 100 : 145)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: compact ? 13 : 16))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, compact ? 12 : 15)
            .frame(height: compact ? 40 : 48)
            .glassEffect(.clear, in: Capsule())
        }
    }
}

private struct StandbyLyricsView: View {
    @ObservedObject var engine: AudioEngine
    let compact: Bool

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var appearance = LyricsAppearanceManager.shared
    @ObservedObject private var settings = AppSettings.shared

    private var activeLineIndex: Int? {
        guard let lyrics = engine.currentTrack?.lyrics else { return nil }
        return lyrics.lastIndex { engine.currentTime >= $0.time }
    }

    private var neonColor: Color {
        if appearance.usesAlbumColorForNeon,
           let albumColor = engine.dominantArtworkColor(for: colorScheme) {
            return albumColor
        }
        return appearance.getNeonColor(isDark: colorScheme == .dark)
    }

    private var glowColor: Color {
        if appearance.usesAlbumColorForGlow,
           let albumColor = engine.dominantArtworkColor(for: colorScheme) {
            return albumColor
        }
        return appearance.getGlowColor(isDark: colorScheme == .dark)
    }

    var body: some View {
        Group {
            if let track = engine.currentTrack,
               let lyrics = track.lyrics,
               !lyrics.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: compact ? 30 : 46) {
                            ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                                lyricLine(line, at: index)
                                    .id(index)
                                    .onTapGesture {
                                        engine.seek(to: line.time)
                                    }
                            }
                        }
                        .padding(.vertical, compact ? 190 : 310)
                        .padding(.horizontal, compact ? 20 : 34)
                    }
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.12),
                                .init(color: .black, location: 0.88),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .onAppear {
                        scrollToCurrentLine(using: proxy, animated: false)
                    }
                    .onChange(of: activeLineIndex) { _, _ in
                        scrollToCurrentLine(using: proxy, animated: true)
                    }
                }
                .id(track.id)
            } else {
                if let title = engine.currentTrack?.title {
                    ContentUnavailableView(
                        "No Lyrics Available",
                        systemImage: "quote.bubble",
                        description: Text(title)
                    )
                    .foregroundStyle(.white.opacity(0.7))
                } else {
                    ContentUnavailableView(
                        "No Lyrics Available",
                        systemImage: "quote.bubble",
                        description: Text("No Track Selected")
                    )
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func lyricLine(_ line: LyricLine, at index: Int) -> some View {
        let activeIndex = activeLineIndex
        let distance = activeIndex.map { abs(index - $0) } ?? 2
        let isActive = index == activeIndex
        let transition = appearance.transitionStyle
        let fontSize: CGFloat = isActive
            ? (compact ? 38 : 54)
            : (compact ? 29 : 40)
        let inactiveBlur = min(CGFloat(max(distance - 1, 0)) * 2.2, 7)
        let verticalOffset: CGFloat = transition == .slide && !isActive
            ? (index < (activeIndex ?? 0) ? -18 : 18)
            : 0

        return Text(line.text.isEmpty ? "♪" : line.text)
            .font(.system(
                size: fontSize,
                weight: isActive ? .bold : .semibold,
                design: appearance.getFontDesign(isDark: colorScheme == .dark)
            ))
            .foregroundStyle(foregroundColor(isActive: isActive, distance: distance))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(isActive ? transition.activeScale : max(transition.inactiveScale, 0.92), anchor: .leading)
            .offset(y: verticalOffset)
            .blur(radius: isActive ? 0 : max(inactiveBlur, transition.inactiveBlur))
            .shadow(
                color: settings.isNeonEffectEnabled && isActive ? neonColor.opacity(0.82) : .clear,
                radius: 12
            )
            .shadow(
                color: settings.isGlowEffectEnabled && isActive ? glowColor.opacity(0.65) : .clear,
                radius: 24
            )
            .contentShape(Rectangle())
            .animation(transition.animation, value: activeLineIndex)
            .animation(transition.animation, value: appearance.lyricsTransitionStyle)
    }

    private func foregroundColor(isActive: Bool, distance: Int) -> Color {
        if isActive {
            if settings.isNeonEffectEnabled {
                return neonColor
            }
            return appearance.getFontColor(isDark: colorScheme == .dark, isActive: true)
        }

        let opacity = distance == 1 ? 0.45 : max(0.12, 0.31 - Double(distance) * 0.055)
        return .white.opacity(opacity)
    }

    private func scrollToCurrentLine(using proxy: ScrollViewProxy, animated: Bool) {
        guard let activeLineIndex else { return }

        if animated {
            withAnimation(appearance.transitionStyle.animation) {
                proxy.scrollTo(activeLineIndex, anchor: .center)
            }
        } else {
            proxy.scrollTo(activeLineIndex, anchor: .center)
        }
    }
}

private struct StandbyQueueView: View {
    @ObservedObject var engine: AudioEngine
    let compact: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: compact ? 10 : 14) {
                    ForEach(Array(engine.queue.enumerated()), id: \.element.id) { index, track in
                        let isCurrent = engine.currentTrackIndex == index

                        Button {
                            engine.playTrack(at: index)
                        } label: {
                            HStack(spacing: compact ? 13 : 18) {
                                ZStack {
                                    if let artwork = track.albumArt {
                                        artwork
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.white.opacity(0.08)
                                        Image(systemName: "music.note")
                                            .foregroundStyle(.white.opacity(0.45))
                                    }
                                }
                                .frame(width: compact ? 50 : 64, height: compact ? 50 : 64)
                                .clipShape(RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .font(.system(size: compact ? 16 : 20, weight: .semibold, design: .rounded))
                                        .lineLimit(1)

                                    Text(track.artist)
                                        .font(.system(size: compact ? 13 : 15, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isCurrent {
                                    Image(systemName: engine.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                        .foregroundStyle(.white.opacity(0.9))
                                        .contentTransition(.symbolEffect(.replace))
                                } else {
                                    Text(track.duration.formatTime())
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(compact ? 10 : 12)
                            .background {
                                RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                                    .fill(.white.opacity(isCurrent ? 0.14 : 0.035))
                            }
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .id(index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, compact ? 90 : 140)
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.09),
                        .init(color: .black, location: 0.91),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .onAppear {
                if let index = engine.currentTrackIndex {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
            .onChange(of: engine.currentTrackIndex) { _, index in
                guard let index else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }
}

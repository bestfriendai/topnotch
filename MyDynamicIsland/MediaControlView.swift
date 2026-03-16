import SwiftUI

/// Beautiful expanded media control UI for the notch
struct MediaControlView: View {
    @StateObject private var mediaController = MediaRemoteController.shared
    
    @State private var isHoveringPlayPause = false
    @State private var isHoveringPrevious = false
    @State private var isHoveringNext = false
    @State private var artworkScale: CGFloat = 1.0
    @State private var showVolumeSlider = false
    @State private var volumeLevel: CGFloat = 0.5
    @State private var artworkGlowPulse: Bool = false
    @State private var trackChangeFlash: Bool = false

    private var info: NowPlayingInfo { mediaController.nowPlayingInfo }
    private var accentColor: Color { Color(info.appColor) }

    var body: some View {
        ZStack {
            // Subtle gradient glow behind everything
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(0.06))
                .blur(radius: 20)

            // Brief accent flash on track change
            if trackChangeFlash {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                    .blur(radius: 12)
                    .transition(.opacity)
            }

            VStack(spacing: 8) {
                // Top row: artwork + track info
                HStack(spacing: 12) {
                    // Album artwork — fixed size
                    artworkView
                        .frame(width: 56, height: 56)

                    // Track info fills remaining width
                    trackInfoView
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Scrubber — full width
                ZStack(alignment: .leading) {
                    // Animated progress glow under scrubber
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(accentColor.opacity(0.25))
                            .frame(width: max(0, geo.size.width * info.progress), height: 6)
                            .blur(radius: 6)
                            .offset(y: 4)
                            .animation(.easeInOut(duration: 0.5), value: info.progress)
                    }
                    .frame(height: 3)

                    MediaScrubber(
                        progress: info.progress,
                        elapsedTime: info.elapsedTimeString,
                        remainingTime: info.remainingTimeString,
                        isPlaying: info.isPlaying,
                        accentColor: accentColor
                    ) { progress in
                        mediaController.seekToProgress(progress)
                    }
                }

                // Playback controls — centered row
                HStack {
                    Spacer()
                    controlsView
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .clipped()
        .onAppear {
            mediaController.refresh()
        }
        .onChange(of: info.title) { _, _ in
            // Flash accent color on track change
            withAnimation(.easeIn(duration: 0.1)) {
                trackChangeFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.5)) {
                    trackChangeFlash = false
                }
            }
        }
    }

    // MARK: - Artwork View
    
    private var artworkView: some View {
        ZStack {
            // Prominent accent-colored glow behind artwork — pulses when playing
            if let artwork = info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 54, height: 54)
                    .blur(radius: artworkGlowPulse ? 28 : 24)
                    .opacity(artworkGlowPulse ? 0.75 : 0.6)
                    .scaleEffect(artworkGlowPulse ? 1.38 : 1.3)

                // Extra accent color glow layer
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(artworkGlowPulse ? 0.35 : 0.25))
                    .frame(width: 54, height: 54)
                    .blur(radius: artworkGlowPulse ? 22 : 18)
                    .scaleEffect(artworkGlowPulse ? 1.3 : 1.2)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(artworkGlowPulse ? 0.45 : 0.35))
                    .frame(width: 54, height: 54)
                    .blur(radius: artworkGlowPulse ? 22 : 18)
            }

            // Main artwork
            Group {
                if let artwork = info.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Placeholder with app icon
                    ZStack {
                        LinearGradient(
                            colors: [accentColor.opacity(0.6), accentColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(systemName: info.appIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .scaleEffect(artworkScale)
            .animation(.spring(duration: 0.3), value: artworkScale)

            // Vinyl spin effect when playing
            if info.isPlaying && info.artwork != nil {
                VinylSpinOverlay()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(width: 56, height: 56)
        .clipped()
        .onHover { hovering in
            artworkScale = hovering ? 1.05 : 1.0
        }
        .onAppear {
            if info.isPlaying {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    artworkGlowPulse = true
                }
            }
        }
        .onChange(of: info.isPlaying) { _, playing in
            if playing {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    artworkGlowPulse = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    artworkGlowPulse = false
                }
            }
        }
    }
    
    // MARK: - Track Info View
    
    private var trackInfoView: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                // Title with smooth crossfade transition
                Text(info.title.isEmpty ? "Not Playing" : info.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.numericText())
                    .id(info.title)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .animation(.easeInOut(duration: 0.35), value: info.title)

                // Artist
                Text(info.artist.isEmpty ? "—" : info.artist)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // App indicator
            AppIndicator(appName: info.appName, appIcon: info.appIcon, color: accentColor)
        }
    }
    
    // MARK: - Controls View
    
    private var controlsView: some View {
        HStack(spacing: 6) {
            // Previous button
            MediaControlButton(
                icon: "backward.fill",
                size: 14,
                isHovering: isHoveringPrevious,
                accentColor: accentColor
            ) {
                mediaController.previousTrack()
            }
            .onHover { isHoveringPrevious = $0 }
            
            // Play/Pause button
            MediaControlButton(
                icon: info.isPlaying ? "pause.fill" : "play.fill",
                size: 18,
                isMain: true,
                isHovering: isHoveringPlayPause,
                accentColor: accentColor,
                isPlaying: info.isPlaying
            ) {
                mediaController.togglePlayPause()
            }
            .onHover { isHoveringPlayPause = $0 }
            
            // Next button
            MediaControlButton(
                icon: "forward.fill",
                size: 14,
                isHovering: isHoveringNext,
                accentColor: accentColor
            ) {
                mediaController.nextTrack()
            }
            .onHover { isHoveringNext = $0 }
        }
    }
}

// MARK: - Media Control Button

struct MediaControlButton: View {
    let icon: String
    let size: CGFloat
    var isMain: Bool = false
    let isHovering: Bool
    let accentColor: Color
    var isPlaying: Bool = false
    let action: () -> Void

    @State private var isPressed = false
    @State private var mainPulseShadow: CGFloat = 0.3

    var body: some View {
        Button(action: {
            withAnimation(.spring(duration: 0.12, bounce: 0.5)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(duration: 0.15, bounce: 0.3)) {
                    isPressed = false
                }
            }

            // Haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            action()
        }) {
            ZStack {
                if isMain {
                    // Pulsing outer glow when playing
                    if isPlaying {
                        Circle()
                            .fill(accentColor.opacity(mainPulseShadow * 0.3))
                            .frame(width: 42, height: 42)
                            .blur(radius: 6)
                    }

                    // Main button background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 34, height: 34)
                        .shadow(color: accentColor.opacity(isHovering ? 0.6 : 0.3), radius: isHovering ? 8 : 4, y: 2)
                } else {
                    // Hover glow for secondary buttons
                    if isHovering {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                            .blur(radius: 4)
                    }

                    // Secondary button background
                    Circle()
                        .fill(Color.white.opacity(isHovering ? 0.2 : 0.1))
                        .frame(width: 28, height: 28)
                        .shadow(color: accentColor.opacity(isHovering ? 0.25 : 0), radius: isHovering ? 6 : 0)
                }

                Image(systemName: icon)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(isMain ? .white : .white.opacity(isHovering ? 1.0 : 0.8))
            }
            .scaleEffect(isPressed ? 0.85 : (isHovering ? 1.1 : 1.0))
            .animation(.spring(duration: 0.2, bounce: 0.5), value: isHovering)
        }
        .buttonStyle(.plain)
        .onAppear {
            if isMain && isPlaying {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    mainPulseShadow = 0.7
                }
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if isMain {
                if playing {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        mainPulseShadow = 0.7
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        mainPulseShadow = 0.3
                    }
                }
            }
        }
    }
}

// MARK: - App Indicator

struct AppIndicator: View {
    let appName: String
    let appIcon: String
    let color: Color

    @State private var isHovering = false
    @State private var hoverScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Image(systemName: appIcon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)

            if isHovering {
                Text(appName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(color.opacity(0.9))
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.8)),
                        removal: .opacity
                    ))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
                )
        )
        .scaleEffect(hoverScale)
        .onHover { hovering in
            withAnimation(.spring(duration: 0.25, bounce: 0.5)) {
                isHovering = hovering
                hoverScale = hovering ? 1.08 : 1.0
            }
            // Brief bounce overshoot on hover start
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(duration: 0.2, bounce: 0.3)) {
                        hoverScale = 1.0
                    }
                }
            }
        }
    }
}

// MARK: - Vinyl Spin Overlay

struct VinylSpinOverlay: View {
    @State private var rotation: Double = 0
    @State private var counterRotation: Double = 0

    var body: some View {
        ZStack {
            // Primary ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.15),
                            .clear,
                            .white.opacity(0.08),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .rotationEffect(.degrees(rotation))

            // Counter-rotating inner ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.1),
                            .clear,
                            .white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
                .padding(4)
                .rotationEffect(.degrees(counterRotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                counterRotation = -360
            }
        }
    }
}

// MARK: - Compact Media View (for collapsed state)

struct CompactMediaIndicator: View {
    @StateObject private var mediaController = MediaRemoteController.shared
    
    private var info: NowPlayingInfo { mediaController.nowPlayingInfo }
    private var accentColor: Color { Color(info.appColor) }
    
    @State private var audioLevels: [CGFloat] = [0.3, 0.5, 0.7, 0.4, 0.6]
    @State private var animationTimer: Timer?
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accentColor)
                    .frame(width: 3, height: info.isPlaying ? 6 + audioLevels[i] * 10 : 4)
            }
        }
        .onAppear { if info.isPlaying { startAnimation() } }
        .onChange(of: info.isPlaying) { _, playing in
            if playing { startAnimation() } else { stopAnimation() }
        }
        .onDisappear { stopAnimation() }
    }
    
    private func startAnimation() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                audioLevels = audioLevels.map { _ in CGFloat.random(in: 0.2...1.0) }
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - Mini Artwork View (for left indicator)

struct MiniArtworkView: View {
    @StateObject private var mediaController = MediaRemoteController.shared
    
    private var info: NowPlayingInfo { mediaController.nowPlayingInfo }
    private var accentColor: Color { Color(info.appColor) }
    
    var body: some View {
        Group {
            if let artwork = info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    accentColor.opacity(0.3)
                    Image(systemName: info.appIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
}

// MARK: - Volume Slider

struct VolumeSlider: View {
    @Binding var volume: CGFloat
    let accentColor: Color
    
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    
                    Capsule()
                        .fill(accentColor)
                        .frame(width: geometry.size.width * volume)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 12 : 8, height: isDragging ? 12 : 8)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .offset(x: max(0, geometry.size.width * volume - (isDragging ? 6 : 4)))
                }
                .frame(height: 4)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            volume = max(0, min(1, value.location.x / geometry.size.width))
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 12)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Compact Transport Button (reusable for compact cards)

private enum CompactTransportStyle {
    case primary(Color)
    case secondary
}

private struct CompactTransportButton: View {
    let icon: String
    let iconSize: CGFloat
    let buttonSize: CGFloat
    let style: CompactTransportStyle
    let action: () -> Void

    @GestureState private var isPressed = false
    @State private var glowFlash: CGFloat = 0

    private var glowColor: Color {
        switch style {
        case .primary(let color): return color
        case .secondary: return .white
        }
    }

    var body: some View {
        Button {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

            // Trigger glow flash
            withAnimation(.easeOut(duration: 0.08)) {
                glowFlash = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.35)) {
                    glowFlash = 0
                }
            }

            action()
        } label: {
            ZStack {
                // Glow flash layer
                Circle()
                    .fill(glowColor.opacity(glowFlash * 0.4))
                    .frame(width: buttonSize + 8, height: buttonSize + 8)
                    .blur(radius: 6)

                switch style {
                case .primary(let color):
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: color.opacity(0.35), radius: 6, y: 2)

                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(.white)

                case .secondary:
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: buttonSize, height: buttonSize)

                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .scaleEffect(isPressed ? 0.85 : 1.0)
            .animation(.spring(duration: 0.15, bounce: 0.55), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
    }
}

// MARK: - Compact Now Playing Card (for 3-card deck layout)

struct CompactNowPlayingCard: View {
    @StateObject private var mediaController = MediaRemoteController.shared

    private var info: NowPlayingInfo { mediaController.nowPlayingInfo }
    private var hasMedia: Bool { !info.title.isEmpty }
    private var accentColor: Color { Color(info.appColor) }

    @State private var artworkAppeared = false
    @State private var playingDotOpacity: Double = 1.0
    @State private var emptyPulse: Bool = false
    @State private var emptyTextVisible: Bool = false
    @State private var emptyDashPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 10) {
            if hasMedia {
                mediaContent
            } else {
                emptyState
            }
        }
        .onAppear {
            mediaController.refresh()
        }
    }

    // MARK: - Media Content

    private var mediaContent: some View {
        VStack(spacing: 10) {
            // Top row: artwork + track info
            HStack(spacing: 10) {
                compactArtwork

                VStack(alignment: .leading, spacing: 3) {
                    // Song title — crossfade on track change
                    Text(info.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .id(info.title)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: info.title)

                    // Artist with colored playing dot
                    HStack(spacing: 4) {
                        if info.isPlaying {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 5, height: 5)
                                .transition(.scale.combined(with: .opacity))
                        }

                        Text(info.artist.isEmpty ? info.appName : info.artist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: 0)
            }

            // Transport controls
            compactTransportControls
        }
    }

    // MARK: - Compact Artwork (48x48 with 10pt corners and subtle glow)

    private var compactArtwork: some View {
        Group {
            if let artwork = info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [accentColor.opacity(0.7), accentColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: info.appIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .scaleEffect(artworkAppeared ? 1.0 : 0.85)
        .opacity(artworkAppeared ? 1.0 : 0.0)
        .id(info.title)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.85).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(duration: 0.35, bounce: 0.25), value: info.title)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                artworkAppeared = true
            }
        }
    }

    // MARK: - Transport Controls (centered, spec sizes)

    private var compactTransportControls: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            // Previous — 12pt icon, 26x26 circle, white/8% bg
            CompactTransportButton(
                icon: "backward.fill",
                iconSize: 12,
                buttonSize: 26,
                style: .secondary
            ) {
                mediaController.previousTrack()
            }

            // Play/Pause — 16pt icon, 32x32 circle, accent color + glow
            CompactTransportButton(
                icon: info.isPlaying ? "pause.fill" : "play.fill",
                iconSize: 16,
                buttonSize: 32,
                style: .primary(accentColor)
            ) {
                mediaController.togglePlayPause()
            }

            // Next — 12pt icon, 26x26 circle, white/8% bg
            CompactTransportButton(
                icon: "forward.fill",
                iconSize: 12,
                buttonSize: 26,
                style: .secondary
            ) {
                mediaController.nextTrack()
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(emptyPulse ? 0.35 : 0.15))
                .scaleEffect(emptyPulse ? 1.08 : 0.95)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: emptyPulse)

            Text("No media")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(emptyTextVisible ? 0.35 : 0.0))
                .animation(.easeIn(duration: 0.8), value: emptyTextVisible)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4], dashPhase: emptyDashPhase))
                .foregroundStyle(.white.opacity(0.1))
        )
        .onAppear {
            emptyPulse = true
            withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
                emptyTextVisible = true
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                emptyDashPhase = 40
            }
        }
    }
}

// MARK: - Compact YouTube Card (for 3-card deck layout)

struct CompactYouTubeCard: View {
    @Binding var urlInput: String
    @Binding var inputError: String?
    let onPlay: () -> Void
    let onPaste: (() -> Void)?
    let hasPasteURL: Bool

    /// Optional: pass the video window manager to show playing state
    var videoManager: VideoWindowManager?

    @GestureState private var isPlayPressed = false
    @GestureState private var isPastePressed = false
    @GestureState private var isShowPressed = false
    @State private var browseShimmerPhase: CGFloat = 0
    @State private var playButtonGlow: Bool = false

    private var hasValidURL: Bool {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("youtube.com") || trimmed.contains("youtu.be")
    }

    private var isVideoPlaying: Bool {
        videoManager?.isVisible == true
    }

    private var playerState: YouTubePlayerState? {
        videoManager?.playerState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isVideoPlaying, let state = playerState {
                playingContent(state: state)
            } else {
                inputContent
            }
        }
    }

    // MARK: - Input Content (empty state)

    private var inputContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with subtle red gradient glow
            ZStack {
                // Red gradient glow behind icon
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.red.opacity(0.3), .red.opacity(0.0)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)
                    .offset(x: -28)
                    .blur(radius: 6)

                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                    Text("YouTube")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                }
            }

            // URL input with premium inner border
            TextField("Paste URL...", text: $urlInput)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(white: 0.17))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .white.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .onSubmit { onPlay() }

            // Buttons
            HStack(spacing: 6) {
                // Play button with pulsing glow when valid URL
                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    onPlay()
                } label: {
                    ZStack {
                        if hasValidURL {
                            Capsule(style: .continuous)
                                .fill(.red.opacity(playButtonGlow ? 0.5 : 0.2))
                                .blur(radius: 8)
                                .frame(height: 28)
                                .padding(.horizontal, -4)
                        }

                        Label(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Browse" : "Play", systemImage: "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule(style: .continuous).fill(.red))
                            .overlay(
                                // Shimmer on "Browse" text when no URL
                                Group {
                                    if urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Capsule(style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.clear, .white.opacity(0.15), .clear],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .mask(Capsule(style: .continuous))
                                            .offset(x: browseShimmerPhase * 80 - 40)
                                    }
                                }
                            )
                            .clipShape(Capsule(style: .continuous))
                    }
                    .scaleEffect(isPlayPressed ? 0.88 : 1.0)
                    .animation(.spring(duration: 0.2, bounce: 0.4), value: isPlayPressed)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isPlayPressed) { _, state, _ in state = true }
                )

                if hasPasteURL {
                    Button {
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                        onPaste?()
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
                            .scaleEffect(isPastePressed ? 0.88 : 1.0)
                            .animation(.spring(duration: 0.2, bounce: 0.4), value: isPastePressed)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .updating($isPastePressed) { _, state, _ in state = true }
                    )
                }
            }

            if let error = inputError {
                Text(error)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
                browseShimmerPhase = 1.0
            }
        }
        .onChange(of: hasValidURL) { _, valid in
            if valid {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    playButtonGlow = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    playButtonGlow = false
                }
            }
        }
    }

    // MARK: - Playing Content

    private func playingContent(state: YouTubePlayerState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with red gradient glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.red.opacity(0.3), .red.opacity(0.0)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)
                    .offset(x: -28)
                    .blur(radius: 6)

                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                    Text("YouTube")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)

                    // Buffering indicator
                    if state.isBuffering {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }
                }
            }

            // Video title
            Text(state.videoTitle ?? "Playing video")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(state.isPlaying ? "Playing in window" : "Paused")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color.white.opacity(0.12))

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(.red)
                        .frame(width: max(0, geo.size.width * state.progress))
                }
            }
            .frame(height: 3)

            // Mini transport + show button
            HStack(spacing: 8) {
                // Play/Pause
                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    videoManager?.playerController.togglePlayPause()
                } label: {
                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)

                // Seek back
                Button {
                    videoManager?.playerController.seekRelative(seconds: -10)
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                // Seek forward
                Button {
                    videoManager?.playerController.seekRelative(seconds: 10)
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                // Show button
                Button {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    videoManager?.bringToFront()
                } label: {
                    Text("Show")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(.red.opacity(0.7)))
                        .scaleEffect(isShowPressed ? 0.88 : 1.0)
                        .animation(.spring(duration: 0.2, bounce: 0.4), value: isShowPressed)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isShowPressed) { _, state, _ in state = true }
                )
            }
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.08), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.4)
                    .offset(x: -geometry.size.width * 0.4 + phase * (geometry.size.width * 1.8))
                    .animation(
                        .easeInOut(duration: 2.5).repeatForever(autoreverses: false).delay(3),
                        value: phase
                    )
                }
                .mask(content)
            )
            .onAppear { phase = 1 }
    }
}

// MARK: - Preview

#Preview("Media Control View") {
    VStack {
        MediaControlView()
            .frame(width: 320)
            .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Compact Now Playing Card") {
    CompactNowPlayingCard()
        .frame(width: 170, height: 140)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.07), Color.white.opacity(0.025)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("Compact YouTube Card") {
    CompactYouTubeCard(
        urlInput: .constant(""),
        inputError: .constant(nil),
        onPlay: {},
        onPaste: nil,
        hasPasteURL: false
    )
    .frame(width: 170, height: 140)
    .padding(14)
    .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(LinearGradient(
                colors: [Color.white.opacity(0.07), Color.white.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Compact Indicator") {
    HStack(spacing: 20) {
        CompactMediaIndicator()
        MiniArtworkView()
    }
    .padding()
    .background(Color.black)
}

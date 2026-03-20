import Combine
import SwiftUI

/// Modifier that drives vinyl rotation only when active — avoids 30fps timer when idle
private struct VinylSpinModifier: ViewModifier {
    let isSpinning: Bool
    @Binding var rotation: Double

    func body(content: Content) -> some View {
        if isSpinning {
            content
                .onReceive(Timer.publish(every: 1.0/30, on: .main, in: .common).autoconnect()) { _ in
                    rotation += 360.0 / (8.0 * 30.0)
                }
        } else {
            content
        }
    }
}

/// Beautiful expanded media control UI for the notch
struct MediaControlView: View {
    @StateObject private var mediaController = MediaRemoteController.shared

    @State private var isHoveringPlayPause = false
    @State private var isHoveringPrevious = false
    @State private var isHoveringNext = false
    @State private var artworkScale: CGFloat = 1.0
    @State private var isHoveringChevron = false

    // Vinyl spin
    @AppStorage("vinylAnimation") private var vinylEnabled = false
    @State private var artworkRotation: Double = 0
    @State private var vinylSpinning = false

    @AppStorage("colorMatchApp") private var colorMatchApp = true
    @AppStorage("accentColorIndex") private var accentColorIndex = 0

    private static let accentPalette: [Color] = [
        Color(red: 0.039, green: 0.518, blue: 1.0),   // Blue
        Color(red: 1.0,   green: 0.624, blue: 0.039),  // Orange
        Color(red: 0.196, green: 0.835, blue: 0.514),  // Green
        Color(red: 0.91,  green: 0.353, blue: 0.31),   // Red
        Color(red: 0.749, green: 0.353, blue: 0.949),  // Purple
        Color(red: 0.024, green: 0.714, blue: 0.831),  // Cyan
    ]

    private var info: NowPlayingInfo { mediaController.nowPlayingInfo }
    private var accentColor: Color {
        if colorMatchApp {
            return Color(info.appColor)
        }
        let idx = max(0, min(accentColorIndex, Self.accentPalette.count - 1))
        return Self.accentPalette[idx]
    }

    var body: some View {
        if !info.hasMedia {
            // Empty state — per spec: 800pt wide, 220pt tall
            expandedEmptyState
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity
                ))
        } else {
            expandedMediaContent
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity
                ))
        }
    }

    // MARK: - Empty State (No Media Playing)

    @State private var emptyIconPulse = false
    @State private var emptyRingScale: CGFloat = 0.6
    @State private var emptyRingOpacity: Double = 0

    private var expandedEmptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            ZStack {
                // Pulsing outer ring
                Circle()
                    .stroke(NotchDesign.borderSubtle.opacity(0.5), lineWidth: 1)
                    .frame(width: 72, height: 72)
                    .scaleEffect(emptyRingScale)
                    .opacity(emptyRingOpacity)

                // Inner filled circle
                Circle()
                    .fill(NotchDesign.elevated)
                    .frame(width: 56, height: 56)

                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(NotchDesign.textTertiary)
                    .scaleEffect(emptyIconPulse ? 1.08 : 1.0)
            }
            .onAppear {
                // Set initial values first, then animate to targets
                emptyRingOpacity = 0.6
                emptyRingScale = 0.6
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    emptyIconPulse = true
                }
                withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(0.1)) {
                    emptyRingScale = 1.4
                    emptyRingOpacity = 0
                }
            }

            VStack(spacing: 4) {
                Text(NSLocalizedString("media.noMediaPlaying", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NotchDesign.textTertiary)

                Text(NSLocalizedString("media.playMusicPrompt", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchDesign.textMuted.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Quick-launch media apps
            HStack(spacing: 10) {
                MediaLaunchButton(label: NSLocalizedString("media.music", comment: ""), icon: "music.note", color: Color(red: 0.98, green: 0.27, blue: 0.37)) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
                }
                MediaLaunchButton(label: NSLocalizedString("media.podcasts", comment: ""), icon: "mic.fill", color: Color(red: 0.75, green: 0.35, blue: 0.95)) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Podcasts.app"))
                }
                MediaLaunchButton(label: NSLocalizedString("media.spotify", comment: ""), icon: "waveform", color: Color(red: 0.11, green: 0.73, blue: 0.33)) {
                    if let url = URL(string: "spotify:") { NSWorkspace.shared.open(url) }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity).frame(height: 180)
    }

    private struct MediaLaunchButton: View {
        let label: String
        let icon: String
        let color: Color
        let action: () -> Void
        @State private var isHovering = false

        var body: some View {
            Button(action: action) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(isHovering ? color : NotchDesign.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isHovering ? color.opacity(0.15) : NotchDesign.elevated)
                )
                .overlay(Capsule().strokeBorder(isHovering ? color.opacity(0.4) : NotchDesign.borderSubtle, lineWidth: 0.5))
                .scaleEffect(isHovering ? 1.04 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .animation(.spring(duration: 0.2, bounce: 0.3), value: isHovering)
        }
    }

    // MARK: - Media Content

    private var expandedMediaContent: some View {
        HStack(spacing: 16) {
            // Left: Album artwork 80x80 with colored glow
            artworkView
                .frame(width: 80, height: 80)

            // Center: Track info + scrubber
            VStack(alignment: .leading, spacing: 8) {
                // Track info
                trackInfoView

                // Full-width scrubber
                MediaScrubber(
                    progress: info.progress,
                    elapsedTime: info.elapsedTimeString,
                    remainingTime: info.remainingTimeString,
                    isPlaying: info.isPlaying,
                    accentColor: accentColor,
                    totalDuration: info.duration > 0 ? info.duration : nil
                ) { progress in
                    mediaController.seekToProgress(progress)
                }
            }
            .frame(maxWidth: .infinity)

            // Right: Playback controls
            controlsView

            // Far right: Chevron-up
            VStack(spacing: 12) {
                // Chevron-up icon
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isHoveringChevron ? NotchDesign.textPrimary : NotchDesign.textMuted)
                    .onHover { isHoveringChevron = $0 }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .clipped()
        .onAppear {
            mediaController.refresh()
            vinylSpinning = vinylEnabled && info.isPlaying
        }
        .onDisappear { vinylSpinning = false }
        .onChange(of: info.title) { _, _ in
            // Artwork bounce on track change
            withAnimation(.spring(duration: 0.2, bounce: 0.5)) { artworkScale = 0.90 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(duration: 0.45, bounce: 0.40)) { artworkScale = 1.0 }
            }
        }
        .onChange(of: info.isPlaying) { _, playing in
            if vinylEnabled {
                vinylSpinning = playing
            }
        }
    }

    // MARK: - Artwork View

    private var artworkView: some View {
        ZStack {
            // Colored glow (pulsing subtly)
            artworkImageContent
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .blur(radius: 22)
                .opacity(0.45)
                .scaleEffect(1.2)

            // Main artwork — circular when vinyl, rounded rect otherwise
            artworkImageContent
                .frame(width: 80, height: 80)
                .clipShape(
                    vinylEnabled
                        ? AnyShape(Circle())
                        : AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .shadow(color: accentColor.opacity(0.28), radius: 18, y: 5)
                .rotationEffect(.degrees(vinylEnabled && vinylSpinning ? artworkRotation : 0))
                .modifier(VinylSpinModifier(isSpinning: vinylEnabled && vinylSpinning, rotation: $artworkRotation))
                // Vinyl concentric rings overlay
                .overlay {
                    if vinylEnabled {
                        VinylRingsOverlay()
                    }
                }
                .scaleEffect(artworkScale)
                .animation(.notchSnap, value: artworkScale)
                // Track-change transition: crossfade + subtle scale
                .id(info.title)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.92)),
                    removal: .opacity.combined(with: .scale(scale: 1.04))
                ))
        }
        .frame(width: 80, height: 80)
        .onHover { hovering in
            withAnimation(.notchSnap) { artworkScale = hovering ? 1.04 : 1.0 }
        }
    }

    @ViewBuilder
    private var artworkImageContent: some View {
        if let artwork = info.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [accentColor.opacity(0.7), accentColor.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: info.appIcon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
    
    // MARK: - Track Info View

    @State private var sourceDotPulse = false

    private var trackInfoView: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Track title — slides + fades in when track changes
            Text(info.title.isEmpty ? NSLocalizedString("media.notPlaying", comment: "") : info.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NotchDesign.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .id(info.title)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
                .animation(.notchSnap, value: info.title)

            // Artist
            Text(info.artist.isEmpty ? NSLocalizedString("media.unknownArtist", comment: "") : info.artist)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(NotchDesign.textMuted)
                .lineLimit(1)
                .truncationMode(.tail)
                .id(info.artist)
                .transition(.opacity)
                .animation(.notchDefault, value: info.artist)

            // Live dot + app name
            HStack(spacing: 5) {
                Circle()
                    .fill(info.isPlaying ? NotchDesign.green : NotchDesign.textTertiary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(sourceDotPulse && info.isPlaying ? 1.35 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: sourceDotPulse)
                    .notchGlow(info.isPlaying ? NotchDesign.green : .clear, radius: 6)
                Text(info.appName.isEmpty ? NSLocalizedString("nav.media", comment: "") : info.appName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchDesign.textMuted)
            }
            .padding(.top, 2)
            .onAppear { sourceDotPulse = true }
        }
    }
    
    // MARK: - Controls View

    private var controlsView: some View {
        HStack(spacing: 10) {
            // Previous track
            Button(action: {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                mediaController.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isHoveringPrevious ? NotchDesign.textPrimary : NotchDesign.textMuted)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Color.white.opacity(isHoveringPrevious ? 0.10 : 0))
                    )
                    .animation(.notchSnap, value: isHoveringPrevious)
            }
            .buttonStyle(.notchPress(scale: 0.82, hover: 1.0))
            .onHover { isHoveringPrevious = $0 }

            // Play / Pause — white circle, dark icon, symbol crossfade
            Button(action: {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                mediaController.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(NotchDesign.textPrimary)
                        .frame(width: 40, height: 40)
                        .shadow(color: .white.opacity(isHoveringPlayPause ? 0.22 : 0.12), radius: 14, y: 3)

                    Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(NotchDesign.bgMain)
                        .contentTransition(.symbolEffect(.replace.offUp))
                        .offset(x: info.isPlaying ? 0 : 1.5)
                }
                .scaleEffect(isHoveringPlayPause ? 1.06 : 1.0)
                .animation(.notchSnap, value: isHoveringPlayPause)
            }
            .buttonStyle(.notchPress(scale: 0.88))
            .onHover { isHoveringPlayPause = $0 }

            // Next track
            Button(action: {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                mediaController.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isHoveringNext ? NotchDesign.textPrimary : NotchDesign.textMuted)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Color.white.opacity(isHoveringNext ? 0.10 : 0))
                    )
                    .animation(.notchSnap, value: isHoveringNext)
            }
            .buttonStyle(.notchPress(scale: 0.82, hover: 1.0))
            .onHover { isHoveringNext = $0 }
        }
    }
}

// MARK: - Vinyl Rings Overlay

private struct VinylRingsOverlay: View {
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .padding(6)

            // Middle ring
            Circle()
                .stroke(.black.opacity(0.40), lineWidth: 2)
                .padding(14)

            // Center hole
            Circle()
                .fill(.black.opacity(0.55))
                .frame(width: 14, height: 14)
        }
    }
}

// Helper to erase shape types for conditional clipping
private struct AnyShape: Shape, @unchecked Sendable {
    private let _path: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { _path = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { _path(rect) }
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

    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring()) {
                    isPressed = false
                }
            }
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            action()
        }) {
            ZStack {
                if isMain {
                    // Clean white circle play button
                    Circle()
                        .fill(Color.white)
                        .frame(width: 34, height: 34)
                        .shadow(color: Color.white.opacity(0.15), radius: 10, y: 2)
                } else {
                    // Secondary button — subtle background
                    Circle()
                        .fill(Color.white.opacity(isHovering ? 0.15 : 0.08))
                        .frame(width: 28, height: 28)
                }

                Image(systemName: icon)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(isMain ? NotchDesign.bgMain : (isHovering ? NotchDesign.textPrimary : NotchDesign.textMuted))
            }
            .scaleEffect(isPressed ? 0.85 : (isHovering ? 1.06 : 1.0))
            .animation(.spring(), value: isHovering)
        }
        .buttonStyle(.plain)
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
    @State private var isAnimating = false

    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accentColor)
                    .frame(width: 3, height: info.isPlaying ? 6 + audioLevels[i] * 10 : 4)
                    .shadow(color: accentColor.opacity(0.37), radius: 4)
            }
        }
        .onAppear { if info.isPlaying { isAnimating = true } }
        .onChange(of: info.isPlaying) { _, playing in
            isAnimating = playing
        }
        .onDisappear { isAnimating = false }
        .onReceive(timer) { _ in
            guard isAnimating else { return }
            withAnimation(.easeInOut(duration: 0.1)) {
                audioLevels = audioLevels.map { _ in CGFloat.random(in: 0.2...1.0) }
            }
        }
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
        // Spec: album art 22x22, cornerRadius 5
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
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
                case .primary:
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.114, green: 0.725, blue: 0.329),
                                    Color(red: 0.094, green: 0.639, blue: 0.290)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: Color(red: 0.114, green: 0.725, blue: 0.329).opacity(0.3), radius: 12, y: 2)

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
    @AppStorage("showAlbumArt") private var showAlbumArt = true
    @AppStorage("nowPlayingControls") private var showControls = true

    private var info: NowPlayingInfo { mediaController.nowPlayingInfo }
    private var hasMedia: Bool { !info.title.isEmpty }
    private var accentColor: Color { Color(info.appColor) }

    @State private var artworkAppeared = false
    @State private var artworkGlowPulse: Bool = false
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
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                artworkGlowPulse = true
            }
        }
    }

    // MARK: - Media Content

    private var mediaContent: some View {
        VStack(spacing: 8) {
            // Top row: artwork + track info
            HStack(spacing: 12) {
                if showAlbumArt { compactArtwork }

                VStack(alignment: .leading, spacing: 4) {
                    // App source badge
                    HStack(spacing: 4) {
                        Image(systemName: info.appIcon)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(accentColor)
                        Text(info.appName.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                            .tracking(0.5)
                            .lineLimit(1)
                    }

                    // Song title — crossfade on track change
                    Text(info.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .id(info.title)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: info.title)

                    // Artist
                    Text(info.artist.isEmpty ? NSLocalizedString("media.unknownArtist", comment: "") : info.artist)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                // Playing indicator — animated equalizer bars
                if info.isPlaying {
                    equalizerBars
                }
            }

            // Scrubber with time labels
            VStack(spacing: 3) {
                MediaScrubber(
                    progress: info.progress,
                    elapsedTime: info.elapsedTimeString,
                    remainingTime: info.remainingTimeString,
                    isPlaying: info.isPlaying,
                    accentColor: accentColor,
                    totalDuration: info.duration > 0 ? info.duration : nil
                ) { progress in
                    mediaController.seekToProgress(progress)
                }
            }

            // Transport controls
            if showControls { compactTransportControls }
        }
    }

    // MARK: - Compact Artwork (64x64 with glow)

    private var compactArtwork: some View {
        ZStack {
            // Blurred color glow behind artwork
            Group {
                if let artwork = info.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    accentColor
                }
            }
            .frame(width: 64, height: 64)
            .blur(radius: 16)
            .opacity(artworkGlowPulse ? 0.55 : 0.35)
            .scaleEffect(1.4)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: artworkGlowPulse)

            // Actual artwork
            Group {
                if let artwork = info.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [accentColor.opacity(0.8), accentColor.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: info.appIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color(red: 0.114, green: 0.725, blue: 0.329).opacity(0.19), radius: 20, y: 4)
        }
        .frame(width: 64, height: 64)
        .clipped()
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

    // MARK: - Equalizer Bars

    private var equalizerBars: some View {
        let heights: [CGFloat] = [8, 12, 6]
        return VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 2.5, height: heights[i])
                    .opacity(artworkGlowPulse ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.4 + Double(i) * 0.15)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.1),
                        value: artworkGlowPulse
                    )
            }
        }
        .frame(width: 12)
        .transition(.opacity.combined(with: .scale))
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

            Text(NSLocalizedString("media.noMedia", comment: ""))
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
                    Text(NSLocalizedString("youtube.title", comment: ""))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                }
            }

            // URL input with premium inner border
            TextField(NSLocalizedString("youtube.pasteUrl", comment: ""), text: $urlInput)
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

                        Label(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSLocalizedString("youtube.browse", comment: "") : NSLocalizedString("youtube.play", comment: ""), systemImage: "play.fill")
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
                        Label(NSLocalizedString("youtube.paste", comment: ""), systemImage: "doc.on.clipboard")
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
                    Text(NSLocalizedString("youtube.title", comment: ""))
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

            Text(state.isPlaying ? NSLocalizedString("youtube.playingInWindow", comment: "") : NSLocalizedString("youtube.paused", comment: ""))
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
                    Text(NSLocalizedString("youtube.show", comment: ""))
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

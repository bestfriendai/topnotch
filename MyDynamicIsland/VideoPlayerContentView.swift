import SwiftUI
import WebKit
import AppKit

/// Main SwiftUI view for the video player content
struct VideoPlayerContentView: View {
    let videoID: String
    var startTime: Int = 0
    @ObservedObject var playerState: YouTubePlayerState
    @ObservedObject var playerController: YouTubePlayerController
    let onClose: () -> Void

    @State private var showControls: Bool = true
    @State private var controlsWorkItem: DispatchWorkItem?
    @State private var isDraggingScrubber: Bool = false
    @State private var scrubberValue: Double = 0
    @State private var showVolumeSlider: Bool = false
    @State private var showPlaybackRateMenu: Bool = false
    @State private var isHovering: Bool = false
    @State private var isHoveringScrubber: Bool = false
    @State private var isCloseHovered: Bool = false
    @State private var keyMonitor: Any?
    @State private var centerButtonScale: CGFloat = 1.0

    private let controlsHideDelay: TimeInterval = 5.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video player
                YouTubePlayerWebView(
                    videoID: videoID,
                    startTime: startTime,
                    playerState: playerState,
                    playerController: playerController
                )
                .onAppear {
                    // Get reference to webView through coordinator
                }

                // Error overlay only — no loading overlay, no controls overlay
                // YouTube's native player handles all UI in both embed and watch page modes
                if playerState.hasError {
                    errorOverlay
                }
            }
            .background(Color.black)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    showControlsTemporarily()
                }
            }
            .onAppear {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    // Don't intercept keys when a text field or web view has focus
                    if let firstResponder = event.window?.firstResponder {
                        let responderClass = String(describing: type(of: firstResponder))
                        if firstResponder is NSTextView ||
                           firstResponder is NSTextField ||
                           responderClass.contains("WKWebView") ||
                           responderClass.contains("WKContentView") {
                            return event
                        }
                    }

                    switch event.keyCode {
                    case 49: // space
                        playerController.togglePlayPause()
                        return nil
                    case 53: // escape
                        onClose()
                        return nil
                    case 123: // left arrow
                        playerController.seekRelative(seconds: -10)
                        return nil
                    case 124: // right arrow
                        playerController.seekRelative(seconds: 10)
                        return nil
                    case 46: // m key (mute)
                        playerController.toggleMute()
                        return nil
                    case 3: // F key - fullscreen
                        if let panel = NSApp.windows.compactMap({ $0 as? VideoPlayerPanel }).first {
                            panel.toggleFullscreen()
                        }
                        return nil
                    default:
                        return event
                    }
                }
            }
            .onDisappear {
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                }
                controlsWorkItem?.cancel()
                controlsWorkItem = nil
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.7))

            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                Text(playerState.isBuffering ? "Buffering video" : "Preparing player")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(NotchDesign.textPrimary)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(NotchDesign.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            )
            .padding(36)
        }
    }

    // MARK: - Error Overlay

    private var errorOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.7))

            VStack(spacing: 16) {
                // Alert circle icon — 48pt, #E85A4F
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(NotchDesign.red)

                Text(NSLocalizedString("youtube.videoUnavailable", comment: ""))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(NotchDesign.textPrimary)
                    .lineLimit(1)

                Text(playerState.error?.localizedDescription ?? "This video may not allow embedded playback. Try opening it in Safari.")
                    .font(.system(size: 13))
                    .foregroundColor(NotchDesign.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                HStack(spacing: 12) {
                    Button(action: {
                        playerState.clearError()
                    }) {
                        Text(NSLocalizedString("youtube.tryAnother", comment: ""))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NotchDesign.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(NotchDesign.elevated)
                                    .overlay(Capsule(style: .continuous).strokeBorder(NotchDesign.borderSubtle, lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)

                    if let vid = playerState.currentVideoID {
                        Button(action: {
                            if let url = URL(string: "https://youtube.com/watch?v=\(vid)") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text(NSLocalizedString("youtube.openInSafari", comment: ""))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(NotchDesign.red)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: onClose) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(NSLocalizedString("youtube.closePlayer", comment: ""))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(NotchDesign.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(NotchDesign.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(NotchDesign.borderSubtle, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            )
            .padding(28)
        }
    }

    // MARK: - Controls Overlay

    private func controlsOverlay(size: CGSize) -> some View {
        ZStack {
            if showControls {
                // Gradient backgrounds for controls visibility
                VStack {
                    // Top gradient
                    LinearGradient(
                        colors: [.black.opacity(0.7), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)

                    Spacer()

                    // Bottom gradient
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                }
                .transition(.opacity)

                VStack {
                    // Top bar with title and close button
                    topBar

                    Spacer()

                    // Bottom controls
                    bottomControls
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            }

            // Center play button (always available when paused, fades with controls)
            if !playerState.isPlaying && playerState.isReady && showControls {
                centerPlayButton
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showControls)
    }

    // MARK: - Top Bar

    @State private var showWatchPageBanner = true

    private var watchPageOverlay: some View {
        VStack {
            if showWatchPageBanner {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                            .font(.system(size: 10, weight: .semibold))
                        Text(NSLocalizedString("youtube.watchPageMode", comment: ""))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(NotchDesign.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )

                    Button(action: { withAnimation(.spring()) { showWatchPageBanner = false } }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(NotchDesign.textMuted)
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.spring()) { showWatchPageBanner = false }
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                // Video title — 14px semibold, white
                if let title = playerState.videoTitle {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(NotchDesign.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // "Playing from YouTube" — 12px, red
                Text(NSLocalizedString("youtube.playingFromYT", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(NotchDesign.red)
            }

            Spacer()

            // Close X button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isCloseHovered ? NotchDesign.textPrimary : NotchDesign.textMuted)
                    .animation(.spring(), value: isCloseHovered)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(isCloseHovered ? 0.15 : 0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isCloseHovered = hovering
            }
            .help(NSLocalizedString("tooltip.close", comment: ""))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.4))
        )
    }

    // MARK: - Center Play Button

    private var centerPlayButton: some View {
        Button(action: {
            playerController.play()
        }) {
            ZStack {
                // Red circle play icon overlay
                Circle()
                    .fill(NotchDesign.red)
                    .frame(width: 64, height: 64)
                    .shadow(color: NotchDesign.red.opacity(0.3), radius: 20, y: 4)

                Image(systemName: "play.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                    .offset(x: 2)
            }
            .scaleEffect(centerButtonScale)
            .onAppear {
                // Reset before starting to avoid stale animation state
                centerButtonScale = 1.0
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    centerButtonScale = 1.04
                }
            }
            .onDisappear {
                // Reset scale without animation to clean up
                withAnimation(nil) {
                    centerButtonScale = 1.0
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 6) {
            // Red progress scrubber
            scrubber

            // Control buttons row
            HStack(spacing: 12) {
                // Red play/pause circle
                playPauseButton

                // Time display
                Text(playerState.currentTimeFormatted)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundColor(NotchDesign.textPrimary)

                Text("/")
                    .font(.system(size: 10))
                    .foregroundColor(NotchDesign.textMuted)

                Text(playerState.durationFormatted)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundColor(NotchDesign.textMuted)

                Spacer()

                // Volume
                volumeControl

                // Playback rate "1x" pill
                playbackRateButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.4))
        )
    }

    // MARK: - Scrubber

    private var scrubber: some View {
        GeometryReader { geometry in
            let progress = isDraggingScrubber ? scrubberValue : playerState.progress
            let trackHeight: CGFloat = 3
            let knobSize: CGFloat = 10

            ZStack(alignment: .leading) {
                // Track background — borderSubtle
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(NotchDesign.borderSubtle)
                    .frame(height: trackHeight)

                // Red progress fill
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(NotchDesign.red)
                    .frame(width: max(0, geometry.size.width * progress), height: trackHeight)

                // White knob — appears on hover
                if isHovering || isDraggingScrubber || isHoveringScrubber {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        .frame(width: knobSize, height: knobSize)
                        .offset(x: max(0, min(geometry.size.width - knobSize, geometry.size.width * progress - knobSize / 2)))
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                }
            }
            .animation(.spring(), value: isHoveringScrubber)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHoveringScrubber = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingScrubber = true
                        resetControlsTimer()
                        let newValue = max(0, min(1, value.location.x / geometry.size.width))
                        scrubberValue = newValue
                    }
                    .onEnded { value in
                        let newValue = max(0, min(1, value.location.x / geometry.size.width))
                        let seekTime = playerState.duration * newValue
                        playerController.seek(to: seekTime)
                        isDraggingScrubber = false
                    }
            )
        }
        .frame(height: 14)
    }

    // MARK: - Play/Pause Button

    private var playPauseButton: some View {
        Button(action: {
            playerController.togglePlayPause()
            showControlsTemporarily()
        }) {
            Image(systemName: playerState.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(NotchDesign.red)
                )
        }
        .buttonStyle(.plain)
        .help(playerState.isPlaying ? NSLocalizedString("tooltip.pause", comment: "") : NSLocalizedString("tooltip.play", comment: ""))
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        HStack(spacing: 4) {
            Button(action: {
                playerController.toggleMute()
            }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 13))
                    .foregroundColor(NotchDesign.textPrimary)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help(playerState.isMuted ? NSLocalizedString("tooltip.unmute", comment: "") : NSLocalizedString("tooltip.mute", comment: ""))

            if showVolumeSlider {
                Slider(value: Binding(
                    get: { playerState.volume },
                    set: { newValue in
                        playerController.setVolume(newValue)
                        playerState.volume = newValue
                        if newValue > 0 {
                            playerState.isMuted = false
                        }
                    }
                ), in: 0...1)
                .frame(width: 50)
                .tint(.white)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.spring(), value: showVolumeSlider)
        .onHover { hovering in
            showVolumeSlider = hovering
        }
    }

    private var volumeIcon: String {
        if playerState.isMuted || playerState.volume == 0 {
            return "speaker.slash.fill"
        } else if playerState.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if playerState.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    // MARK: - Playback Rate Button

    private var playbackRateButton: some View {
        Menu {
            ForEach(YouTubePlayerState.playbackRates, id: \.self) { rate in
                Button(action: {
                    playerController.setPlaybackRate(rate)
                    playerState.playbackRate = rate
                }) {
                    HStack {
                        Text(rate == 1.0 ? "Normal" : "\(rate, specifier: "%.2g")x")
                        if playerState.playbackRate == rate {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(playerState.playbackRate == 1.0 ? "1x" : "\(playerState.playbackRate, specifier: "%.2g")x")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundColor(NotchDesign.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
        }
        .menuStyle(.borderlessButton)
        .help(NSLocalizedString("tooltip.playbackSpeed", comment: ""))
    }

    // MARK: - Controls Visibility

    private func showControlsTemporarily() {
        withAnimation(.easeOut(duration: 0.2)) {
            showControls = true
        }
        resetControlsTimer()
    }

    private func resetControlsTimer() {
        controlsWorkItem?.cancel()
        controlsWorkItem = nil

        guard playerState.isPlaying else { return }

        let work = DispatchWorkItem { [self] in
            // Only hide if still playing and not hovering/dragging
            if playerState.isPlaying && !isDraggingScrubber && !isHovering {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
        controlsWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + controlsHideDelay, execute: work)
    }

    // MARK: - Time Formatting

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#if DEBUG
struct VideoPlayerContentView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerContentView(
            videoID: "dQw4w9WgXcQ",
            playerState: YouTubePlayerState(videoID: "dQw4w9WgXcQ"),
            playerController: YouTubePlayerController(),
            onClose: {}
        )
        .frame(width: 640, height: 360)
        .preferredColorScheme(.dark)
    }
}
#endif

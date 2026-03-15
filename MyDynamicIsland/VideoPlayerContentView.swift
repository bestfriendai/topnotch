import SwiftUI
import WebKit
import AppKit

/// Main SwiftUI view for the video player content
struct VideoPlayerContentView: View {
    let videoID: String
    @ObservedObject var playerState: YouTubePlayerState
    @ObservedObject var playerController: YouTubePlayerController
    let onClose: () -> Void

    @State private var showControls: Bool = true
    @State private var controlsTimer: Timer?
    @State private var isDraggingScrubber: Bool = false
    @State private var scrubberValue: Double = 0
    @State private var showVolumeSlider: Bool = false
    @State private var showPlaybackRateMenu: Bool = false
    @State private var isHovering: Bool = false
    @State private var isHoveringScrubber: Bool = false
    @State private var isCloseHovered: Bool = false
    @State private var keyMonitor: Any?
    @State private var centerButtonScale: CGFloat = 1.0

    private let controlsHideDelay: TimeInterval = 3.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video player
                YouTubePlayerWebView(
                    videoID: videoID,
                    playerState: playerState,
                    playerController: playerController
                )
                .onAppear {
                    // Get reference to webView through coordinator
                }

                // Loading indicator
                if playerState.playbackMode == .embed && (!playerState.isReady || playerState.isBuffering) {
                    loadingOverlay
                }

                // Error overlay
                if playerState.hasError {
                    errorOverlay
                }

                // Controls overlay
                if playerState.playbackMode == .embed && !playerState.hasError {
                    controlsOverlay(size: geometry.size)
                }

                if playerState.playbackMode == .watchPageFallback {
                    watchPageOverlay
                }
            }
            .background(Color.black)
            .cornerRadius(12)
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    showControlsTemporarily()
                }
            }
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        // Double-tap: toggle fullscreen
                        if let panel = NSApp.windows.compactMap({ $0 as? VideoPlayerPanel }).first {
                            panel.toggleFullscreen()
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if showControls {
                            playerController.togglePlayPause()
                        } else {
                            showControlsTemporarily()
                        }
                    }
            )
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
                    case 134: // m key (mute)
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
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                if playerState.isBuffering {
                    Text("Buffering...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Error Overlay

    private var errorOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text("Video Unavailable")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(playerState.error?.localizedDescription ?? "This video may not allow embedded playback. Try opening it in Safari.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button("Try Another") {
                        playerState.clearError()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    if let vid = playerState.currentVideoID {
                        Button("Open in Safari") {
                            if let url = URL(string: "https://youtube.com/watch?v=\(vid)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Button("Close") { onClose() }
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 12))
            }
            .padding(24)
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
                    Text("Watch page mode")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Button(action: { withAnimation { showWatchPageBanner = false } }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.5)))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeOut(duration: 0.3)) { showWatchPageBanner = false }
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
                // Video title
                if let title = playerState.videoTitle {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // "Playing from YouTube" label
                Text("Playing from YouTube")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isCloseHovered ? .white : .white.opacity(0.7))
                    .animation(.easeOut(duration: 0.15), value: isCloseHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isCloseHovered = hovering
            }
            .help("Close")
        }
    }

    // MARK: - Center Play Button

    private var centerPlayButton: some View {
        Button(action: {
            playerController.play()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 4)

                Image(systemName: "play.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .offset(x: 2)
            }
            .scaleEffect(centerButtonScale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    centerButtonScale = 1.05
                }
            }
            .onDisappear {
                centerButtonScale = 1.0
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 6) {
            // Progress bar / scrubber
            scrubber

            // Control buttons row
            HStack(spacing: 12) {
                // Play/Pause button
                playPauseButton

                // Current time
                Text(playerState.currentTimeFormatted)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundColor(.white)

                // Separator
                Text("/")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))

                // Duration
                Text(playerState.durationFormatted)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                // Volume control
                volumeControl

                // Playback rate
                playbackRateButton

                // Picture-in-Picture (placeholder)
                pipButton
            }
        }
    }

    // MARK: - Scrubber

    private var scrubber: some View {
        GeometryReader { geometry in
            let progress = isDraggingScrubber ? scrubberValue : playerState.progress
            let trackHeight: CGFloat = isHoveringScrubber || isDraggingScrubber ? 5 : 3
            let knobSize: CGFloat = isHoveringScrubber || isDraggingScrubber ? 14 : 10

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(height: trackHeight)

                // Progress fill - YouTube red
                Capsule()
                    .fill(Color(red: 1, green: 0.07, blue: 0.07))
                    .frame(width: max(0, geometry.size.width * progress), height: trackHeight)

                // Scrubber knob (visible when hovering or dragging)
                if isHovering || isDraggingScrubber || isHoveringScrubber {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                        .frame(width: knobSize, height: knobSize)
                        .offset(x: max(0, min(geometry.size.width - knobSize, geometry.size.width * progress - knobSize / 2)))
                        .animation(.easeOut(duration: 0.15), value: knobSize)
                }
            }
            .animation(.easeOut(duration: 0.15), value: trackHeight)
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
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(playerState.isPlaying ? "Pause" : "Play")
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        HStack(spacing: 4) {
            Button(action: {
                playerController.toggleMute()
            }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(playerState.isMuted ? "Unmute" : "Mute")

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
        .animation(.easeOut(duration: 0.2), value: showVolumeSlider)
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
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.white.opacity(0.15), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .help("Playback speed")
    }

    // MARK: - PiP Button

    private var pipButton: some View {
        Button(action: {
            // PiP functionality - placeholder
        }) {
            Image(systemName: "pip.enter")
                .font(.system(size: 13))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help("Picture in Picture")
    }

    // MARK: - Controls Visibility

    private func showControlsTemporarily() {
        withAnimation(.easeOut(duration: 0.2)) {
            showControls = true
        }
        resetControlsTimer()
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()

        guard playerState.isPlaying else { return }

        controlsTimer = Timer.scheduledTimer(withTimeInterval: controlsHideDelay, repeats: false) { _ in
            DispatchQueue.main.async {
                // Only hide if still playing and not hovering/dragging
                if self.playerState.isPlaying && !self.isDraggingScrubber && !self.isHovering {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.showControls = false
                    }
                }
            }
        }
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

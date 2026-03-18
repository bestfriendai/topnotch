import SwiftUI

struct NotchInlineYouTubePlayerView: View {
    @ObservedObject var notchState: NotchState
    let videoID: String
    @ObservedObject var playerState: YouTubePlayerState
    @ObservedObject var playerController: YouTubePlayerController
    let startTime: Int

    @State private var resizeStartWidth: CGFloat?
    @State private var isHoveringResizeHandle = false
    @State private var isHoveringChrome = false

    private let minWidth: CGFloat = 360
    private let maxWidth: CGFloat = 960
    private let aspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        VStack(spacing: 0) {
            // Chrome header
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red.opacity(0.95))
                        .frame(width: 8, height: 8)
                    Text("YouTube")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    if let title = playerState.videoTitle, !title.isEmpty {
                        Text("\u{00B7}")
                            .foregroundStyle(.white.opacity(0.3))
                        Text(title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text("Pinned")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                Spacer(minLength: 8)

                // Minimize to bar
                Button(action: minimizePlayer) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(isHoveringChrome ? 0.10 : 0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Play in background")

                // Pop out to floating window
                Button(action: popToWindow) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(isHoveringChrome ? 0.10 : 0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Pop out to floating window")

                // Close
                Button(action: closePlayer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(isHoveringChrome ? 0.12 : 0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close video")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Video
            VideoPlayerContentView(
                videoID: videoID,
                startTime: startTime,
                playerState: playerState,
                playerController: playerController,
                onClose: closePlayer
            )
            .frame(width: notchState.youtubePlayerWidth, height: notchState.youtubePlayerHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(isHoveringResizeHandle ? 0.88 : 0.72))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay(alignment: .topLeading) {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 12))
                                path.addLine(to: CGPoint(x: 12, y: 0))
                            }
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
                .frame(width: 56, height: 56, alignment: .bottomTrailing)
                .contentShape(Rectangle())
                .gesture(resizeGesture)
                .onHover { hovering in
                    isHoveringResizeHandle = hovering
                }
            }
            .padding(.horizontal, 12)

            // Always-visible mini controls strip
            if playerState.isReady || playerState.isPlaying {
                HStack(spacing: 10) {
                    Button(action: { playerController.togglePlayPause() }) {
                        Image(systemName: playerState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Text(playerState.currentTimeFormatted)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 38, alignment: .trailing)

                    Slider(
                        value: Binding(
                            get: { playerState.progress },
                            set: { playerController.seek(to: $0 * playerState.duration) }
                        ),
                        in: 0...1
                    )
                    .tint(.red)

                    Text(playerState.remainingTimeFormatted)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 42, alignment: .leading)

                    Button(action: { playerController.toggleMute() }) {
                        Image(systemName: playerState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)

                    Slider(
                        value: Binding(
                            get: { playerState.isMuted ? 0 : playerState.volume },
                            set: { newVol in
                                if playerState.isMuted { playerController.unmute() }
                                playerController.setVolume(newVol)
                            }
                        ),
                        in: 0...1
                    )
                    .tint(.white.opacity(0.5))
                    .frame(width: 60)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.96), Color(red: 0.08, green: 0.08, blue: 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 20, y: 10)
        .onHover { hovering in
            isHoveringChrome = hovering
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            notchState.isExpanded = true
            playerState.loadVideo(id: videoID)
        }
        .onChange(of: videoID) { _, newValue in
            playerState.loadVideo(id: newValue)
        }
        .onChange(of: playerState.isPlaying) { _, playing in
            notchState.inlineYouTubeIsPlaying = playing
        }
        .onChange(of: playerState.progress) { _, progress in
            notchState.inlineYouTubeProgress = progress
        }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if resizeStartWidth == nil {
                    resizeStartWidth = notchState.youtubePlayerWidth
                }

                let baseWidth = resizeStartWidth ?? notchState.youtubePlayerWidth
                let widthDelta = max(value.translation.width, value.translation.height * aspectRatio)
                let newWidth = min(max(baseWidth + widthDelta, minWidth), maxWidth)

                notchState.youtubePlayerWidth = newWidth
                notchState.youtubePlayerHeight = newWidth / aspectRatio
            }
            .onEnded { _ in
                resizeStartWidth = nil
            }
    }

    private func closePlayer() {
        playerController.pause()
        playerState.reset()
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            notchState.isShowingInlineYouTubePlayer = false
            notchState.inlineYouTubeVideoID = nil
            notchState.inlineYouTubeMinimized = false
            notchState.activeDeckCard = .home
            if !notchState.isHovered {
                notchState.isExpanded = false
            }
        }
    }

    private func minimizePlayer() {
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            notchState.inlineYouTubeMinimized = true
            notchState.isExpanded = false
        }
    }

    private func popToWindow() {
        // Capture video ID and playback position before tearing down the inline player
        let savedVideoID = videoID
        let savedTime = Int(playerState.currentTime)

        // Pause and tear down the inline player first so there's no
        // concurrent YouTube embed when the floating panel loads.
        playerController.pause()
        playerState.reset()
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
            notchState.isShowingInlineYouTubePlayer = false
            notchState.inlineYouTubeVideoID = nil
            notchState.inlineYouTubeMinimized = false
            notchState.activeDeckCard = .youtube
            if !notchState.isHovered {
                notchState.isExpanded = false
            }
        }

        // Open the floating video panel AFTER the inline player's WKWebView is fully
        // torn down, so we never have two concurrent YouTube WKWebViews.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            VideoWindowManager.shared.showVideo(videoID: savedVideoID, startTime: savedTime)
        }
    }
}

private extension NotchDeckCard {
    var title: String {
        switch self {
        case .home: return "Home"
        case .weather: return "Weather"
        case .youtube: return "YouTube"
        case .media: return "Media"
        case .pomodoro: return "Focus"
        case .clipboard: return "Clipboard"
        case .calendar: return "Calendar"
        case .fileShelf: return "File Shelf"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "sparkles"
        case .weather: return "cloud.sun.fill"
        case .youtube: return "play.rectangle.fill"
        case .media: return "music.note"
        case .pomodoro: return "timer"
        case .clipboard: return "doc.on.clipboard"
        case .calendar: return "calendar"
        case .fileShelf: return "tray.and.arrow.down.fill"
        }
    }
}

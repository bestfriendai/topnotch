import AppKit
import SwiftUI
import Combine

/// Singleton manager for the video player window
@MainActor
final class VideoWindowManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = VideoWindowManager()
    
    // MARK: - Published State
    
    @Published private(set) var isVisible: Bool = false
    @Published private(set) var currentVideoID: String?
    @Published var playerState: YouTubePlayerState = YouTubePlayerState()
    @Published var playerController: YouTubePlayerController = YouTubePlayerController()
    
    // MARK: - Persistence
    
    @AppStorage("videoPlayer.lastX") private var lastX: Double = 100
    @AppStorage("videoPlayer.lastY") private var lastY: Double = 100
    @AppStorage("videoPlayer.lastWidth") private var lastWidth: Double = 640
    @AppStorage("videoPlayer.lastHeight") private var lastHeight: Double = 360
    @AppStorage("videoPlayer.lastVolume") private var lastVolume: Double = 1.0
    
    // MARK: - Private Properties
    
    private var panel: VideoPlayerPanel?
    private var hostingView: NSHostingView<VideoPlayerContentView>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let defaultSize = NSSize(width: 640, height: 360)
    private let notchLaunchSize = NSSize(width: 220, height: 36)
    private let animationDuration: TimeInterval = 0.3
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Shows a video in the floating player
    /// - Parameters:
    ///   - videoID: YouTube video ID
    ///   - startTime: Seconds offset to resume playback from (default 0)
    ///   - fromNotchPosition: Optional point to animate from (e.g., notch position)
    func showVideo(videoID: String, startTime: Int = 0, fromNotchPosition: NSPoint? = nil) {
        let parsedID = YouTubeURLParser.extractVideoID(from: videoID) ?? videoID

        guard YouTubeURLParser.isValidVideoID(parsedID) else {
            playerState.setError(.invalidVideoID)
            return
        }

        // Close any inline player first to avoid concurrent YouTube embeds
        NotificationCenter.default.post(name: .closeInlineYouTubeVideo, object: nil)

        currentVideoID = parsedID
        playerState.loadVideo(id: parsedID)
        playerState.volume = lastVolume

        // Create panel if needed
        if panel == nil {
            createPanel()
        }

        // Update content with the new video
        updateContent(videoID: parsedID, startTime: startTime)

        // Show the panel
        if let startPoint = fromNotchPosition {
            animateIn(from: startPoint)
        } else {
            panel?.orderFront(nil)
            panel?.alphaValue = 1.0
            isVisible = true
        }
    }

    /// Hides the video player with animation
    func hideVideo() {
        guard isVisible else { return }
        savePosition()
        animateOut { [weak self] in
            self?.cleanupPanel()
        }
    }

    /// Closes the video player immediately
    func closeVideo() {
        guard isVisible else { return }
        savePosition()
        cleanupPanel()
    }
    
    /// Toggles the video player visibility
    func toggleVideo(videoID: String? = nil, fromNotchPosition: NSPoint? = nil) {
        if isVisible {
            hideVideo()
        } else if let id = videoID ?? currentVideoID {
            showVideo(videoID: id, fromNotchPosition: fromNotchPosition)
        }
    }
    
    /// Brings the panel to front if visible
    func bringToFront() {
        panel?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Panel Management
    
    private func createPanel() {
        var savedOrigin = NSPoint(x: lastX, y: lastY)
        if lastX == 100 && lastY == 100 {
            savedOrigin = getNotchPosition()
        }

        let width = lastWidth
        let height = lastHeight

        // Validate saved position is on-screen; if not, reset to notch position
        let savedFrame: NSRect
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(savedOrigin) }) {
            let visible = screen.visibleFrame
            let clampedX = min(max(savedOrigin.x, visible.minX), visible.maxX - width)
            let clampedY = min(max(savedOrigin.y, visible.minY), visible.maxY - height)
            savedFrame = NSRect(x: clampedX, y: clampedY, width: width, height: height)
        } else {
            let fallback = getNotchPosition()
            savedFrame = NSRect(x: fallback.x, y: fallback.y, width: width, height: height)
        }

        panel = VideoPlayerPanel(contentRect: savedFrame)
        panel?.delegate = self

        // Set custom content view with rounded corners
        let contentView = VideoPlayerNSContentView(frame: savedFrame)
        panel?.contentView = contentView
    }
    
    private func updateContent(videoID: String, startTime: Int = 0) {
        guard let panel = panel else { return }

        let contentSwiftUIView = VideoPlayerContentView(
            videoID: videoID,
            startTime: startTime,
            playerState: playerState,
            playerController: playerController,
            onClose: { [weak self] in
                self?.hideVideo()
            }
        )

        if hostingView == nil {
            let newHostingView = NSHostingView(rootView: contentSwiftUIView)
            let contentBounds = panel.contentView?.bounds ?? NSRect(origin: .zero, size: defaultSize)
            newHostingView.frame = contentBounds
            newHostingView.autoresizingMask = [.width, .height]
            panel.contentView?.addSubview(newHostingView)
            hostingView = newHostingView
        } else {
            hostingView?.rootView = contentSwiftUIView
        }
    }
    
    private func cleanupPanel() {
        hostingView?.removeFromSuperview()
        hostingView = nil
        panel?.close()
        panel = nil
        isVisible = false
        currentVideoID = nil
        playerState.reset()
    }
    
    // MARK: - Position Management
    
    private func savePosition() {
        guard let frame = panel?.frame else { return }
        lastX = frame.origin.x
        lastY = frame.origin.y
        lastWidth = frame.width
        lastHeight = frame.height
        lastVolume = playerState.volume
    }
    
    /// Returns the center point of the panel
    var panelCenter: NSPoint? {
        guard let frame = panel?.frame else { return nil }
        return NSPoint(x: frame.midX, y: frame.midY)
    }
    
    // MARK: - Notch Position
    
    private func getNotchPosition() -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let screenFrame = screen.frame
        let menuBarHeight: CGFloat = NSStatusBar.system.thickness
        let notchCenterX = screenFrame.midX
        let notchBottomY = screenFrame.maxY - menuBarHeight - 2
        let windowWidth: CGFloat = CGFloat(lastWidth)
        let windowHeight: CGFloat = CGFloat(lastHeight)
        let x = notchCenterX - windowWidth / 2
        let y = notchBottomY - windowHeight - 8
        return NSPoint(x: x, y: y)
    }
    
    // MARK: - Animations
    
    private func animateIn(from startPoint: NSPoint) {
        guard let panel = panel else { return }
        
        let finalFrame = panel.frame
        let startFrame = notchLaunchFrame(anchoredAt: startPoint, finalFrame: finalFrame)
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1.0
        }, completionHandler: {
            Task { @MainActor in
                self.isVisible = true
            }
        })
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        guard let panel = panel else {
            completion()
            return
        }
        
        let endFrame = notchLaunchFrame(anchoredAt: getNotchPosition(), finalFrame: panel.frame)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            panel.animator().setFrame(endFrame, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            completion()
        })
    }

    private func notchLaunchFrame(anchoredAt point: NSPoint, finalFrame: NSRect) -> NSRect {
        NSRect(
            x: point.x + (finalFrame.width - notchLaunchSize.width) / 2,
            y: point.y + finalFrame.height - notchLaunchSize.height,
            width: notchLaunchSize.width,
            height: notchLaunchSize.height
        )
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .videoPlayerTogglePlayPause)
            .sink { [weak self] _ in
                self?.playerController.togglePlayPause()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .videoPlayerSeekForward)
            .sink { [weak self] _ in
                self?.playerController.seekRelative(seconds: 10)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .videoPlayerSeekBackward)
            .sink { [weak self] _ in
                self?.playerController.seekRelative(seconds: -10)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .videoPlayerVolumeUp)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newVolume = min(1.0, self.playerState.volume + 0.1)
                self.playerController.setVolume(newVolume)
                self.playerState.volume = newVolume
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .videoPlayerVolumeDown)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newVolume = max(0.0, self.playerState.volume - 0.1)
                self.playerController.setVolume(newVolume)
                self.playerState.volume = newVolume
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .videoPlayerClose)
            .sink { [weak self] _ in
                self?.hideVideo()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Convenience Extensions

extension VideoWindowManager {
    /// Opens a video from a YouTube URL or video ID
    func openVideo(from input: String) {
        if let request = YouTubeURLParser.playbackRequest(from: input) {
            showVideo(videoID: request.videoID, startTime: request.startTime)
        } else {
            playerState.setError(.invalidVideoID)
        }
    }
    
    /// Opens a video from the clipboard
    func openVideoFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            return
        }
        openVideo(from: clipboardString)
    }
}

// MARK: - NSWindowDelegate

extension VideoWindowManager: NSWindowDelegate {
    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in
            self.savePosition()
        }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            self.savePosition()
        }
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.savePosition()
            self.cleanupPanel()
        }
    }
}

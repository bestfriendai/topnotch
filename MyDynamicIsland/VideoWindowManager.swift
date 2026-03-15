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
    ///   - fromNotchPosition: Optional point to animate from (e.g., notch position)
    func showVideo(videoID: String, fromNotchPosition: NSPoint? = nil) {
        let parsedID = YouTubeURLParser.extractVideoID(from: videoID) ?? videoID

        guard YouTubeURLParser.isValidVideoID(parsedID) else {
            playerState.setError(.invalidVideoID)
            return
        }

        currentVideoID = parsedID
        playerState.loadVideo(id: parsedID)
        playerState.volume = lastVolume
        NotificationCenter.default.post(name: .openInlineYouTubeVideo, object: parsedID)
        isVisible = true
    }
    
    /// Hides the video player with animation
    func hideVideo() {
        guard isVisible else { return }
        isVisible = false
        NotificationCenter.default.post(name: .closeInlineYouTubeVideo, object: nil)
    }
    
    /// Closes the video player immediately
    func closeVideo() {
        hideVideo()
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
        
        let savedFrame = NSRect(
            x: savedOrigin.x,
            y: savedOrigin.y,
            width: lastWidth,
            height: lastHeight
        )
        
        panel = VideoPlayerPanel(contentRect: savedFrame)
        panel?.delegate = self
        
        // Set custom content view with rounded corners
        let contentView = VideoPlayerNSContentView(frame: savedFrame)
        panel?.contentView = contentView
    }
    
    private func updateContent(videoID: String) {
        guard let panel = panel else { return }
        
        let contentSwiftUIView = VideoPlayerContentView(
            videoID: videoID,
            playerState: playerState,
            playerController: playerController,
            onClose: { [weak self] in
                self?.hideVideo()
            }
        )
        
        if hostingView == nil {
            hostingView = NSHostingView(rootView: contentSwiftUIView)
            hostingView?.frame = panel.contentView?.bounds ?? .zero
            hostingView?.autoresizingMask = [.width, .height]
            panel.contentView?.addSubview(hostingView!)
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
        if let result = YouTubeURLParser.parse(input) {
            showVideo(videoID: result.videoID)
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
}

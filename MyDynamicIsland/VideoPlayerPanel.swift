import AppKit
import SwiftUI

/// Custom NSPanel subclass for the floating video player window
class VideoPlayerPanel: NSPanel {

    // MARK: - Configuration

    private static let minSize = NSSize(width: 320, height: 180)
    private static let maxSize = NSSize(width: 1920, height: 1080)
    private static let aspectRatio: CGFloat = 16.0 / 9.0

    // MARK: - State

    private var panelTrackingArea: NSTrackingArea?
    private var isMouseInside: Bool = false

    // Fullscreen toggle state
    private var preFullscreenFrame: NSRect?
    private var isInFullscreen: Bool = false

    // MARK: - Initialization

    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configurePanel()
    }

    private func configurePanel() {
        // Title bar — transparent so video fills to top
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Panel behavior
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false

        // Appearance
        isOpaque = false
        backgroundColor = .black
        hasShadow = true

        // Size constraints
        minSize = Self.minSize
        maxSize = Self.maxSize

        // Make it movable by dragging anywhere
        isMovableByWindowBackground = true

        // Set aspect ratio
        contentAspectRatio = NSSize(width: Self.aspectRatio, height: 1.0)

        // Setup tracking area for hover opacity
        setupTrackingArea()
    }

    // MARK: - Tracking Area

    private func setupTrackingArea() {
        guard let contentView = contentView else { return }

        if let existing = panelTrackingArea {
            contentView.removeTrackingArea(existing)
        }

        panelTrackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        if let area = panelTrackingArea {
            contentView.addTrackingArea(area)
        }
    }

    // MARK: - Mouse Events

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        NSCursor.arrow.set()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = 0.85
        }
    }

    // MARK: - Corner Snapping

    func snapToNearestCorner() {
        guard let screen = self.screen else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame
        let margin: CGFloat = 16

        let centerX = windowFrame.midX
        let centerY = windowFrame.midY
        let screenCenterX = screenFrame.midX
        let screenCenterY = screenFrame.midY

        var snapX: CGFloat
        var snapY: CGFloat

        if centerX < screenCenterX {
            snapX = screenFrame.minX + margin
        } else {
            snapX = screenFrame.maxX - windowFrame.width - margin
        }

        if centerY < screenCenterY {
            snapY = screenFrame.minY + margin
        } else {
            snapY = screenFrame.maxY - windowFrame.height - margin
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrameOrigin(NSPoint(x: snapX, y: snapY))
        }, completionHandler: {
            // Save position after snap animation completes
            UserDefaults.standard.set(snapX, forKey: "videoPlayer.lastX")
            UserDefaults.standard.set(snapY, forKey: "videoPlayer.lastY")
            UserDefaults.standard.set(self.frame.width, forKey: "videoPlayer.lastWidth")
            UserDefaults.standard.set(self.frame.height, forKey: "videoPlayer.lastHeight")
        })
    }

    // MARK: - Fullscreen Toggle

    func toggleFullscreen() {
        guard let screen = self.screen else { return }

        if isInFullscreen, let savedFrame = preFullscreenFrame {
            // Restore to previous size
            isInFullscreen = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(savedFrame, display: true)
            }
            preFullscreenFrame = nil
        } else {
            // Save current frame and go fullscreen
            preFullscreenFrame = self.frame
            isInFullscreen = true
            let screenFrame = screen.visibleFrame
            // Fill the visible area maintaining aspect ratio
            let targetWidth = screenFrame.width
            let targetHeight = targetWidth / Self.aspectRatio
            let finalHeight = min(targetHeight, screenFrame.height)
            let finalWidth = finalHeight * Self.aspectRatio
            let x = screenFrame.midX - finalWidth / 2
            let y = screenFrame.midY - finalHeight / 2
            let fullFrame = NSRect(x: x, y: y, width: finalWidth, height: finalHeight)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(fullFrame, display: true)
            }
        }
    }

    // MARK: - First Responder

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Key Events (for video controls)

    override func keyDown(with event: NSEvent) {
        // Space bar for play/pause
        if event.keyCode == 49 { // Space
            NotificationCenter.default.post(name: .videoPlayerTogglePlayPause, object: nil)
            return
        }

        // Arrow keys for seeking
        switch event.keyCode {
        case 123: // Left arrow
            NotificationCenter.default.post(name: .videoPlayerSeekBackward, object: nil)
        case 124: // Right arrow
            NotificationCenter.default.post(name: .videoPlayerSeekForward, object: nil)
        case 126: // Up arrow
            NotificationCenter.default.post(name: .videoPlayerVolumeUp, object: nil)
        case 125: // Down arrow
            NotificationCenter.default.post(name: .videoPlayerVolumeDown, object: nil)
        case 3: // F key - toggle fullscreen
            toggleFullscreen()
        default:
            super.keyDown(with: event)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openInlineYouTubeVideo = Notification.Name("openInlineYouTubeVideo")
    static let closeInlineYouTubeVideo = Notification.Name("closeInlineYouTubeVideo")
    static let videoPlayerTogglePlayPause = Notification.Name("videoPlayerTogglePlayPause")
    static let videoPlayerSeekForward = Notification.Name("videoPlayerSeekForward")
    static let videoPlayerSeekBackward = Notification.Name("videoPlayerSeekBackward")
    static let videoPlayerVolumeUp = Notification.Name("videoPlayerVolumeUp")
    static let videoPlayerVolumeDown = Notification.Name("videoPlayerVolumeDown")
    static let videoPlayerClose = Notification.Name("videoPlayerClose")
}

// MARK: - Panel Content View

/// Custom content view with rounded corners
class VideoPlayerNSContentView: NSView {

    private let cornerRadius: CGFloat = 12.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.cornerRadius = cornerRadius
    }
}

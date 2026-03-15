import AppKit
import SwiftUI

/// Custom NSPanel subclass for the floating video player window
class VideoPlayerPanel: NSPanel {

    // MARK: - Configuration

    private static let minSize = NSSize(width: 320, height: 180)
    private static let maxSize = NSSize(width: 1920, height: 1080)
    private static let aspectRatio: CGFloat = 16.0 / 9.0
    private static let resizeMargin: CGFloat = 8.0
    private static let cornerResizeSize: CGFloat = 16.0

    // MARK: - State

    private var isResizing = false
    private var isDragging = false
    private var resizeEdge: ResizeEdge = .none
    private var initialMouseLocation: NSPoint = .zero
    private var initialFrame: NSRect = .zero
    private var panelTrackingArea: NSTrackingArea?
    private var isMouseInside: Bool = false

    // Fullscreen toggle state
    private var preFullscreenFrame: NSRect?
    private var isInFullscreen: Bool = false

    /// Edges/corners that can be resized
    private enum ResizeEdge {
        case none
        case left, right, top, bottom
        case topLeft, topRight, bottomLeft, bottomRight
    }

    // MARK: - Initialization

    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configurePanel()
    }

    private func configurePanel() {
        // Panel behavior
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false

        // Appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Size constraints
        minSize = Self.minSize
        maxSize = Self.maxSize

        // Make it movable
        isMovableByWindowBackground = true

        // Set aspect ratio
        contentAspectRatio = NSSize(width: Self.aspectRatio, height: 1.0)

        // Setup tracking area for resize cursor changes and hover opacity
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

    override func mouseMoved(with event: NSEvent) {
        let location = event.locationInWindow
        let edge = detectResizeEdge(at: location)
        updateCursor(for: edge)
    }

    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        resizeEdge = detectResizeEdge(at: location)

        if resizeEdge != .none {
            isResizing = true
            isDragging = false
            initialMouseLocation = NSEvent.mouseLocation
            initialFrame = frame
        } else {
            isDragging = true
            isResizing = false
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isResizing {
            performResize()
        } else {
            super.mouseDragged(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let wasDragging = isDragging
        let wasResizing = isResizing
        isResizing = false
        isDragging = false
        resizeEdge = .none
        super.mouseUp(with: event)

        // Snap to nearest corner after a drag or resize
        if wasDragging || wasResizing {
            snapToNearestCorner()
        }
    }

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

    // MARK: - Resize Detection

    private func detectResizeEdge(at point: NSPoint) -> ResizeEdge {
        guard let contentView = contentView else { return .none }

        let bounds = contentView.bounds
        let margin = Self.resizeMargin
        let corner = Self.cornerResizeSize

        let isLeft = point.x < margin
        let isRight = point.x > bounds.width - margin
        let isTop = point.y > bounds.height - margin
        let isBottom = point.y < margin

        let isCornerLeft = point.x < corner
        let isCornerRight = point.x > bounds.width - corner
        let isCornerTop = point.y > bounds.height - corner
        let isCornerBottom = point.y < corner

        // Check corners first
        if isCornerTop && isCornerLeft { return .topLeft }
        if isCornerTop && isCornerRight { return .topRight }
        if isCornerBottom && isCornerLeft { return .bottomLeft }
        if isCornerBottom && isCornerRight { return .bottomRight }

        // Then edges
        if isLeft { return .left }
        if isRight { return .right }
        if isTop { return .top }
        if isBottom { return .bottom }

        return .none
    }

    private func updateCursor(for edge: ResizeEdge) {
        switch edge {
        case .none:
            NSCursor.arrow.set()
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .topLeft, .bottomRight:
            // Diagonal resize (no built-in cursor, use crosshair or custom)
            NSCursor.crosshair.set()
        case .topRight, .bottomLeft:
            NSCursor.crosshair.set()
        }
    }

    // MARK: - Resize Logic

    private func performResize() {
        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - initialMouseLocation.x
        let deltaY = currentMouse.y - initialMouseLocation.y

        var newFrame = initialFrame

        switch resizeEdge {
        case .none:
            return

        case .right:
            newFrame.size.width = initialFrame.width + deltaX

        case .left:
            newFrame.size.width = initialFrame.width - deltaX
            newFrame.origin.x = initialFrame.origin.x + deltaX

        case .top:
            newFrame.size.height = initialFrame.height + deltaY

        case .bottom:
            newFrame.size.height = initialFrame.height - deltaY
            newFrame.origin.y = initialFrame.origin.y + deltaY

        case .topRight:
            newFrame.size.width = initialFrame.width + deltaX
            newFrame.size.height = initialFrame.height + deltaY

        case .topLeft:
            newFrame.size.width = initialFrame.width - deltaX
            newFrame.size.height = initialFrame.height + deltaY
            newFrame.origin.x = initialFrame.origin.x + deltaX

        case .bottomRight:
            newFrame.size.width = initialFrame.width + deltaX
            newFrame.size.height = initialFrame.height - deltaY
            newFrame.origin.y = initialFrame.origin.y + deltaY

        case .bottomLeft:
            newFrame.size.width = initialFrame.width - deltaX
            newFrame.size.height = initialFrame.height - deltaY
            newFrame.origin.x = initialFrame.origin.x + deltaX
            newFrame.origin.y = initialFrame.origin.y + deltaY
        }

        // Enforce aspect ratio
        newFrame = enforceAspectRatio(for: newFrame, basedOn: resizeEdge)

        // Enforce size limits
        newFrame = enforceSizeLimits(for: newFrame)

        setFrame(newFrame, display: true, animate: false)
    }

    private func enforceAspectRatio(for rect: NSRect, basedOn edge: ResizeEdge) -> NSRect {
        var newRect = rect
        let ratio = Self.aspectRatio

        switch edge {
        case .left, .right:
            // Width changed, adjust height
            newRect.size.height = newRect.width / ratio

        case .top, .bottom:
            // Height changed, adjust width
            newRect.size.width = newRect.height * ratio

        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            // Corner resize - use the larger dimension change
            let widthFromHeight = newRect.height * ratio
            let heightFromWidth = newRect.width / ratio

            if abs(newRect.width - initialFrame.width) > abs(newRect.height - initialFrame.height) {
                newRect.size.height = heightFromWidth
            } else {
                newRect.size.width = widthFromHeight
            }

        case .none:
            break
        }

        return newRect
    }

    private func enforceSizeLimits(for rect: NSRect) -> NSRect {
        var newRect = rect

        // Enforce minimum size
        if newRect.width < Self.minSize.width {
            newRect.size.width = Self.minSize.width
            newRect.size.height = Self.minSize.width / Self.aspectRatio
        }
        if newRect.height < Self.minSize.height {
            newRect.size.height = Self.minSize.height
            newRect.size.width = Self.minSize.height * Self.aspectRatio
        }

        // Enforce maximum size
        if newRect.width > Self.maxSize.width {
            newRect.size.width = Self.maxSize.width
            newRect.size.height = Self.maxSize.width / Self.aspectRatio
        }
        if newRect.height > Self.maxSize.height {
            newRect.size.height = Self.maxSize.height
            newRect.size.width = Self.maxSize.height * Self.aspectRatio
        }

        return newRect
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

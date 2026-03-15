# YouTube Video Player for macOS Notch App - Technical Implementation Guide

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [WKWebView vs AVPlayer Comparison](#wkwebview-vs-avplayer-comparison)
3. [YouTube Embedding Approaches](#youtube-embedding-approaches)
4. [Implementation Code](#implementation-code)
5. [Resizable Floating Window](#resizable-floating-window)
6. [Picture-in-Picture](#picture-in-picture)
7. [Keyboard Shortcuts](#keyboard-shortcuts)
8. [Complete Integration](#complete-integration)

---

## Architecture Overview

For a macOS notch app YouTube player, the recommended architecture is:

```
┌─────────────────────────────────────────────────────────────┐
│                     NotchPanel (NSPanel)                    │
│  - Starts as notch overlay                                  │
│  - Transforms into resizable video window                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              VideoPlayerPanel (Custom NSPanel)              │
│  - Floating, resizable, draggable                           │
│  - Contains WKWebView with YouTube iframe                   │
│  - Supports PiP via native macOS controls                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│            YouTubePlayerView (SwiftUI + WKWebView)          │
│  - Handles YouTube iframe API                               │
│  - JavaScript bridge for controls                           │
│  - URL parsing and video ID extraction                      │
└─────────────────────────────────────────────────────────────┘
```

---

## WKWebView vs AVPlayer Comparison

### WKWebView Approach (RECOMMENDED for YouTube)

| Aspect | Details |
|--------|---------|
| **Pros** | Full YouTube player features, official iframe API, no API key needed, adaptive streaming works automatically |
| **Cons** | Limited native control, relies on web rendering, slightly higher memory usage |
| **Best For** | YouTube videos (primary recommendation) |

### AVPlayer Approach

| Aspect | Details |
|--------|---------|
| **Pros** | Native macOS integration, better PiP support, lower-level control |
| **Cons** | Cannot play YouTube directly (no direct stream URLs), requires third-party extraction which violates YouTube ToS |
| **Best For** | Local videos, HLS streams, non-YouTube content |

**Verdict**: Use **WKWebView with YouTube iframe API** for legal, full-featured YouTube playback.

---

## YouTube Embedding Approaches

### 1. YouTube IFrame API (Recommended)

```swift
let html = """
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * { margin: 0; padding: 0; }
        body { background: #000; overflow: hidden; }
        #player { width: 100vw; height: 100vh; }
    </style>
</head>
<body>
    <div id="player"></div>
    <script>
        var tag = document.createElement('script');
        tag.src = "https://www.youtube.com/iframe_api";
        var firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

        var player;
        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                videoId: '\(videoID)',
                playerVars: {
                    'autoplay': 1,
                    'controls': 1,
                    'modestbranding': 1,
                    'rel': 0,
                    'playsinline': 1,
                    'enablejsapi': 1
                },
                events: {
                    'onReady': onPlayerReady,
                    'onStateChange': onPlayerStateChange
                }
            });
        }

        function onPlayerReady(event) {
            event.target.playVideo();
            window.webkit.messageHandlers.playerReady.postMessage({
                duration: player.getDuration()
            });
        }

        function onPlayerStateChange(event) {
            window.webkit.messageHandlers.stateChange.postMessage({
                state: event.data
            });
        }

        // Control functions callable from Swift
        function playVideo() { player.playVideo(); }
        function pauseVideo() { player.pauseVideo(); }
        function seekTo(seconds) { player.seekTo(seconds, true); }
        function setVolume(volume) { player.setVolume(volume); }
        function mute() { player.mute(); }
        function unmute() { player.unMute(); }
    </script>
</body>
</html>
"""
```

### 2. Direct Embed URL (Simpler but less control)

```swift
let embedURL = "https://www.youtube.com/embed/\(videoID)?autoplay=1&controls=1&modestbranding=1"
```

### 3. YouTube oEmbed API (For metadata only)

```swift
// Useful for getting video info before loading
let oEmbedURL = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoID)&format=json"
```

---

## Implementation Code

### 1. YouTube URL Parser

```swift
import Foundation

struct YouTubeURLParser {
    /// Extracts video ID from various YouTube URL formats
    /// - Supports: youtube.com/watch?v=, youtu.be/, youtube.com/embed/, youtube.com/v/
    static func extractVideoID(from urlString: String) -> String? {
        // Clean the input
        let cleanedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern 1: youtube.com/watch?v=VIDEO_ID
        if let url = URL(string: cleanedURL),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return validateVideoID(videoID)
        }
        
        // Pattern 2: youtu.be/VIDEO_ID
        if cleanedURL.contains("youtu.be/") {
            let pattern = #"youtu\.be\/([a-zA-Z0-9_-]{11})"#
            if let match = cleanedURL.range(of: pattern, options: .regularExpression) {
                let startIndex = cleanedURL.index(match.lowerBound, offsetBy: 9)
                let videoID = String(cleanedURL[startIndex..<cleanedURL.index(startIndex, offsetBy: 11)])
                return validateVideoID(videoID)
            }
        }
        
        // Pattern 3: youtube.com/embed/VIDEO_ID
        if cleanedURL.contains("/embed/") {
            let pattern = #"\/embed\/([a-zA-Z0-9_-]{11})"#
            if let match = cleanedURL.range(of: pattern, options: .regularExpression) {
                let startIndex = cleanedURL.index(match.lowerBound, offsetBy: 7)
                let videoID = String(cleanedURL[startIndex..<cleanedURL.index(startIndex, offsetBy: 11)])
                return validateVideoID(videoID)
            }
        }
        
        // Pattern 4: youtube.com/v/VIDEO_ID
        if cleanedURL.contains("/v/") {
            let pattern = #"\/v\/([a-zA-Z0-9_-]{11})"#
            if let match = cleanedURL.range(of: pattern, options: .regularExpression) {
                let startIndex = cleanedURL.index(match.lowerBound, offsetBy: 3)
                let videoID = String(cleanedURL[startIndex..<cleanedURL.index(startIndex, offsetBy: 11)])
                return validateVideoID(videoID)
            }
        }
        
        // Pattern 5: Just a video ID (11 characters)
        if cleanedURL.count == 11 {
            return validateVideoID(cleanedURL)
        }
        
        return nil
    }
    
    /// Validates that a video ID matches YouTube's format
    private static func validateVideoID(_ id: String) -> String? {
        let pattern = #"^[a-zA-Z0-9_-]{11}$"#
        return id.range(of: pattern, options: .regularExpression) != nil ? id : nil
    }
    
    /// Fetches video metadata using oEmbed API
    static func fetchVideoMetadata(videoID: String) async throws -> YouTubeVideoMetadata {
        let urlString = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoID)&format=json"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(YouTubeVideoMetadata.self, from: data)
    }
}

struct YouTubeVideoMetadata: Codable {
    let title: String
    let authorName: String
    let authorURL: String
    let thumbnailURL: String
    let thumbnailWidth: Int
    let thumbnailHeight: Int
    
    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case authorURL = "author_url"
        case thumbnailURL = "thumbnail_url"
        case thumbnailWidth = "thumbnail_width"
        case thumbnailHeight = "thumbnail_height"
    }
}
```

### 2. WKWebView YouTube Player (SwiftUI + AppKit)

```swift
import SwiftUI
import WebKit

// MARK: - YouTube Player State
@MainActor
class YouTubePlayerState: ObservableObject {
    @Published var isPlaying = false
    @Published var isReady = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 100
    @Published var isMuted = false
    @Published var videoID: String = ""
    @Published var error: String?
}

// MARK: - WKWebView Representable for macOS
struct YouTubePlayerWebView: NSViewRepresentable {
    let videoID: String
    @ObservedObject var state: YouTubePlayerState
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Enable fullscreen for videos
        configuration.preferences.setValue(true, forKey: "fullScreenEnabled")
        
        // Add message handlers for JavaScript communication
        let contentController = configuration.userContentController
        contentController.add(context.coordinator, name: "playerReady")
        contentController.add(context.coordinator, name: "stateChange")
        contentController.add(context.coordinator, name: "timeUpdate")
        contentController.add(context.coordinator, name: "error")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        
        // Make web view inspectable for debugging
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        
        // Load the YouTube player
        loadYouTubePlayer(webView: webView, videoID: videoID)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Handle video ID changes
        if state.videoID != videoID {
            state.videoID = videoID
            loadYouTubePlayer(webView: webView, videoID: videoID)
        }
    }
    
    private func loadYouTubePlayer(webView: WKWebView, videoID: String) {
        let html = generateYouTubeHTML(videoID: videoID)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }
    
    private func generateYouTubeHTML(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { 
                    width: 100%; 
                    height: 100%; 
                    background: #000; 
                    overflow: hidden;
                }
                #player {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                }
                iframe {
                    width: 100%;
                    height: 100%;
                    border: none;
                }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

                var player;
                var timeUpdateInterval;
                
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        videoId: '\(videoID)',
                        playerVars: {
                            'autoplay': 1,
                            'controls': 1,
                            'modestbranding': 1,
                            'rel': 0,
                            'playsinline': 1,
                            'enablejsapi': 1,
                            'origin': 'https://www.youtube.com',
                            'fs': 1
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError
                        }
                    });
                }

                function onPlayerReady(event) {
                    event.target.playVideo();
                    window.webkit.messageHandlers.playerReady.postMessage({
                        duration: player.getDuration(),
                        volume: player.getVolume()
                    });
                    
                    // Start time updates
                    timeUpdateInterval = setInterval(function() {
                        if (player && player.getCurrentTime) {
                            window.webkit.messageHandlers.timeUpdate.postMessage({
                                currentTime: player.getCurrentTime(),
                                duration: player.getDuration()
                            });
                        }
                    }, 500);
                }

                function onPlayerStateChange(event) {
                    var states = {
                        '-1': 'unstarted',
                        '0': 'ended',
                        '1': 'playing',
                        '2': 'paused',
                        '3': 'buffering',
                        '5': 'cued'
                    };
                    window.webkit.messageHandlers.stateChange.postMessage({
                        state: event.data,
                        stateName: states[event.data] || 'unknown'
                    });
                }
                
                function onPlayerError(event) {
                    var errors = {
                        '2': 'Invalid video ID',
                        '5': 'HTML5 player error',
                        '100': 'Video not found',
                        '101': 'Video not embeddable',
                        '150': 'Video not embeddable'
                    };
                    window.webkit.messageHandlers.error.postMessage({
                        code: event.data,
                        message: errors[event.data] || 'Unknown error'
                    });
                }

                // Control functions callable from Swift
                function playVideo() { 
                    if (player) player.playVideo(); 
                }
                
                function pauseVideo() { 
                    if (player) player.pauseVideo(); 
                }
                
                function togglePlayPause() {
                    if (player) {
                        var state = player.getPlayerState();
                        if (state === 1) {
                            player.pauseVideo();
                        } else {
                            player.playVideo();
                        }
                    }
                }
                
                function seekTo(seconds) { 
                    if (player) player.seekTo(seconds, true); 
                }
                
                function seekRelative(delta) {
                    if (player) {
                        var current = player.getCurrentTime();
                        player.seekTo(current + delta, true);
                    }
                }
                
                function setVolume(volume) { 
                    if (player) player.setVolume(volume); 
                }
                
                function changeVolume(delta) {
                    if (player) {
                        var current = player.getVolume();
                        var newVolume = Math.max(0, Math.min(100, current + delta));
                        player.setVolume(newVolume);
                    }
                }
                
                function mute() { 
                    if (player) player.mute(); 
                }
                
                function unmute() { 
                    if (player) player.unMute(); 
                }
                
                function toggleMute() {
                    if (player) {
                        if (player.isMuted()) {
                            player.unMute();
                        } else {
                            player.mute();
                        }
                    }
                }
                
                function loadVideo(videoId) {
                    if (player) player.loadVideoById(videoId);
                }
                
                function setPlaybackRate(rate) {
                    if (player) player.setPlaybackRate(rate);
                }
            </script>
        </body>
        </html>
        """
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var state: YouTubePlayerState
        
        init(state: YouTubePlayerState) {
            self.state = state
        }
        
        // MARK: - WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            Task { @MainActor in
                switch message.name {
                case "playerReady":
                    state.isReady = true
                    if let duration = body["duration"] as? Double {
                        state.duration = duration
                    }
                    if let volume = body["volume"] as? Double {
                        state.volume = volume
                    }
                    
                case "stateChange":
                    if let stateCode = body["state"] as? Int {
                        state.isPlaying = (stateCode == 1)
                    }
                    
                case "timeUpdate":
                    if let currentTime = body["currentTime"] as? Double {
                        state.currentTime = currentTime
                    }
                    if let duration = body["duration"] as? Double {
                        state.duration = duration
                    }
                    
                case "error":
                    if let message = body["message"] as? String {
                        state.error = message
                    }
                    
                default:
                    break
                }
            }
        }
        
        // MARK: - WKUIDelegate
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle popup requests (fullscreen, etc.)
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

// MARK: - YouTube Player SwiftUI View
struct YouTubePlayerView: View {
    let videoID: String
    @StateObject private var playerState = YouTubePlayerState()
    
    var body: some View {
        ZStack {
            Color.black
            
            YouTubePlayerWebView(videoID: videoID, state: playerState)
                .aspectRatio(16/9, contentMode: .fit)
            
            if !playerState.isReady {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
            }
            
            if let error = playerState.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
    }
}
```

### 3. Video Player Controller (For JavaScript Bridge)

```swift
import WebKit

@MainActor
class YouTubePlayerController: ObservableObject {
    weak var webView: WKWebView?
    
    func play() {
        evaluateScript("playVideo()")
    }
    
    func pause() {
        evaluateScript("pauseVideo()")
    }
    
    func togglePlayPause() {
        evaluateScript("togglePlayPause()")
    }
    
    func seek(to seconds: Double) {
        evaluateScript("seekTo(\(seconds))")
    }
    
    func seekRelative(_ delta: Double) {
        evaluateScript("seekRelative(\(delta))")
    }
    
    func setVolume(_ volume: Double) {
        evaluateScript("setVolume(\(volume))")
    }
    
    func changeVolume(_ delta: Double) {
        evaluateScript("changeVolume(\(delta))")
    }
    
    func mute() {
        evaluateScript("mute()")
    }
    
    func unmute() {
        evaluateScript("unmute()")
    }
    
    func toggleMute() {
        evaluateScript("toggleMute()")
    }
    
    func loadVideo(_ videoID: String) {
        evaluateScript("loadVideo('\(videoID)')")
    }
    
    func setPlaybackRate(_ rate: Double) {
        evaluateScript("setPlaybackRate(\(rate))")
    }
    
    private func evaluateScript(_ script: String) {
        webView?.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("JavaScript error: \(error.localizedDescription)")
            }
        }
    }
}
```

---

## Resizable Floating Window

### Custom Video Panel (Extending from Notch)

```swift
import AppKit
import SwiftUI

// MARK: - Video Player Panel
final class VideoPlayerPanel: NSPanel {
    
    private var initialMouseLocation: NSPoint = .zero
    private var initialFrame: NSRect = .zero
    private var resizeEdge: ResizeEdge = .none
    private let resizeMargin: CGFloat = 8
    
    enum ResizeEdge {
        case none
        case left, right, top, bottom
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable, .utilityWindow],
            backing: backing,
            defer: flag
        )
        
        configurePanel()
    }
    
    private func configurePanel() {
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        
        // Allow moving by dragging anywhere
        isMovableByWindowBackground = true
        
        // Collection behavior for spaces
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Allow resizing
        minSize = NSSize(width: 320, height: 180)
        maxSize = NSSize(width: 1920, height: 1080)
        
        // Aspect ratio constraint (16:9)
        aspectRatio = NSSize(width: 16, height: 9)
        
        // Animate resize
        animationBehavior = .utilityWindow
    }
    
    // Keep panel floating but allow interaction
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    // MARK: - Custom Resize Handling
    
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        resizeEdge = detectResizeEdge(at: location)
        
        if resizeEdge != .none {
            initialMouseLocation = NSEvent.mouseLocation
            initialFrame = frame
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard resizeEdge != .none else {
            super.mouseDragged(with: event)
            return
        }
        
        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - initialMouseLocation.x
        let deltaY = currentLocation.y - initialMouseLocation.y
        
        var newFrame = initialFrame
        
        switch resizeEdge {
        case .right:
            newFrame.size.width = max(minSize.width, initialFrame.width + deltaX)
        case .left:
            let newWidth = max(minSize.width, initialFrame.width - deltaX)
            newFrame.origin.x = initialFrame.maxX - newWidth
            newFrame.size.width = newWidth
        case .top:
            newFrame.size.height = max(minSize.height, initialFrame.height + deltaY)
        case .bottom:
            let newHeight = max(minSize.height, initialFrame.height - deltaY)
            newFrame.origin.y = initialFrame.maxY - newHeight
            newFrame.size.height = newHeight
        case .bottomRight:
            newFrame.size.width = max(minSize.width, initialFrame.width + deltaX)
            let newHeight = max(minSize.height, initialFrame.height - deltaY)
            newFrame.origin.y = initialFrame.maxY - newHeight
            newFrame.size.height = newHeight
        case .bottomLeft:
            let newWidth = max(minSize.width, initialFrame.width - deltaX)
            newFrame.origin.x = initialFrame.maxX - newWidth
            newFrame.size.width = newWidth
            let newHeight = max(minSize.height, initialFrame.height - deltaY)
            newFrame.origin.y = initialFrame.maxY - newHeight
            newFrame.size.height = newHeight
        case .topRight:
            newFrame.size.width = max(minSize.width, initialFrame.width + deltaX)
            newFrame.size.height = max(minSize.height, initialFrame.height + deltaY)
        case .topLeft:
            let newWidth = max(minSize.width, initialFrame.width - deltaX)
            newFrame.origin.x = initialFrame.maxX - newWidth
            newFrame.size.width = newWidth
            newFrame.size.height = max(minSize.height, initialFrame.height + deltaY)
        case .none:
            break
        }
        
        // Maintain aspect ratio
        if aspectRatio.width > 0 && aspectRatio.height > 0 {
            let ratio = aspectRatio.width / aspectRatio.height
            newFrame.size.height = newFrame.size.width / ratio
        }
        
        setFrame(newFrame, display: true, animate: false)
    }
    
    override func mouseUp(with event: NSEvent) {
        resizeEdge = .none
        super.mouseUp(with: event)
    }
    
    private func detectResizeEdge(at point: NSPoint) -> ResizeEdge {
        let bounds = contentView?.bounds ?? .zero
        let margin = resizeMargin
        
        let nearLeft = point.x < margin
        let nearRight = point.x > bounds.width - margin
        let nearTop = point.y > bounds.height - margin
        let nearBottom = point.y < margin
        
        if nearTop && nearLeft { return .topLeft }
        if nearTop && nearRight { return .topRight }
        if nearBottom && nearLeft { return .bottomLeft }
        if nearBottom && nearRight { return .bottomRight }
        if nearLeft { return .left }
        if nearRight { return .right }
        if nearTop { return .top }
        if nearBottom { return .bottom }
        
        return .none
    }
    
    // MARK: - Cursor Updates
    
    override func mouseMoved(with event: NSEvent) {
        let location = event.locationInWindow
        let edge = detectResizeEdge(at: location)
        
        switch edge {
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .topLeft, .bottomRight:
            NSCursor.crosshair.set() // macOS doesn't have diagonal cursors by default
        case .topRight, .bottomLeft:
            NSCursor.crosshair.set()
        case .none:
            NSCursor.arrow.set()
        }
        
        super.mouseMoved(with: event)
    }
}

// MARK: - Video Window Manager
@MainActor
final class VideoWindowManager: ObservableObject {
    static let shared = VideoWindowManager()
    
    private var videoPanel: VideoPlayerPanel?
    @Published var isShowing = false
    @Published var currentVideoID: String?
    
    private init() {}
    
    func showVideo(videoID: String, fromNotchPosition: NSPoint? = nil) {
        // Close existing panel
        hideVideo()
        
        // Calculate initial position (expanding from notch)
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let initialSize = NSSize(width: 480, height: 270) // 16:9 aspect ratio
        
        var position: NSPoint
        if let notchPos = fromNotchPosition {
            // Position below the notch
            position = NSPoint(
                x: notchPos.x - initialSize.width / 2,
                y: notchPos.y - initialSize.height - 20
            )
        } else {
            // Center of screen, below notch area
            let notchHeight = screen.safeAreaInsets.top
            position = NSPoint(
                x: (screen.frame.width - initialSize.width) / 2,
                y: screen.frame.height - notchHeight - initialSize.height - 20
            )
        }
        
        let contentRect = NSRect(origin: position, size: initialSize)
        
        // Create panel
        let panel = VideoPlayerPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: true
        )
        
        // Create SwiftUI content
        let playerView = VideoPlayerContentView(videoID: videoID, windowManager: self)
        let hostingView = NSHostingView(rootView: playerView)
        panel.contentView = hostingView
        
        // Animate in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        
        self.videoPanel = panel
        self.isShowing = true
        self.currentVideoID = videoID
    }
    
    func hideVideo() {
        guard let panel = videoPanel else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
            self.videoPanel = nil
        }
        
        isShowing = false
        currentVideoID = nil
    }
    
    func toggleVisibility() {
        if isShowing {
            hideVideo()
        } else if let videoID = currentVideoID {
            showVideo(videoID: videoID)
        }
    }
}

// MARK: - Video Player Content View
struct VideoPlayerContentView: View {
    let videoID: String
    @ObservedObject var windowManager: VideoWindowManager
    @StateObject private var playerState = YouTubePlayerState()
    
    var body: some View {
        ZStack {
            // Rounded corners background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
            
            // YouTube player
            YouTubePlayerWebView(videoID: videoID, state: playerState)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: { windowManager.hideVideo() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .opacity(playerState.isReady ? 1 : 0)
                }
                Spacer()
            }
            
            // Loading indicator
            if !playerState.isReady {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
            }
        }
    }
}
```

### Drag Handle View for Custom Resizing

```swift
import SwiftUI

struct ResizeHandleView: View {
    let edge: VideoPlayerPanel.ResizeEdge
    let size: CGFloat = 16
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(
                width: isHorizontal ? nil : size,
                height: isHorizontal ? size : nil
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    setCursor()
                } else {
                    NSCursor.arrow.set()
                }
            }
    }
    
    private var isHorizontal: Bool {
        edge == .top || edge == .bottom
    }
    
    private func setCursor() {
        switch edge {
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        default:
            NSCursor.arrow.set()
        }
    }
}
```

---

## Picture-in-Picture

### Native PiP Implementation for macOS

**Note**: WKWebView with YouTube iframe doesn't directly support AVPictureInPictureController. However, YouTube's native PiP button works within WKWebView when the user enters fullscreen mode.

For native PiP with AVPlayer (non-YouTube content):

```swift
import AVKit
import AVFoundation

@MainActor
class PiPVideoController: NSObject, ObservableObject {
    private var playerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?
    @Published var isPiPActive = false
    @Published var isPiPPossible = false
    
    func setupPiP(with playerLayer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP not supported on this device")
            return
        }
        
        self.playerLayer = playerLayer
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        
        // Observe PiP possibility
        pipController?.addObserver(self, forKeyPath: "isPictureInPicturePossible", options: [.new], context: nil)
    }
    
    func startPiP() {
        guard let pipController = pipController, pipController.isPictureInPicturePossible else {
            return
        }
        pipController.startPictureInPicture()
    }
    
    func stopPiP() {
        pipController?.stopPictureInPicture()
    }
    
    func togglePiP() {
        if isPiPActive {
            stopPiP()
        } else {
            startPiP()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "isPictureInPicturePossible" {
            Task { @MainActor in
                isPiPPossible = pipController?.isPictureInPicturePossible ?? false
            }
        }
    }
    
    deinit {
        pipController?.removeObserver(self, forKeyPath: "isPictureInPicturePossible")
    }
}

extension PiPVideoController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed to start: \(error.localizedDescription)")
        isPiPActive = false
    }
}
```

### WKWebView PiP Workaround

Since WKWebView doesn't directly expose PiP controls, you can inject JavaScript to trigger YouTube's native PiP:

```swift
// Inject this to enable YouTube's native PiP button
let pipScript = """
// Find the video element and request PiP
var video = document.querySelector('video');
if (video && document.pictureInPictureEnabled) {
    video.requestPictureInPicture().catch(console.error);
}
"""

// Call this from Swift
webView.evaluateJavaScript(pipScript) { result, error in
    if let error = error {
        print("PiP script error: \(error)")
    }
}
```

---

## Keyboard Shortcuts

### Global Keyboard Event Monitor

```swift
import AppKit
import Carbon.HIToolbox

@MainActor
class VideoKeyboardManager: ObservableObject {
    private var eventMonitor: Any?
    weak var playerController: YouTubePlayerController?
    
    func startMonitoring() {
        // Local event monitor (when app is focused)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume the event
            }
            return event
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let controller = playerController else { return false }
        
        // Check for modifier keys
        let hasCommand = event.modifierFlags.contains(.command)
        let hasShift = event.modifierFlags.contains(.shift)
        let hasOption = event.modifierFlags.contains(.option)
        
        switch event.keyCode {
        case UInt16(kVK_Space):
            // Space: Play/Pause
            controller.togglePlayPause()
            return true
            
        case UInt16(kVK_LeftArrow):
            if hasCommand {
                // Cmd+Left: Go to beginning
                controller.seek(to: 0)
            } else if hasShift {
                // Shift+Left: -10 seconds
                controller.seekRelative(-10)
            } else {
                // Left: -5 seconds
                controller.seekRelative(-5)
            }
            return true
            
        case UInt16(kVK_RightArrow):
            if hasCommand {
                // Cmd+Right: Go to end (let video handle)
                return false
            } else if hasShift {
                // Shift+Right: +10 seconds
                controller.seekRelative(10)
            } else {
                // Right: +5 seconds
                controller.seekRelative(5)
            }
            return true
            
        case UInt16(kVK_UpArrow):
            // Up: Volume up
            controller.changeVolume(10)
            return true
            
        case UInt16(kVK_DownArrow):
            // Down: Volume down
            controller.changeVolume(-10)
            return true
            
        case UInt16(kVK_ANSI_M):
            // M: Toggle mute
            controller.toggleMute()
            return true
            
        case UInt16(kVK_ANSI_F):
            if hasCommand {
                // Cmd+F: Toggle fullscreen (handled by webview)
                return false
            }
            return false
            
        case UInt16(kVK_Escape):
            // Escape: Close video window
            VideoWindowManager.shared.hideVideo()
            return true
            
        case UInt16(kVK_ANSI_Period):
            if hasShift {
                // >: Increase playback speed
                controller.setPlaybackRate(1.5)
            }
            return true
            
        case UInt16(kVK_ANSI_Comma):
            if hasShift {
                // <: Decrease playback speed
                controller.setPlaybackRate(0.75)
            }
            return true
            
        case UInt16(kVK_ANSI_0):
            // 0: Reset playback speed
            controller.setPlaybackRate(1.0)
            return true
            
        default:
            // Number keys 1-9: Seek to percentage
            if event.keyCode >= UInt16(kVK_ANSI_1) && event.keyCode <= UInt16(kVK_ANSI_9) {
                let percentage = Double(event.keyCode - UInt16(kVK_ANSI_1) + 1) * 10
                // Would need duration from playerState to calculate
                return true
            }
            return false
        }
    }
}
```

### Keyboard Shortcut Reference

| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause |
| `←` | Seek -5 seconds |
| `→` | Seek +5 seconds |
| `Shift + ←` | Seek -10 seconds |
| `Shift + →` | Seek +10 seconds |
| `Cmd + ←` | Go to beginning |
| `↑` | Volume up |
| `↓` | Volume down |
| `M` | Toggle mute |
| `>` | Speed up (1.5x) |
| `<` | Slow down (0.75x) |
| `0` | Normal speed (1x) |
| `Esc` | Close video |
| `1-9` | Seek to 10%-90% |

---

## Complete Integration

### Integration with Existing Notch App

```swift
import SwiftUI

// MARK: - Add to NotchState
extension NotchState {
    @Published var videoURL: String?
    @Published var isVideoExpanded = false
}

// MARK: - Notch Video Trigger View
struct NotchVideoTriggerView: View {
    @ObservedObject var state: NotchState
    @State private var urlInput = ""
    @State private var showURLInput = false
    
    var body: some View {
        HStack(spacing: 8) {
            // YouTube icon
            Button(action: { showURLInput.toggle() }) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            
            if showURLInput {
                TextField("Paste YouTube URL", text: $urlInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 150)
                    .onSubmit {
                        if let videoID = YouTubeURLParser.extractVideoID(from: urlInput) {
                            VideoWindowManager.shared.showVideo(videoID: videoID)
                            urlInput = ""
                            showURLInput = false
                        }
                    }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - App Entry Point Addition
extension MyDynamicIslandApp {
    static func setupVideoKeyboardShortcuts() {
        // Register global hotkey for video player
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // Cmd+Shift+Y: Show/Hide video
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 16 { // Y key
                Task { @MainActor in
                    VideoWindowManager.shared.toggleVisibility()
                }
            }
        }
    }
}
```

### Usage Example

```swift
// In your notch view or menu bar
Button("Play YouTube Video") {
    // From URL
    if let videoID = YouTubeURLParser.extractVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") {
        VideoWindowManager.shared.showVideo(videoID: videoID)
    }
    
    // Or directly with video ID
    VideoWindowManager.shared.showVideo(videoID: "dQw4w9WgXcQ")
}
```

---

## Summary

### Key Implementation Decisions

1. **Use WKWebView + YouTube iframe API** - Legal, full-featured, automatic quality adjustment
2. **Custom NSPanel for floating window** - Extends above other windows, proper macOS integration
3. **JavaScript bridge** - Full control over YouTube player from Swift
4. **Manual resize handling** - More control than standard window resize for notch integration
5. **Aspect ratio constraint** - Maintains 16:9 during resize

### Files to Create

1. `YouTubeURLParser.swift` - URL parsing utility
2. `YouTubePlayerWebView.swift` - WKWebView + SwiftUI bridge
3. `YouTubePlayerController.swift` - JavaScript control bridge
4. `VideoPlayerPanel.swift` - Custom resizable NSPanel
5. `VideoWindowManager.swift` - Window lifecycle management
6. `VideoKeyboardManager.swift` - Keyboard shortcuts

### Required Frameworks

```swift
import SwiftUI
import WebKit
import AVKit          // For PiP (non-YouTube)
import Carbon.HIToolbox // For keyboard codes
```

### Info.plist Requirements

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
```

### Testing Checklist

- [ ] YouTube URL parsing (all formats)
- [ ] Video loads and autoplays
- [ ] Play/pause controls work
- [ ] Volume controls work
- [ ] Seek controls work
- [ ] Window dragging works
- [ ] Window resizing maintains aspect ratio
- [ ] Keyboard shortcuts function
- [ ] Window stays above other windows
- [ ] Close button dismisses window
- [ ] Memory is released when window closes

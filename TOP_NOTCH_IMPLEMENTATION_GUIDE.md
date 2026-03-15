# Top Notch - Complete Implementation Guide

> **App Name:** Top Notch  
> **Version:** 2.0  
> **Date:** March 2026  
> **Based on Latest Apple Guidelines:** February 6, 2026

---

## 📋 Executive Summary

This guide covers everything needed to take the current NotchMac app to the next level by adding:
1. **YouTube Video Player** - Embedded in/expanding from the notch
2. **Resizable Floating Window** - Drag handles, snap presets, position memory
3. **Enhanced Settings** - YouTube player preferences, global hotkeys
4. **App Store/Distribution** - Requirements and strategy

### ⚠️ CRITICAL FINDING: Distribution Strategy

| Path | Recommendation | Reason |
|------|----------------|--------|
| **Mac App Store** | ❌ NOT POSSIBLE | Uses private APIs (SkyLight, MediaRemote) |
| **Notarized Direct Distribution** | ✅ RECOMMENDED | Full functionality preserved |
| **Platforms** | Gumroad, Paddle, Lemon Squeezy, Your Website | 5-10% commission |

The app uses private frameworks that will be **immediately rejected** by App Store Review:
- `SkyLight.framework` - Lock screen visibility
- `MediaRemote.framework` - Now playing detection
- `DisplayServices.framework` - Brightness control
- `CGEvent.tapCreate()` - Media key interception (incompatible with sandbox)

---

## 🎬 Part 1: YouTube Video Player Implementation

### 1.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     NotchPanel (existing)                   │
│  - Detects tap/URL paste → opens video player               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              VideoPlayerPanel (new NSPanel)                 │
│  - Floating, resizable, draggable                           │
│  - Expands from notch position with spring animation        │
│  - 16:9 aspect ratio enforcement                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│            YouTubePlayerView (WKWebView + SwiftUI)          │
│  - YouTube iframe API for legal playback                    │
│  - JavaScript bridge for Swift ↔ player communication       │
│  - Picture-in-Picture support                               │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Create New File: `YouTubeURLParser.swift`

```swift
import Foundation

struct YouTubeURLParser {
    /// Extracts video ID from various YouTube URL formats
    /// Supports: youtube.com/watch?v=, youtu.be/, /embed/, /v/, raw IDs
    static func extractVideoID(from urlString: String) -> String? {
        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern 1: youtube.com/watch?v=VIDEO_ID
        if let url = URL(string: cleaned),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return validateVideoID(videoID)
        }
        
        // Pattern 2: youtu.be/VIDEO_ID
        if cleaned.contains("youtu.be/") {
            let pattern = #"youtu\.be\/([a-zA-Z0-9_-]{11})"#
            if let match = cleaned.range(of: pattern, options: .regularExpression) {
                let startIndex = cleaned.index(match.lowerBound, offsetBy: 9)
                let videoID = String(cleaned[startIndex..<cleaned.index(startIndex, offsetBy: 11)])
                return validateVideoID(videoID)
            }
        }
        
        // Pattern 3: /embed/VIDEO_ID
        if cleaned.contains("/embed/") {
            let pattern = #"\/embed\/([a-zA-Z0-9_-]{11})"#
            if let match = cleaned.range(of: pattern, options: .regularExpression) {
                let startIndex = cleaned.index(match.lowerBound, offsetBy: 7)
                let videoID = String(cleaned[startIndex..<cleaned.index(startIndex, offsetBy: 11)])
                return validateVideoID(videoID)
            }
        }
        
        // Pattern 4: Just a video ID (11 characters)
        if cleaned.count == 11 { return validateVideoID(cleaned) }
        
        return nil
    }
    
    private static func validateVideoID(_ id: String) -> String? {
        let pattern = #"^[a-zA-Z0-9_-]{11}$"#
        return id.range(of: pattern, options: .regularExpression) != nil ? id : nil
    }
    
    /// Fetches video metadata using oEmbed API
    static func fetchMetadata(videoID: String) async throws -> YouTubeMetadata {
        let urlString = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoID)&format=json"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(YouTubeMetadata.self, from: data)
    }
}

struct YouTubeMetadata: Codable {
    let title: String
    let authorName: String
    let thumbnailURL: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case thumbnailURL = "thumbnail_url"
    }
}
```

### 1.3 Create New File: `YouTubePlayerState.swift`

```swift
import SwiftUI

@MainActor
class YouTubePlayerState: ObservableObject {
    @Published var isPlaying = false
    @Published var isReady = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 100
    @Published var isMuted = false
    @Published var videoID: String = ""
    @Published var videoTitle: String = ""
    @Published var error: String?
    @Published var isBuffering = false
}
```

### 1.4 Create New File: `YouTubePlayerWebView.swift`

```swift
import SwiftUI
import WebKit

struct YouTubePlayerWebView: NSViewRepresentable {
    let videoID: String
    @ObservedObject var state: YouTubePlayerState
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.setValue(true, forKey: "fullScreenEnabled")
        
        // JavaScript bridge
        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "playerReady")
        contentController.add(context.coordinator, name: "stateChange")
        contentController.add(context.coordinator, name: "timeUpdate")
        contentController.add(context.coordinator, name: "error")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        if #available(macOS 13.3, *) { webView.isInspectable = true }
        
        loadPlayer(webView: webView, videoID: videoID)
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if state.videoID != videoID {
            state.videoID = videoID
            loadPlayer(webView: webView, videoID: videoID)
        }
    }
    
    private func loadPlayer(webView: WKWebView, videoID: String) {
        let html = generateHTML(videoID: videoID)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }
    
    private func generateHTML(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; }
                html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                #player { width: 100%; height: 100%; }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                document.getElementsByTagName('script')[0].parentNode.insertBefore(tag, document.getElementsByTagName('script')[0]);

                var player;
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        videoId: '\(videoID)',
                        playerVars: {
                            'autoplay': 1, 'controls': 1, 'modestbranding': 1,
                            'rel': 0, 'playsinline': 1, 'enablejsapi': 1, 'fs': 1
                        },
                        events: {
                            'onReady': function(e) {
                                e.target.playVideo();
                                window.webkit.messageHandlers.playerReady.postMessage({
                                    duration: player.getDuration(),
                                    volume: player.getVolume()
                                });
                                setInterval(function() {
                                    if (player && player.getCurrentTime) {
                                        window.webkit.messageHandlers.timeUpdate.postMessage({
                                            currentTime: player.getCurrentTime(),
                                            duration: player.getDuration()
                                        });
                                    }
                                }, 500);
                            },
                            'onStateChange': function(e) {
                                var states = {'-1':'unstarted','0':'ended','1':'playing','2':'paused','3':'buffering','5':'cued'};
                                window.webkit.messageHandlers.stateChange.postMessage({
                                    state: e.data, stateName: states[e.data]
                                });
                            },
                            'onError': function(e) {
                                var errors = {'2':'Invalid video ID','100':'Video not found','101':'Not embeddable','150':'Not embeddable'};
                                window.webkit.messageHandlers.error.postMessage({
                                    code: e.data, message: errors[e.data] || 'Unknown error'
                                });
                            }
                        }
                    });
                }

                // Swift-callable functions
                function playVideo() { if (player) player.playVideo(); }
                function pauseVideo() { if (player) player.pauseVideo(); }
                function togglePlayPause() { if (player) { player.getPlayerState() === 1 ? player.pauseVideo() : player.playVideo(); } }
                function seekTo(s) { if (player) player.seekTo(s, true); }
                function seekRelative(d) { if (player) player.seekTo(player.getCurrentTime() + d, true); }
                function setVolume(v) { if (player) player.setVolume(v); }
                function mute() { if (player) player.mute(); }
                function unmute() { if (player) player.unMute(); }
                function toggleMute() { if (player) { player.isMuted() ? player.unMute() : player.mute(); } }
                function setPlaybackRate(r) { if (player) player.setPlaybackRate(r); }
            </script>
        </body>
        </html>
        """
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(state: state) }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var state: YouTubePlayerState
        
        init(state: YouTubePlayerState) { self.state = state }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            Task { @MainActor in
                switch message.name {
                case "playerReady":
                    state.isReady = true
                    if let duration = body["duration"] as? Double { state.duration = duration }
                    if let volume = body["volume"] as? Double { state.volume = volume }
                case "stateChange":
                    if let stateCode = body["state"] as? Int {
                        state.isPlaying = stateCode == 1
                        state.isBuffering = stateCode == 3
                    }
                case "timeUpdate":
                    if let currentTime = body["currentTime"] as? Double { state.currentTime = currentTime }
                    if let duration = body["duration"] as? Double { state.duration = duration }
                case "error":
                    if let msg = body["message"] as? String { state.error = msg }
                default: break
                }
            }
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }
    }
}
```

### 1.5 Create New File: `YouTubePlayerController.swift`

```swift
import WebKit

@MainActor
class YouTubePlayerController: ObservableObject {
    weak var webView: WKWebView?
    
    func play() { evaluate("playVideo()") }
    func pause() { evaluate("pauseVideo()") }
    func togglePlayPause() { evaluate("togglePlayPause()") }
    func seek(to seconds: Double) { evaluate("seekTo(\(seconds))") }
    func seekRelative(_ delta: Double) { evaluate("seekRelative(\(delta))") }
    func setVolume(_ volume: Double) { evaluate("setVolume(\(volume))") }
    func mute() { evaluate("mute()") }
    func unmute() { evaluate("unmute()") }
    func toggleMute() { evaluate("toggleMute()") }
    func setPlaybackRate(_ rate: Double) { evaluate("setPlaybackRate(\(rate))") }
    
    private func evaluate(_ script: String) {
        webView?.evaluateJavaScript(script) { _, error in
            if let error = error { print("JS error: \(error.localizedDescription)") }
        }
    }
}
```

### 1.6 Create New File: `VideoPlayerPanel.swift`

```swift
import AppKit
import SwiftUI

final class VideoPlayerPanel: NSPanel {
    private var initialMouseLocation: NSPoint = .zero
    private var initialFrame: NSRect = .zero
    private var resizeEdge: ResizeEdge = .none
    private let resizeMargin: CGFloat = 8
    
    enum ResizeEdge {
        case none, left, right, top, bottom
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel, .resizable, .utilityWindow], backing: backing, defer: flag)
        configure()
    }
    
    private func configure() {
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        minSize = NSSize(width: 320, height: 180)
        maxSize = NSSize(width: 1920, height: 1080)
        aspectRatio = NSSize(width: 16, height: 9)
        animationBehavior = .utilityWindow
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        resizeEdge = detectEdge(at: location)
        if resizeEdge != .none {
            initialMouseLocation = NSEvent.mouseLocation
            initialFrame = frame
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard resizeEdge != .none else { super.mouseDragged(with: event); return }
        
        let current = NSEvent.mouseLocation
        let deltaX = current.x - initialMouseLocation.x
        let deltaY = current.y - initialMouseLocation.y
        
        var newFrame = initialFrame
        let ratio: CGFloat = 16.0 / 9.0
        
        switch resizeEdge {
        case .right:
            newFrame.size.width = max(minSize.width, initialFrame.width + deltaX)
            newFrame.size.height = newFrame.size.width / ratio
        case .left:
            let newWidth = max(minSize.width, initialFrame.width - deltaX)
            newFrame.origin.x = initialFrame.maxX - newWidth
            newFrame.size.width = newWidth
            newFrame.size.height = newWidth / ratio
        case .bottomRight:
            newFrame.size.width = max(minSize.width, initialFrame.width + deltaX)
            newFrame.size.height = newFrame.size.width / ratio
            newFrame.origin.y = initialFrame.maxY - newFrame.size.height
        case .bottomLeft:
            let newWidth = max(minSize.width, initialFrame.width - deltaX)
            newFrame.origin.x = initialFrame.maxX - newWidth
            newFrame.size.width = newWidth
            newFrame.size.height = newWidth / ratio
            newFrame.origin.y = initialFrame.maxY - newFrame.size.height
        default: break
        }
        
        setFrame(newFrame, display: true, animate: false)
    }
    
    override func mouseUp(with event: NSEvent) {
        resizeEdge = .none
        super.mouseUp(with: event)
    }
    
    private func detectEdge(at point: NSPoint) -> ResizeEdge {
        let bounds = contentView?.bounds ?? .zero
        let m = resizeMargin
        
        let nearLeft = point.x < m
        let nearRight = point.x > bounds.width - m
        let nearTop = point.y > bounds.height - m
        let nearBottom = point.y < m
        
        if nearBottom && nearRight { return .bottomRight }
        if nearBottom && nearLeft { return .bottomLeft }
        if nearTop && nearRight { return .topRight }
        if nearTop && nearLeft { return .topLeft }
        if nearLeft { return .left }
        if nearRight { return .right }
        if nearTop { return .top }
        if nearBottom { return .bottom }
        return .none
    }
    
    override func mouseMoved(with event: NSEvent) {
        let edge = detectEdge(at: event.locationInWindow)
        switch edge {
        case .left, .right: NSCursor.resizeLeftRight.set()
        case .top, .bottom: NSCursor.resizeUpDown.set()
        case .topLeft, .topRight, .bottomLeft, .bottomRight: NSCursor.crosshair.set()
        default: NSCursor.arrow.set()
        }
        super.mouseMoved(with: event)
    }
}
```

### 1.7 Create New File: `VideoWindowManager.swift`

```swift
import AppKit
import SwiftUI

@MainActor
final class VideoWindowManager: ObservableObject {
    static let shared = VideoWindowManager()
    
    private var videoPanel: VideoPlayerPanel?
    @Published var isShowing = false
    @Published var currentVideoID: String?
    
    private init() {}
    
    func showVideo(videoID: String, fromNotchPosition: NSPoint? = nil) {
        hideVideo()
        
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let size = lastSize ?? NSSize(width: 480, height: 270)
        
        var position: NSPoint
        if let notchPos = fromNotchPosition {
            position = NSPoint(x: notchPos.x - size.width / 2, y: notchPos.y - size.height - 20)
        } else {
            let notchHeight = screen.safeAreaInsets.top
            position = NSPoint(
                x: (screen.frame.width - size.width) / 2,
                y: screen.frame.height - notchHeight - size.height - 20
            )
        }
        
        let panel = VideoPlayerPanel(
            contentRect: NSRect(origin: position, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: true
        )
        
        let view = VideoPlayerContentView(videoID: videoID, windowManager: self)
        panel.contentView = NSHostingView(rootView: view)
        
        // Animate in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        
        videoPanel = panel
        isShowing = true
        currentVideoID = videoID
    }
    
    func hideVideo() {
        guard let panel = videoPanel else { return }
        lastSize = panel.frame.size
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.close()
        })
        
        videoPanel = nil
        isShowing = false
        currentVideoID = nil
    }
    
    // Position memory
    @AppStorage("videoPlayer.lastSize.width") private var lastWidth: Double = 480
    @AppStorage("videoPlayer.lastSize.height") private var lastHeight: Double = 270
    
    private var lastSize: NSSize? {
        get { NSSize(width: lastWidth, height: lastHeight) }
        set { lastWidth = newValue?.width ?? 480; lastHeight = newValue?.height ?? 270 }
    }
}

struct VideoPlayerContentView: View {
    let videoID: String
    @ObservedObject var windowManager: VideoWindowManager
    @StateObject private var playerState = YouTubePlayerState()
    @State private var showControls = true
    @State private var hideControlsTimer: Timer?
    
    var body: some View {
        ZStack {
            // Video
            YouTubePlayerWebView(videoID: videoID, state: playerState)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Controls overlay
            VideoControlsOverlay(
                playerState: playerState,
                isVisible: $showControls,
                onClose: { windowManager.hideVideo() }
            )
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            showControls = hovering
            resetHideTimer()
        }
    }
    
    private func resetHideTimer() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            if playerState.isPlaying { showControls = false }
        }
    }
}
```

### 1.8 Create New File: `VideoControlsOverlay.swift`

```swift
import SwiftUI

struct VideoControlsOverlay: View {
    @ObservedObject var playerState: YouTubePlayerState
    @Binding var isVisible: Bool
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Gradients
            VStack {
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 50)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 80)
            }
            .opacity(isVisible ? 1 : 0)
            
            VStack {
                // Top bar
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white).frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if !playerState.videoTitle.isEmpty {
                        Text(playerState.videoTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white).lineLimit(1)
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "pip.enter").font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white).frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.top, 8)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 8) {
                    // Progress bar
                    VideoScrubber(currentTime: playerState.currentTime, duration: playerState.duration)
                    
                    // Buttons
                    HStack(spacing: 16) {
                        Text(formatTime(playerState.currentTime))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(formatTime(playerState.duration))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
            }
            .opacity(isVisible ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.2), value: isVisible)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct VideoScrubber: View {
    let currentTime: Double
    let duration: Double
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.3)).frame(height: 4)
                Capsule().fill(Color.red).frame(width: geo.size.width * progress, height: 4)
                Circle().fill(Color.white).frame(width: 12, height: 12)
                    .position(x: geo.size.width * progress, y: 10)
            }
        }
        .frame(height: 20)
    }
}
```

---

## 🎨 Part 2: Settings Improvements

### 2.1 Add to Settings: YouTube Player Section

Add this new `YouTubePlayerSettingsView` and integrate it into the existing `SettingsView`:

```swift
struct YouTubePlayerSettingsView: View {
    @AppStorage("youtubeAutoplay") private var autoplay = true
    @AppStorage("youtubeDefaultSize") private var defaultSize = "medium"
    @AppStorage("youtubeRememberPosition") private var rememberPosition = true
    @AppStorage("youtubeShowInMenuBar") private var showInMenuBar = true
    @AppStorage("youtubeDefaultQuality") private var defaultQuality = "auto"
    @AppStorage("youtubePlaybackSpeed") private var playbackSpeed = 1.0
    
    let sizeOptions = ["tiny": "Tiny (280×158)", "small": "Small (426×240)", "medium": "Medium (480×270)", "large": "Large (854×480)", "hd": "HD (1280×720)"]
    let qualityOptions = ["auto": "Auto", "1080p": "1080p", "720p": "720p", "480p": "480p", "360p": "360p"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader(title: "YouTube Player", subtitle: "Video playback preferences", icon: "play.rectangle.fill", color: .red)
                
                SettingsSection(title: "PLAYBACK") {
                    SettingsToggleRow(title: "Autoplay videos", subtitle: "Start playing when opened", icon: "play.fill", color: .green, isOn: $autoplay)
                    Divider().padding(.leading, 56)
                    
                    // Default size picker
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.15)).frame(width: 40, height: 40)
                            Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 16, weight: .medium)).foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Size").font(.system(size: 14, weight: .medium))
                            Picker("", selection: $defaultSize) {
                                ForEach(sizeOptions.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                    Text(value).tag(key)
                                }
                            }
                            .labelsHidden()
                        }
                        Spacer()
                    }
                    .padding(12)
                    
                    Divider().padding(.leading, 56)
                    
                    // Playback speed slider
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.15)).frame(width: 40, height: 40)
                            Image(systemName: "speedometer").font(.system(size: 16, weight: .medium)).foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Default Playback Speed").font(.system(size: 14, weight: .medium))
                            HStack {
                                Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.25)
                                Text("\(playbackSpeed, specifier: "%.2f")x")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                }
                
                SettingsSection(title: "WINDOW") {
                    SettingsToggleRow(title: "Remember position & size", subtitle: "Restore last used window settings", icon: "rectangle.dashed", color: .purple, isOn: $rememberPosition)
                    Divider().padding(.leading, 56)
                    SettingsToggleRow(title: "Show in menu bar", subtitle: "Quick access to paste YouTube URLs", icon: "menubar.rectangle", color: .gray, isOn: $showInMenuBar)
                }
                
                Spacer()
            }
            .padding(24)
        }
    }
}
```

### 2.2 Update Settings Tab Enum

In the existing `SettingsView`, add the YouTube tab:

```swift
enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case volume = "Volume"
    case brightness = "Brightness"
    case battery = "Battery"
    case music = "Music"
    case youtube = "YouTube"  // NEW
    case about = "About"
    
    var icon: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        // ... existing cases
        }
    }
    
    var color: Color {
        switch self {
        case .youtube: return .red
        // ... existing cases
        }
    }
}

// In the detail switch:
case .youtube: YouTubePlayerSettingsView()
```

---

## 📦 Part 3: Distribution & Notarization

### 3.1 Entitlements for Direct Distribution

Create file: `TopNotch-DirectDist.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

### 3.2 Info.plist Additions

Add to existing `Info.plist`:

```xml
<!-- Network for YouTube -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>youtube.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSThirdPartyExceptionAllowsInsecureHTTPLoads</key>
            <false/>
        </dict>
    </dict>
</dict>

<!-- Export Compliance -->
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### 3.3 Notarization Script

Create file: `scripts/notarize.sh`

```bash
#!/bin/bash

APP_NAME="TopNotch"
TEAM_ID="YOUR_TEAM_ID"
APPLE_ID="your@email.com"

# Build
xcodebuild archive \
    -scheme "$APP_NAME" \
    -archivePath "./build/$APP_NAME.xcarchive" \
    -configuration Release

# Export
xcodebuild -exportArchive \
    -archivePath "./build/$APP_NAME.xcarchive" \
    -exportPath "./build/export" \
    -exportOptionsPlist "./ExportOptions.plist"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "./build/export/$APP_NAME.app" \
    -ov -format UDZO \
    "./build/$APP_NAME.dmg"

# Sign DMG
codesign --sign "Developer ID Application: Your Name ($TEAM_ID)" \
    --timestamp "./build/$APP_NAME.dmg"

# Notarize
xcrun notarytool submit "./build/$APP_NAME.dmg" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --wait

# Staple
xcrun stapler staple "./build/$APP_NAME.dmg"

echo "✅ Done! DMG ready at ./build/$APP_NAME.dmg"
```

### 3.4 ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

---

## 📱 Part 4: App Icon Requirements

### 4.1 Required Sizes (macOS)

| Size | Scale | Filename |
|------|-------|----------|
| 16×16 | 1x | icon_16x16.png |
| 32×32 | 2x | icon_16x16@2x.png |
| 32×32 | 1x | icon_32x32.png |
| 64×64 | 2x | icon_32x32@2x.png |
| 128×128 | 1x | icon_128x128.png |
| 256×256 | 2x | icon_128x128@2x.png |
| 256×256 | 1x | icon_256x256.png |
| 512×512 | 2x | icon_256x256@2x.png |
| 512×512 | 1x | icon_512x512.png |
| 1024×1024 | 2x | icon_512x512@2x.png |

### 4.2 Icon Design Recommendations

For a notch utility app:
- **Primary shape**: Rounded rectangle representing the notch
- **Colors**: Dark gradient background like actual notch
- **Accent**: Bright indicator dots (green, orange, red)
- **Style**: Flat design with subtle depth/shadows

---

## ✅ Part 5: Implementation Checklist

### Phase 1: Core YouTube Player
- [ ] Create `YouTubeURLParser.swift`
- [ ] Create `YouTubePlayerState.swift`
- [ ] Create `YouTubePlayerWebView.swift`
- [ ] Create `YouTubePlayerController.swift`
- [ ] Create `VideoPlayerPanel.swift`
- [ ] Create `VideoWindowManager.swift`
- [ ] Create `VideoControlsOverlay.swift`

### Phase 2: Integration with Notch
- [ ] Add YouTube URL detection to clipboard monitoring
- [ ] Add "Open YouTube Video" context menu item
- [ ] Implement notch tap → video URL input
- [ ] Animation from notch to player expansion

### Phase 3: Settings & Preferences
- [ ] Add `YouTubePlayerSettingsView`
- [ ] Update `SettingsView` with YouTube tab
- [ ] Implement position/size memory
- [ ] Add global hotkey configuration

### Phase 4: Polish
- [ ] Keyboard shortcuts (Space, arrows, M, F, Esc)
- [ ] Picture-in-Picture button
- [ ] Loading states and error handling
- [ ] Edge-case handling (invalid URLs, offline)

### Phase 5: Distribution
- [ ] Update app name to "Top Notch"
- [ ] Create new app icon
- [ ] Set up entitlements for notarization
- [ ] Create build/notarization scripts
- [ ] Create landing page
- [ ] Set up Gumroad/Paddle storefront
- [ ] Create privacy policy

---

## 📁 New File Structure

```
TopNotch/
├── MyDynamicIslandApp.swift (rename: TopNotchApp.swift)
├── DynamicIsland.swift
├── IslandView.swift
├── MediaKeyManager.swift
├── YouTube/                      # NEW FOLDER
│   ├── YouTubeURLParser.swift
│   ├── YouTubePlayerState.swift
│   ├── YouTubePlayerWebView.swift
│   ├── YouTubePlayerController.swift
│   ├── VideoPlayerPanel.swift
│   ├── VideoWindowManager.swift
│   └── VideoControlsOverlay.swift
├── Settings/                     # REORGANIZE
│   ├── SettingsView.swift
│   ├── GeneralSettingsView.swift
│   ├── YouTubePlayerSettingsView.swift  # NEW
│   └── ... other settings views
├── Assets.xcassets/
│   ├── AppIcon.appiconset/       # UPDATE icons
│   └── ...
└── TopNotch.entitlements         # For notarization
```

---

## 🔗 Reference Documents

For detailed code implementations, see:

1. **[YOUTUBE_PLAYER_IMPLEMENTATION.md](YOUTUBE_PLAYER_IMPLEMENTATION.md)**
   - Complete WKWebView YouTube player code
   - JavaScript bridge implementation
   - Picture-in-Picture integration

2. **[YOUTUBE_PLAYER_UIUX_RESEARCH.md](YOUTUBE_PLAYER_UIUX_RESEARCH.md)**
   - Animation timing constants
   - Resize handle implementations
   - Settings UI components
   - URL input methods

3. **[APP_STORE_SUBMISSION_GUIDE.md](APP_STORE_SUBMISSION_GUIDE.md)**
   - Why App Store is not possible
   - Notarization process
   - Privacy policy template
   - Distribution platforms

---

## ⚠️ Important Notes

1. **Private APIs**: The app uses SkyLight, MediaRemote, and DisplayServices frameworks which are private Apple APIs. This means:
   - App Store submission is **not possible**
   - Direct distribution with notarization is the only option
   - These APIs may break with macOS updates

2. **YouTube ToS**: Embedding YouTube via iframe is **legal and supported** by Google. Do NOT attempt to extract direct video URLs or download videos.

3. **macOS 13.0+**: The app requires macOS Ventura or later for notch detection and safe area APIs.

4. **Accessibility**: The app requires Accessibility permission for media key interception. Users must manually grant this in System Settings.

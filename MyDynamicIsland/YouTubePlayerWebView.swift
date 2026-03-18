import SwiftUI
import WebKit
import Combine
import OSLog

/// NSViewRepresentable wrapper for YouTube iframe player
struct YouTubePlayerWebView: NSViewRepresentable {
    let videoID: String
    var startTime: Int = 0
    @ObservedObject var playerState: YouTubePlayerState
    @ObservedObject var playerController: YouTubePlayerController

    private static let logger = Logger(subsystem: "com.topnotch.app", category: "YouTubePlayer")

    private static let playerBridgeScript = #"""
    (function() {
        if (window.__topNotchBridgeInstalled) {
            return;
        }
        window.__topNotchBridgeInstalled = true;

        function postMessage(name, payload) {
            try {
                window.webkit.messageHandlers[name].postMessage(payload);
            } catch (_) {}
        }

        function activeVideoElement() {
            return document.querySelector('video.html5-main-video') || document.querySelector('video');
        }

        function hasEmbedPlayer() {
            return typeof window.player !== 'undefined' && window.player;
        }

        function currentDuration() {
            try {
                if (hasEmbedPlayer() && typeof window.player.getDuration === 'function') {
                    return Number(window.player.getDuration()) || 0;
                }
                var video = activeVideoElement();
                return Number(video && video.duration) || 0;
            } catch (_) {
                return 0;
            }
        }

        function currentTime() {
            try {
                if (hasEmbedPlayer() && typeof window.player.getCurrentTime === 'function') {
                    return Number(window.player.getCurrentTime()) || 0;
                }
                var video = activeVideoElement();
                return Number(video && video.currentTime) || 0;
            } catch (_) {
                return 0;
            }
        }

        function isMuted() {
            try {
                if (hasEmbedPlayer() && typeof window.player.isMuted === 'function') {
                    return !!window.player.isMuted();
                }
                var video = activeVideoElement();
                return !!(video && video.muted);
            } catch (_) {
                return false;
            }
        }

        function currentVolumePercent() {
            try {
                if (hasEmbedPlayer() && typeof window.player.getVolume === 'function') {
                    return Number(window.player.getVolume()) || 0;
                }
                var video = activeVideoElement();
                return Math.round((Number(video && video.volume) || 0) * 100);
            } catch (_) {
                return 0;
            }
        }

        function currentStateCode() {
            try {
                if (hasEmbedPlayer() && typeof window.player.getPlayerState === 'function') {
                    return Number(window.player.getPlayerState());
                }
                var video = activeVideoElement();
                if (!video) {
                    return -1;
                }
                if (video.ended) {
                    return 0;
                }
                if (video.readyState < 3) {
                    return 3;
                }
                return video.paused ? 2 : 1;
            } catch (_) {
                return -1;
            }
        }

        window.sendTimeUpdate = function() {
            postMessage('timeUpdate', {
                currentTime: currentTime(),
                duration: currentDuration()
            });
        };

        window.sendVolumeChange = function() {
            postMessage('volumeChange', {
                volume: currentVolumePercent(),
                muted: isMuted()
            });
        };

        window.sendVideoData = function() {
            var title = '';
            try {
                if (hasEmbedPlayer() && typeof window.player.getVideoData === 'function') {
                    var data = window.player.getVideoData();
                    title = (data && data.title) || '';
                }
            } catch (_) {}

            if (!title) {
                var titleNode = document.querySelector('h1.ytd-watch-metadata yt-formatted-string')
                    || document.querySelector('h1.title yt-formatted-string')
                    || document.querySelector('meta[name="title"]');
                if (titleNode) {
                    title = (titleNode.textContent || titleNode.content || '').trim();
                }
            }

            if (!title && document.title) {
                title = document.title.replace(/\s*-\s*YouTube$/i, '').trim();
            }

            postMessage('videoData', { title: title });
        };

        window.playVideo = function() {
            if (hasEmbedPlayer() && typeof window.player.playVideo === 'function') {
                window.player.playVideo();
                return;
            }
            var video = activeVideoElement();
            if (video) {
                var playResult = video.play();
                if (playResult && typeof playResult.catch === 'function') {
                    playResult.catch(function() {});
                }
            }
        };

        window.pauseVideo = function() {
            if (hasEmbedPlayer() && typeof window.player.pauseVideo === 'function') {
                window.player.pauseVideo();
                return;
            }
            var video = activeVideoElement();
            if (video) {
                video.pause();
            }
        };

        window.togglePlayPause = function() {
            if (hasEmbedPlayer() && typeof window.player.getPlayerState === 'function') {
                if (Number(window.player.getPlayerState()) === 1) {
                    window.player.pauseVideo();
                } else {
                    window.player.playVideo();
                }
                return;
            }
            var video = activeVideoElement();
            if (!video) {
                return;
            }
            if (video.paused || video.ended) {
                var playResult = video.play();
                if (playResult && typeof playResult.catch === 'function') {
                    playResult.catch(function() {});
                }
            } else {
                video.pause();
            }
        };

        window.seekTo = function(seconds) {
            if (hasEmbedPlayer() && typeof window.player.seekTo === 'function') {
                window.player.seekTo(seconds, true);
                return;
            }
            var video = activeVideoElement();
            if (video) {
                video.currentTime = Number(seconds) || 0;
            }
        };

        window.seekRelative = function(seconds) {
            if (hasEmbedPlayer() && typeof window.player.getCurrentTime === 'function') {
                window.player.seekTo(window.player.getCurrentTime() + Number(seconds || 0), true);
                return;
            }
            var video = activeVideoElement();
            if (video) {
                video.currentTime = Math.max(0, (Number(video.currentTime) || 0) + Number(seconds || 0));
            }
        };

        window.setVolume = function(volume) {
            if (hasEmbedPlayer() && typeof window.player.setVolume === 'function') {
                window.player.setVolume(volume);
                window.sendVolumeChange();
                return;
            }
            var video = activeVideoElement();
            if (video) {
                video.volume = Math.max(0, Math.min(1, (Number(volume) || 0) / 100));
                if (video.volume > 0 && video.muted) {
                    video.muted = false;
                }
                window.sendVolumeChange();
            }
        };

        window.mute = function() {
            if (hasEmbedPlayer() && typeof window.player.mute === 'function') {
                window.player.mute();
                window.sendVolumeChange();
                return;
            }
            var video = activeVideoElement();
            if (video) {
                video.muted = true;
                window.sendVolumeChange();
            }
        };

        window.unmute = function() {
            if (hasEmbedPlayer() && typeof window.player.unMute === 'function') {
                window.player.unMute();
                window.sendVolumeChange();
                return;
            }
            var video = activeVideoElement();
            if (video) {
                video.muted = false;
                window.sendVolumeChange();
            }
        };

        window.toggleMute = function() {
            if (hasEmbedPlayer() && typeof window.player.isMuted === 'function') {
                if (window.player.isMuted()) {
                    window.player.unMute();
                } else {
                    window.player.mute();
                }
                window.sendVolumeChange();
                return;
            }
            var video = activeVideoElement();
            if (video) {
                video.muted = !video.muted;
                window.sendVolumeChange();
            }
        };

        window.setPlaybackRate = function(rate) {
            if (hasEmbedPlayer() && typeof window.player.setPlaybackRate === 'function') {
                window.player.setPlaybackRate(rate);
                return;
            }
            var video = activeVideoElement();
            if (video) {
                video.playbackRate = Number(rate) || 1;
                postMessage('playbackRateChange', { rate: video.playbackRate });
            }
        };

        window.loadVideo = function(videoId) {
            if (hasEmbedPlayer() && typeof window.player.loadVideoById === 'function') {
                window.player.loadVideoById(videoId);
                return;
            }
            window.location.href = 'https://www.youtube.com/watch?v=' + encodeURIComponent(videoId);
        };

        function postReadyState() {
            postMessage('playerReady', { duration: currentDuration() });
            postMessage('stateChange', { state: currentStateCode() });
            postMessage('playbackRateChange', { rate: (activeVideoElement() && activeVideoElement().playbackRate) || 1 });
            window.sendVideoData();
            window.sendTimeUpdate();
            window.sendVolumeChange();
        }

        function bindVideo(video) {
            if (!video || video.__topNotchBound) {
                return;
            }
            video.__topNotchBound = true;
            ['play', 'pause', 'playing', 'waiting', 'ended'].forEach(function(eventName) {
                video.addEventListener(eventName, function() {
                    postMessage('stateChange', { state: currentStateCode() });
                });
            });
            ['timeupdate', 'loadedmetadata', 'durationchange'].forEach(function(eventName) {
                video.addEventListener(eventName, function() {
                    window.sendTimeUpdate();
                });
            });
            ['volumechange'].forEach(function(eventName) {
                video.addEventListener(eventName, function() {
                    window.sendVolumeChange();
                });
            });
            ['ratechange'].forEach(function(eventName) {
                video.addEventListener(eventName, function() {
                    postMessage('playbackRateChange', { rate: video.playbackRate || 1 });
                });
            });
            postReadyState();
        }

        function bindCurrentVideo() {
            bindVideo(activeVideoElement());
        }

        bindCurrentVideo();

        var observer = new MutationObserver(function() {
            bindCurrentVideo();
        });

        if (document.documentElement) {
            observer.observe(document.documentElement, { childList: true, subtree: true });
        }

        document.addEventListener('readystatechange', bindCurrentVideo);
        window.addEventListener('load', bindCurrentVideo);
    })();
    """#

    private static func trace(_ message: String) {
        #if DEBUG
        logger.debug("\(message)")
        #endif
    }
    
    /// Coordinator handles JavaScript message callbacks
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YouTubePlayerWebView
        weak var webView: WKWebView?
        private var timeUpdateTimer: Timer?
        var lastLoadedVideoID: String?
        var lastPlaybackMode: YouTubePlaybackMode?
        
        init(_ parent: YouTubePlayerWebView) {
            self.parent = parent
        }
        
        deinit {
            timeUpdateTimer?.invalidate()
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            Task { @MainActor in
                switch message.name {
                case "playerReady":
                    handlePlayerReady(body)
                case "stateChange":
                    handleStateChange(body)
                case "timeUpdate":
                    handleTimeUpdate(body)
                case "error":
                    handleError(body)
                case "videoData":
                    handleVideoData(body)
                case "volumeChange":
                    handleVolumeChange(body)
                case "playbackRateChange":
                    handlePlaybackRateChange(body)
                default:
                    break
                }
            }
        }
        
        // MARK: - Message Handlers
        
        @MainActor
        private func handlePlayerReady(_ data: [String: Any]) {
            YouTubePlayerWebView.logger.info("YouTube player ready for video \(self.parent.videoID, privacy: .public)")
            YouTubePlayerWebView.trace("player ready for video \(self.parent.videoID)")
            parent.playerState.isReady = true
            if let duration = data["duration"] as? Double {
                parent.playerState.duration = duration
            }
            // Start time update polling
            startTimeUpdateTimer()
        }
        
        @MainActor
        private func handleStateChange(_ data: [String: Any]) {
            guard let state = data["state"] as? Int else { return }
            YouTubePlayerWebView.logger.debug("YouTube state change \(state, privacy: .public) for video \(self.parent.videoID, privacy: .public)")
            YouTubePlayerWebView.trace("state change \(state) for video \(self.parent.videoID)")
            parent.playerState.updatePlaybackState(from: state)
        }
        
        @MainActor
        private func handleTimeUpdate(_ data: [String: Any]) {
            if let currentTime = data["currentTime"] as? Double {
                parent.playerState.currentTime = currentTime
            }
            if let duration = data["duration"] as? Double, duration > 0 {
                parent.playerState.duration = duration
            }
        }
        
        @MainActor
        private func handleError(_ data: [String: Any]) {
            guard let code = data["code"] as? Int else { return }
            let error = YouTubePlayerError.fromYouTubeErrorCode(code)
            YouTubePlayerWebView.logger.error("YouTube player error \(code, privacy: .public) for video \(self.parent.videoID, privacy: .public)")
            YouTubePlayerWebView.trace("player error \(code) for video \(self.parent.videoID)")
            if case .embeddingDisabled = error, let webView, let currentVideoID = parent.playerState.currentVideoID {
                YouTubePlayerWebView.logger.notice("Embedding blocked for video \(currentVideoID, privacy: .public); switching to watch-page fallback")
                YouTubePlayerWebView.trace("embedding blocked for video \(currentVideoID); switching to watch-page fallback")
                parent.playerState.switchToWatchPageFallback()
                parent.loadWatchPage(in: webView, videoID: currentVideoID)
                lastLoadedVideoID = currentVideoID
                lastPlaybackMode = .watchPageFallback
                return
            }
            parent.playerState.setError(error)
        }
        
        @MainActor
        private func handleVideoData(_ data: [String: Any]) {
            if let title = data["title"] as? String {
                parent.playerState.videoTitle = title
            }
        }
        
        @MainActor
        private func handleVolumeChange(_ data: [String: Any]) {
            if let volume = data["volume"] as? Double {
                parent.playerState.volume = volume / 100.0
            }
            if let muted = data["muted"] as? Bool {
                parent.playerState.isMuted = muted
            }
        }
        
        @MainActor
        private func handlePlaybackRateChange(_ data: [String: Any]) {
            if let rate = data["rate"] as? Double {
                parent.playerState.playbackRate = rate
            }
        }
        
        // MARK: - Time Update Timer

        @MainActor
        private func startTimeUpdateTimer() {
            timeUpdateTimer?.invalidate()
            timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.requestTimeUpdate() }
            }
        }

        @MainActor
        func stopTimeUpdateTimer() {
            timeUpdateTimer?.invalidate()
            timeUpdateTimer = nil
        }

        @MainActor
        private func requestTimeUpdate() {
            webView?.evaluateJavaScript("sendTimeUpdate()", completionHandler: nil)
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let host = url.host?.lowercased() ?? ""
            let isMainFrameNavigation = navigationAction.targetFrame?.isMainFrame ?? false

            // Always allow YouTube domains and initial about:blank / data loads
            let allowedHosts = ["youtube.com", "www.youtube.com", "m.youtube.com",
                                "music.youtube.com", "youtu.be",
                                "accounts.google.com", "consent.youtube.com",
                                "www.youtube-nocookie.com",
                                "www.google.com"]
            let isYouTubeDomain = allowedHosts.contains(where: { host.hasSuffix($0) })
            let isInitialLoad = url.scheme == "about" || url.scheme == "data" || url.absoluteString.hasPrefix("blob:")

            if isMainFrameNavigation && !isInitialLoad {
                switch parent.playerState.playbackMode {
                case .embed:
                    // Only block user-initiated link clicks in embed mode.
                    // Allow .other (loadHTMLString, iframe API) and .reload.
                    if navigationAction.navigationType == .linkActivated {
                        NSWorkspace.shared.open(url)
                        decisionHandler(.cancel)
                        return
                    }
                    // Allow the navigation (initial embed load, reloads, etc.)
                    break
                case .watchPageFallback:
                    let isCurrentVideoPage: Bool
                    if let currentVideoID = parent.playerState.currentVideoID,
                       let requestedVideoID = YouTubeURLParser.extractVideoID(from: url.absoluteString) {
                        isCurrentVideoPage = currentVideoID == requestedVideoID
                    } else {
                        isCurrentVideoPage = false
                    }

                    let isAllowedFallbackPage = isYouTubeDomain && isCurrentVideoPage
                    let isAllowedAccountFlow = host.hasSuffix("accounts.google.com") || host.hasSuffix("consent.youtube.com")

                    if !isAllowedFallbackPage && !isAllowedAccountFlow {
                        if navigationAction.navigationType == .linkActivated {
                            NSWorkspace.shared.open(url)
                        }
                        decisionHandler(.cancel)
                        return
                    }
                }
            }

            if isYouTubeDomain || isInitialLoad {
                decisionHandler(.allow)
                return
            }

            // User-initiated clicks on external links — open in Safari instead
            if navigationAction.navigationType == .linkActivated {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            // Allow sub-resource loads (scripts, images, iframes) from any domain
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let urlString = webView.url?.absoluteString ?? "unknown"
            YouTubePlayerWebView.logger.debug("WKWebView finished navigation: \(urlString, privacy: .public)")
            YouTubePlayerWebView.trace("finished navigation: \(urlString)")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if shouldIgnore(error) {
                return
            }
            YouTubePlayerWebView.logger.error("WKWebView navigation failure: \(error.localizedDescription, privacy: .public)")
            YouTubePlayerWebView.trace("navigation failure: \(error.localizedDescription)")
            Task { @MainActor in
                parent.playerState.setError(.networkError)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if shouldIgnore(error) {
                return
            }
            YouTubePlayerWebView.logger.error("WKWebView provisional navigation failure: \(error.localizedDescription, privacy: .public)")
            YouTubePlayerWebView.trace("provisional navigation failure: \(error.localizedDescription)")
            Task { @MainActor in
                parent.playerState.setError(.networkError)
            }
        }

        private func shouldIgnore(_ error: Error) -> Bool {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return true
            }
            if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
                return true
            }
            return false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Add message handlers
        let contentController = configuration.userContentController
        contentController.addUserScript(
            WKUserScript(
                source: Self.playerBridgeScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )
        let messageNames = ["playerReady", "stateChange", "timeUpdate", "error", "videoData", "volumeChange", "playbackRateChange"]
        for name in messageNames {
            contentController.add(context.coordinator, name: name)
        }
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        // Make background transparent
        webView.setValue(false, forKey: "drawsBackground")
        
        context.coordinator.webView = webView
        playerController.webView = webView
        
        loadCurrentPlaybackMode(in: webView)
        context.coordinator.lastLoadedVideoID = videoID
        context.coordinator.lastPlaybackMode = playerState.playbackMode
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        playerController.webView = webView

        let shouldReload = context.coordinator.lastLoadedVideoID != videoID
            || context.coordinator.lastPlaybackMode != playerState.playbackMode

        if shouldReload {
            loadCurrentPlaybackMode(in: webView)
            context.coordinator.lastLoadedVideoID = videoID
            context.coordinator.lastPlaybackMode = playerState.playbackMode
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopTimeUpdateTimer()

        // Clear webView references before removing handlers
        coordinator.webView = nil
        // Only nil out the controller's webView if it still points to THIS webView.
        // A new YouTubePlayerWebView may have already set a replacement reference
        // (e.g., when the player is minimized and a hidden keep-alive WebView takes over).
        // Execute synchronously — we're already on MainActor and an async Task
        // could race against a replacement webView being set by a new view.
        if coordinator.parent.playerController.webView === webView {
            coordinator.parent.playerController.webView = nil
        }

        // Remove message handlers to break the retain cycle:
        // WKUserContentController -> Coordinator -> parent
        let contentController = webView.configuration.userContentController
        let messageNames = ["playerReady", "stateChange", "timeUpdate", "error", "videoData", "volumeChange", "playbackRateChange"]
        for name in messageNames {
            contentController.removeScriptMessageHandler(forName: name)
        }
        webView.navigationDelegate = nil

        // Stop any pending loads
        webView.stopLoading()
    }
    
    // MARK: - YouTube Player HTML
    
    private func loadYouTubePlayer(in webView: WKWebView) {
        Self.logger.info("Loading embedded YouTube player for video \(videoID, privacy: .public)")
        Self.trace("loading embedded player for video \(videoID)")
        let html = generatePlayerHTML(videoID: videoID)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }

    private func loadWatchPage(in webView: WKWebView, videoID: String) {
        guard let url = YouTubeURLParser.youtubeURL(for: videoID) else { return }
        Self.logger.notice("Loading watch-page fallback for video \(videoID, privacy: .public)")
        Self.trace("loading watch-page fallback for video \(videoID)")
        webView.load(URLRequest(url: url))
    }

    private func loadCurrentPlaybackMode(in webView: WKWebView) {
        switch playerState.playbackMode {
        case .embed:
            loadYouTubePlayer(in: webView)
        case .watchPageFallback:
            loadWatchPage(in: webView, videoID: videoID)
        }
    }
    
    private func generatePlayerHTML(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { 
                    width: 100%; 
                    height: 100%; 
                    overflow: hidden;
                    background: black;
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
                var player;
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        width: '100%',
                        height: '100%',
                        videoId: '\(videoID)',
                        playerVars: {
                            'autoplay': 1,
                            'controls': 1,
                            'enablejsapi': 1,
                            'fs': 1,
                            'playsinline': 1,
                            'rel': 0,
                            'modestbranding': 1,
                            'iv_load_policy': 3,
                            'autohide': 1,
                            'start': \(startTime > 0 ? startTime : 0)
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError,
                            'onPlaybackRateChange': onPlaybackRateChange
                        }
                    });
                }
                
                function onPlayerReady(event) {
                    var duration = player.getDuration();
                    webkit.messageHandlers.playerReady.postMessage({
                        'duration': duration
                    });
                    sendVideoData();
                    event.target.playVideo();
                }
                
                function onPlayerStateChange(event) {
                    webkit.messageHandlers.stateChange.postMessage({
                        'state': event.data
                    });
                }
                
                function onPlayerError(event) {
                    webkit.messageHandlers.error.postMessage({
                        'code': event.data
                    });
                }
                
                function onPlaybackRateChange(event) {
                    webkit.messageHandlers.playbackRateChange.postMessage({
                        'rate': event.data
                    });
                }
                
                function sendTimeUpdate() {
                    if (player && player.getCurrentTime) {
                        webkit.messageHandlers.timeUpdate.postMessage({
                            'currentTime': player.getCurrentTime(),
                            'duration': player.getDuration()
                        });
                    }
                }
                
                function sendVideoData() {
                    if (player && player.getVideoData) {
                        var data = player.getVideoData();
                        webkit.messageHandlers.videoData.postMessage({
                            'title': data.title || ''
                        });
                    }
                }
                
                function sendVolumeChange() {
                    if (player) {
                        webkit.messageHandlers.volumeChange.postMessage({
                            'volume': player.getVolume(),
                            'muted': player.isMuted()
                        });
                    }
                }
                
                // Playback Control Functions
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
                
                function seekRelative(seconds) {
                    if (player) {
                        var currentTime = player.getCurrentTime();
                        player.seekTo(currentTime + seconds, true);
                    }
                }
                
                function setVolume(volume) {
                    if (player) {
                        player.setVolume(volume);
                        sendVolumeChange();
                    }
                }
                
                function mute() {
                    if (player) {
                        player.mute();
                        sendVolumeChange();
                    }
                }
                
                function unmute() {
                    if (player) {
                        player.unMute();
                        sendVolumeChange();
                    }
                }
                
                function toggleMute() {
                    if (player) {
                        if (player.isMuted()) {
                            player.unMute();
                        } else {
                            player.mute();
                        }
                        sendVolumeChange();
                    }
                }
                
                function setPlaybackRate(rate) {
                    if (player) player.setPlaybackRate(rate);
                }
                
                function loadVideo(videoId) {
                    if (player) player.loadVideoById(videoId);
                }
                
                function getAvailablePlaybackRates() {
                    if (player) return player.getAvailablePlaybackRates();
                    return [1];
                }
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Player Control Extensions

extension YouTubePlayerWebView {
    /// Creates a control interface for external use
    struct Controls {
        weak var webView: WKWebView?
        
        func play() {
            webView?.evaluateJavaScript("playVideo()", completionHandler: nil)
        }
        
        func pause() {
            webView?.evaluateJavaScript("pauseVideo()", completionHandler: nil)
        }
        
        func togglePlayPause() {
            webView?.evaluateJavaScript("togglePlayPause()", completionHandler: nil)
        }
        
        func seek(to seconds: Double) {
            webView?.evaluateJavaScript("seekTo(\(seconds))", completionHandler: nil)
        }
        
        func seekRelative(seconds: Double) {
            webView?.evaluateJavaScript("seekRelative(\(seconds))", completionHandler: nil)
        }
        
        func setVolume(_ volume: Double) {
            let volumePercent = Int(max(0, min(100, volume * 100)))
            webView?.evaluateJavaScript("setVolume(\(volumePercent))", completionHandler: nil)
        }
        
        func mute() {
            webView?.evaluateJavaScript("mute()", completionHandler: nil)
        }
        
        func unmute() {
            webView?.evaluateJavaScript("unmute()", completionHandler: nil)
        }
        
        func toggleMute() {
            webView?.evaluateJavaScript("toggleMute()", completionHandler: nil)
        }
        
        func setPlaybackRate(_ rate: Double) {
            webView?.evaluateJavaScript("setPlaybackRate(\(rate))", completionHandler: nil)
        }
        
        func loadVideo(id: String) {
            webView?.evaluateJavaScript("loadVideo('\(id)')", completionHandler: nil)
        }
    }
}

// MARK: - WebView Controller for External Control

@MainActor
final class YouTubePlayerController: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    weak var webView: WKWebView?
    
    var controls: YouTubePlayerWebView.Controls {
        YouTubePlayerWebView.Controls(webView: webView)
    }
    
    func play() { controls.play() }
    func pause() { controls.pause() }
    func togglePlayPause() { controls.togglePlayPause() }
    func seek(to seconds: Double) { controls.seek(to: seconds) }
    func seekRelative(seconds: Double) { controls.seekRelative(seconds: seconds) }
    func setVolume(_ volume: Double) { controls.setVolume(volume) }
    func mute() { controls.mute() }
    func unmute() { controls.unmute() }
    func toggleMute() { controls.toggleMute() }
    func setPlaybackRate(_ rate: Double) { controls.setPlaybackRate(rate) }
    func loadVideo(id: String) { controls.loadVideo(id: id) }
}

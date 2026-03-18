#if APP_STORE_BUILD
import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class MediaRemoteController: ObservableObject {
    static let shared = MediaRemoteController()

    @Published private(set) var nowPlayingInfo = NowPlayingInfo()
    @Published private(set) var isAvailable = true
    @Published private(set) var isPlaying = false

    private var observers: [NSObjectProtocol] = []
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 0.5
    private var tickCount: Int = 0

    private init() {
        setupObservers()
        startElapsedTimeTimer()
    }

    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func setupObservers() {
        let center = DistributedNotificationCenter.default()

        // Apple Music
        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] note in
            // Extract userInfo on the callback queue to avoid Sendable issues
            let userInfo = note.userInfo as? [String: Any]
            Task { @MainActor [weak self] in
                guard let self, let info = userInfo else { return }
                self.handleAppleMusicInfo(info)
            }
        })

        // Spotify
        observers.append(center.addObserver(forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] note in
            let userInfo = note.userInfo as? [String: Any]
            Task { @MainActor [weak self] in
                guard let self, let info = userInfo else { return }
                self.handleSpotifyInfo(info)
            }
        })
    }

    private func startElapsedTimeTimer() {
        let interval = updateInterval
        tickCount = 0
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.tickCount += 1

                // Every 6 ticks (3 seconds), do a full refresh to catch missed notifications
                if self.tickCount % 6 == 0 {
                    await self.fetchNowPlayingInfo()
                    return
                }

                guard self.nowPlayingInfo.isPlaying, self.nowPlayingInfo.duration > 0 else { return }
                var updatedInfo = self.nowPlayingInfo
                updatedInfo.elapsedTime = min(
                    updatedInfo.elapsedTime + interval * max(updatedInfo.playbackRate, 1.0),
                    updatedInfo.duration
                )
                self.nowPlayingInfo = updatedInfo
            }
        }
    }

    private func handleAppleMusicInfo(_ info: [String: Any]) {
        var newInfo = nowPlayingInfo
        newInfo.title = info["Name"] as? String ?? ""
        newInfo.artist = info["Artist"] as? String ?? ""
        newInfo.album = info["Album"] as? String ?? ""
        newInfo.appName = "Music"

        let state = info["Player State"] as? String ?? ""
        newInfo.isPlaying = state == "Playing"
        newInfo.playbackRate = newInfo.isPlaying ? 1.0 : 0.0
        self.isPlaying = newInfo.isPlaying

        if let duration = info["Total Time"] as? Int {
            newInfo.duration = TimeInterval(duration) / 1000.0
        }
        if let position = info["Player Position"] as? Double {
            newInfo.elapsedTime = position
        }

        // Fetch artwork asynchronously (Apple Music)
        if newInfo.title != self.nowPlayingInfo.title || self.nowPlayingInfo.artwork == nil {
            newInfo.artwork = fetchAppleMusicArtwork()
        } else {
            newInfo.artwork = self.nowPlayingInfo.artwork
        }

        self.nowPlayingInfo = newInfo
    }

    private func handleSpotifyInfo(_ info: [String: Any]) {
        var newInfo = nowPlayingInfo
        newInfo.title = info["Name"] as? String ?? info["TrackName"] as? String ?? ""
        newInfo.artist = info["Artist"] as? String ?? ""
        newInfo.album = info["Album"] as? String ?? info["AlbumName"] as? String ?? ""
        newInfo.appName = "Spotify"

        let state = info["Player State"] as? String ?? ""
        newInfo.isPlaying = state == "Playing"
        newInfo.playbackRate = newInfo.isPlaying ? 1.0 : 0.0
        self.isPlaying = newInfo.isPlaying

        if let duration = info["Duration"] as? Int {
            newInfo.duration = TimeInterval(duration) / 1000.0
        }
        if let position = info["Playback Position"] as? Double {
            newInfo.elapsedTime = position
        }

        // Fetch artwork asynchronously (Spotify)
        if newInfo.title != self.nowPlayingInfo.title || self.nowPlayingInfo.artwork == nil {
            newInfo.artwork = fetchSpotifyArtwork()
        } else {
            newInfo.artwork = self.nowPlayingInfo.artwork
        }

        self.nowPlayingInfo = newInfo
    }

    func fetchNowPlayingInfo() async {
        // Actively query the currently-playing app for full track details.
        // This is used on initial load and periodic refresh to ensure we
        // have data even if we missed a DistributedNotification.
        let app = nowPlayingInfo.appName
        if app == "Spotify" {
            fetchSpotifyFullInfo()
        } else {
            // Default to Apple Music
            fetchAppleMusicFullInfo()
        }
    }

    private func fetchAppleMusicFullInfo() {
        let script = """
        tell application "System Events"
            if not (exists process "Music") then return "|||NOT_RUNNING|||"
        end tell
        tell application "Music"
            if player state is not playing and player state is not paused then return "|||NOT_PLAYING|||"
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to duration of current track
            set trackPosition to player position
            set playerState to player state as string
            return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration & "|||" & trackPosition & "|||" & playerState
        end tell
        """
        guard let scriptObject = NSAppleScript(source: script) else { return }
        var errorInfo: NSDictionary?
        let result = scriptObject.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else { return }
        let output = result.stringValue ?? ""
        guard !output.contains("NOT_RUNNING"), !output.contains("NOT_PLAYING") else { return }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return }

        var newInfo = nowPlayingInfo
        newInfo.title = parts[0]
        newInfo.artist = parts[1]
        newInfo.album = parts[2]
        newInfo.duration = Double(parts[3]) ?? 0
        newInfo.elapsedTime = Double(parts[4]) ?? 0
        newInfo.appName = "Music"
        let playing = parts[5].lowercased().contains("playing")
        newInfo.isPlaying = playing
        newInfo.playbackRate = playing ? 1.0 : 0.0

        // Preserve existing artwork or fetch if needed
        if newInfo.title != self.nowPlayingInfo.title || self.nowPlayingInfo.artwork == nil {
            newInfo.artwork = fetchAppleMusicArtwork()
        } else {
            newInfo.artwork = self.nowPlayingInfo.artwork
        }

        self.nowPlayingInfo = newInfo
        self.isPlaying = newInfo.isPlaying
    }

    private func fetchSpotifyFullInfo() {
        let script = """
        tell application "System Events"
            if not (exists process "Spotify") then return "|||NOT_RUNNING|||"
        end tell
        tell application "Spotify"
            if player state is not playing and player state is not paused then return "|||NOT_PLAYING|||"
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to (duration of current track) / 1000
            set trackPosition to player position
            set playerState to player state as string
            set artURL to artwork url of current track
            return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration & "|||" & trackPosition & "|||" & playerState & "|||" & artURL
        end tell
        """
        guard let scriptObject = NSAppleScript(source: script) else { return }
        var errorInfo: NSDictionary?
        let result = scriptObject.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else { return }
        let output = result.stringValue ?? ""
        guard !output.contains("NOT_RUNNING"), !output.contains("NOT_PLAYING") else { return }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return }

        var newInfo = nowPlayingInfo
        newInfo.title = parts[0]
        newInfo.artist = parts[1]
        newInfo.album = parts[2]
        newInfo.duration = Double(parts[3]) ?? 0
        newInfo.elapsedTime = Double(parts[4]) ?? 0
        newInfo.appName = "Spotify"
        let playing = parts[5].lowercased().contains("playing")
        newInfo.isPlaying = playing
        newInfo.playbackRate = playing ? 1.0 : 0.0

        // Fetch artwork from Spotify artwork URL
        if parts.count >= 7, !parts[6].isEmpty,
           newInfo.title != self.nowPlayingInfo.title || self.nowPlayingInfo.artwork == nil {
            newInfo.artwork = fetchImageFromURL(parts[6])
        } else {
            newInfo.artwork = self.nowPlayingInfo.artwork
        }

        self.nowPlayingInfo = newInfo
        self.isPlaying = newInfo.isPlaying
    }

    private func fetchAppleMusicArtwork() -> NSImage? {
        // Apple Music provides artwork via raw data AppleScript
        let script = """
        tell application "System Events"
            if not (exists process "Music") then return ""
        end tell
        tell application "Music"
            try
                set artworks to artwork 1 of current track
                return raw data of artworks
            on error
                return ""
            end try
        end tell
        """
        guard let scriptObject = NSAppleScript(source: script) else { return nil }
        var errorInfo: NSDictionary?
        let result = scriptObject.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else { return nil }

        // The raw data from AppleScript comes as an NSAppleEventDescriptor
        // We need to get the data from it
        let data = result.data
        if !data.isEmpty {
            return NSImage(data: data)
        }
        return nil
    }

    private func fetchSpotifyArtwork() -> NSImage? {
        // Spotify provides an artwork URL via AppleScript
        let script = """
        tell application "System Events"
            if not (exists process "Spotify") then return ""
        end tell
        tell application "Spotify"
            try
                return artwork url of current track
            on error
                return ""
            end try
        end tell
        """
        guard let scriptObject = NSAppleScript(source: script) else { return nil }
        var errorInfo: NSDictionary?
        let result = scriptObject.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else { return nil }
        let urlString = result.stringValue ?? ""
        guard !urlString.isEmpty else { return nil }
        return fetchImageFromURL(urlString)
    }

    private func fetchImageFromURL(_ urlString: String) -> NSImage? {
        guard let url = URL(string: urlString),
              let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }

    func play() {
        appleScript("play")
    }

    func pause() {
        appleScript("pause")
    }

    func togglePlayPause() {
        appleScript("playpause")
    }

    func nextTrack() {
        appleScript("next track")
    }

    func previousTrack() {
        appleScript("previous track")
        // Reset elapsed time on track change
        var updatedInfo = nowPlayingInfo
        updatedInfo.elapsedTime = 0
        nowPlayingInfo = updatedInfo
    }

    private func appleScript(_ command: String) {
        let app = nowPlayingInfo.appName == "Spotify" ? "Spotify" : "Music"
        let script = "tell application \"\(app)\" to \(command)"
        if let scriptObject = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            scriptObject.executeAndReturnError(&errorInfo)
            if let error = errorInfo {
                AppLogger.media.error("AppleScript error: \(error, privacy: .public)")
            }
        }
    }

    func skipForward() {
        seekToTime(min(nowPlayingInfo.elapsedTime + 15, nowPlayingInfo.duration))
    }

    func skipBackward() {
        seekToTime(max(nowPlayingInfo.elapsedTime - 15, 0))
    }

    func seekToTime(_ time: TimeInterval) {
        let app = nowPlayingInfo.appName == "Spotify" ? "Spotify" : "Music"
        let script = "tell application \"\(app)\" to set player position to \(time)"
        if let scriptObject = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            scriptObject.executeAndReturnError(&errorInfo)
        }
        // Update local state immediately for responsiveness
        var updatedInfo = nowPlayingInfo
        updatedInfo.elapsedTime = max(0, min(time, nowPlayingInfo.duration))
        nowPlayingInfo = updatedInfo
    }

    func seekToProgress(_ progress: Double) {
        guard nowPlayingInfo.duration > 0 else { return }
        let time = progress * nowPlayingInfo.duration
        seekToTime(time)
    }

    func refresh() {
        // Do a full info fetch so we pick up track details, not just position
        Task { @MainActor in
            await fetchNowPlayingInfo()
        }
    }
}
#else
import AppKit
import Combine
import Foundation

// MARK: - MediaRemote Private Framework Types

/// Command types for controlling media playback
enum MRCommand: UInt32 {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case stop = 3
    case nextTrack = 4
    case previousTrack = 5
    case advanceShuffleMode = 6
    case advanceRepeatMode = 7
    case beginFastForward = 8
    case endFastForward = 9
    case beginRewind = 10
    case endRewind = 11
    case skipForward = 12
    case skipBackward = 13
    case changePlaybackRate = 14
    case rateTrack = 15
    case likeTrack = 16
    case dislikeTrack = 17
    case bookmarkTrack = 18
    case seekToPlaybackPosition = 19
    case changeRepeatMode = 20
    case changeShuffleMode = 21
    case enableLanguageOption = 22
    case disableLanguageOption = 23
    case nextChapter = 24
    case previousChapter = 25
    case nextAlbumInList = 26
    case previousAlbumInList = 27
    case nextInContext = 28
    case previousInContext = 29
    case resetPlaybackTimeout = 30
    case insertItem = 31
    case appendItem = 32
    case setUnsupportedCommands = 33
    case setSupportedCommands = 34
    case setPlaybackQueueAirPlayAlternativeRouteForKey = 35
    case refreshPlaybackQueueMetadata = 36
    case preferredPlaybackRate = 37
    case prepareForSetQueue = 38
    case setQueue = 39
    case setQueueWithPlayerPath = 40
    case advance = 41
    case rewind = 42
    case skipToBeginning = 43
    case skipToEnd = 44
    case startPlaybackContextHostingAudioSession = 45
    case stopPlaybackContextHostingAudioSession = 46
}

// MARK: - MediaRemote Info Keys

private let kMRMediaRemoteNowPlayingInfoTitle = "kMRMediaRemoteNowPlayingInfoTitle"
private let kMRMediaRemoteNowPlayingInfoArtist = "kMRMediaRemoteNowPlayingInfoArtist"
private let kMRMediaRemoteNowPlayingInfoAlbum = "kMRMediaRemoteNowPlayingInfoAlbum"
private let kMRMediaRemoteNowPlayingInfoDuration = "kMRMediaRemoteNowPlayingInfoDuration"
private let kMRMediaRemoteNowPlayingInfoElapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
private let kMRMediaRemoteNowPlayingInfoTimestamp = "kMRMediaRemoteNowPlayingInfoTimestamp"
private let kMRMediaRemoteNowPlayingInfoPlaybackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
private let kMRMediaRemoteNowPlayingInfoArtworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
private let kMRMediaRemoteNowPlayingInfoArtworkMIMEType = "kMRMediaRemoteNowPlayingInfoArtworkMIMEType"
private let kMRNowPlayingClientBundleIdentifier = "kMRNowPlayingClientBundleIdentifier"
private let kMRMediaRemoteNowPlayingApplicationDisplayName = "kMRMediaRemoteNowPlayingApplicationDisplayName"

// MARK: - MediaRemoteController

/// Controller for interacting with the MediaRemote private framework
/// Provides now playing info and playback control
@MainActor
final class MediaRemoteController: ObservableObject {
    static let shared = MediaRemoteController()
    
    // MARK: - Published Properties
    
    @Published private(set) var nowPlayingInfo = NowPlayingInfo()
    @Published private(set) var isAvailable = false
    @Published private(set) var isPlaying = false

    // MARK: - Private Properties
    
    private var updateTimer: Timer?
    private var artworkCache: [String: NSImage] = [:]
    private let updateInterval: TimeInterval = 0.5
    
    // Function pointers from MediaRemote.framework
    private var MRMediaRemoteGetNowPlayingInfo: (@convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void)?
    private var MRMediaRemoteSendCommand: (@convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool)?
    private var MRMediaRemoteSetElapsedTime: (@convention(c) (Double) -> Void)?
    private var MRMediaRemoteRegisterForNowPlayingNotifications: (@convention(c) (DispatchQueue) -> Void)?
    private var MRMediaRemoteUnregisterForNowPlayingNotifications: (@convention(c) () -> Void)?
    
    private var bundle: CFBundle?
    
    // MARK: - Initialization
    
    private init() {
        loadMediaRemoteFramework()
        if isAvailable {
            registerForNotifications()
            startMonitoring()
        }
    }
    
    deinit {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)

        // Timer and unregister are main-actor-isolated;
        // since this is a singleton that lives for the app lifetime,
        // explicit cleanup via stopMonitoring() is preferred before dealloc.
        // The timer's weak-self reference will prevent retain issues.
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Framework Loading
    
    private func loadMediaRemoteFramework() {
        let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: frameworkPath)) else {
            return
        }
        
        self.bundle = bundle
        
        // Load MRMediaRemoteGetNowPlayingInfo
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(
                ptr,
                to: (@convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void).self
            )
        }
        
        // Load MRMediaRemoteSendCommand
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            MRMediaRemoteSendCommand = unsafeBitCast(
                ptr,
                to: (@convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool).self
            )
        }
        
        // Load MRMediaRemoteSetElapsedTime
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
            MRMediaRemoteSetElapsedTime = unsafeBitCast(
                ptr,
                to: (@convention(c) (Double) -> Void).self
            )
        }
        
        // Load notification registration functions
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) {
            MRMediaRemoteRegisterForNowPlayingNotifications = unsafeBitCast(
                ptr,
                to: (@convention(c) (DispatchQueue) -> Void).self
            )
        }
        
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteUnregisterForNowPlayingNotifications" as CFString) {
            MRMediaRemoteUnregisterForNowPlayingNotifications = unsafeBitCast(
                ptr,
                to: (@convention(c) () -> Void).self
            )
        }
        
        isAvailable = MRMediaRemoteGetNowPlayingInfo != nil && MRMediaRemoteSendCommand != nil
        
        // isAvailable reflects whether the framework loaded successfully
    }
    
    // MARK: - Notification Registration
    
    private func registerForNotifications() {
        MRMediaRemoteRegisterForNowPlayingNotifications?(DispatchQueue.main)
        
        // Listen for now playing info changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleNowPlayingInfoDidChange),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil
        )
        
        // Listen for playback state changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleNowPlayingInfoDidChange),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil
        )
    }
    
    @objc private func handleNowPlayingInfoDidChange() {
        Task { @MainActor in
            await fetchNowPlayingInfo()
        }
    }
    
    // MARK: - Monitoring
    
    private var tickCount: Int = 0

    private func startMonitoring() {
        // Initial fetch
        Task { @MainActor in
            await fetchNowPlayingInfo()
        }

        tickCount = 0

        // Periodic updates — re-fetch full info every 3 seconds (6 ticks at 0.5s),
        // otherwise just increment elapsed time for smooth progress bar updates.
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.tickCount += 1
                if self.tickCount % 6 == 0 {
                    await self.fetchNowPlayingInfo()
                } else {
                    await self.updateElapsedTime()
                }
            }
        }
    }
    
    private func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
        MRMediaRemoteUnregisterForNowPlayingNotifications?()
    }
    
    // MARK: - Now Playing Info
    
    func fetchNowPlayingInfo() async {
        guard let getInfo = MRMediaRemoteGetNowPlayingInfo else { return }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            getInfo(DispatchQueue.main) { [weak self] info in
                Task { @MainActor in
                    self?.parseNowPlayingInfo(info)
                    continuation.resume()
                }
            }
        }
    }
    
    private func parseNowPlayingInfo(_ info: [String: Any]) {
        var newInfo = NowPlayingInfo()
        
        // Basic track info
        newInfo.title = info[kMRMediaRemoteNowPlayingInfoTitle] as? String ?? ""
        newInfo.artist = info[kMRMediaRemoteNowPlayingInfoArtist] as? String ?? ""
        newInfo.album = info[kMRMediaRemoteNowPlayingInfoAlbum] as? String ?? ""
        
        // Timing info
        newInfo.duration = info[kMRMediaRemoteNowPlayingInfoDuration] as? TimeInterval ?? 0
        newInfo.elapsedTime = calculateElapsedTime(from: info)
        newInfo.playbackRate = info[kMRMediaRemoteNowPlayingInfoPlaybackRate] as? Double ?? 0
        newInfo.isPlaying = newInfo.playbackRate > 0
        
        // App info
        newInfo.bundleIdentifier = info[kMRNowPlayingClientBundleIdentifier] as? String ?? ""
        newInfo.appName = info[kMRMediaRemoteNowPlayingApplicationDisplayName] as? String ?? getAppName(from: newInfo.bundleIdentifier)
        
        // Artwork
        if let artworkData = info[kMRMediaRemoteNowPlayingInfoArtworkData] as? Data {
            newInfo.artwork = loadArtwork(from: artworkData, for: newInfo.title)
        } else {
            newInfo.artwork = nil
        }
        
        self.nowPlayingInfo = newInfo
        self.isPlaying = newInfo.isPlaying
    }

    private func calculateElapsedTime(from info: [String: Any]) -> TimeInterval {
        let storedElapsed = info[kMRMediaRemoteNowPlayingInfoElapsedTime] as? TimeInterval ?? 0
        let timestamp = info[kMRMediaRemoteNowPlayingInfoTimestamp] as? Date
        let playbackRate = info[kMRMediaRemoteNowPlayingInfoPlaybackRate] as? Double ?? 0
        
        // If playing, calculate current elapsed time based on timestamp
        if playbackRate > 0, let ts = timestamp {
            let timeSinceUpdate = Date().timeIntervalSince(ts)
            return storedElapsed + (timeSinceUpdate * playbackRate)
        }
        
        return storedElapsed
    }
    
    private func updateElapsedTime() async {
        guard nowPlayingInfo.isPlaying, nowPlayingInfo.duration > 0 else { return }
        
        // Increment elapsed time based on playback rate
        var updatedInfo = nowPlayingInfo
        updatedInfo.elapsedTime += updateInterval * updatedInfo.playbackRate
        
        // Clamp to duration
        updatedInfo.elapsedTime = min(updatedInfo.elapsedTime, updatedInfo.duration)
        
        self.nowPlayingInfo = updatedInfo
    }
    
    private func loadArtwork(from data: Data, for title: String) -> NSImage? {
        // Check cache first
        let cacheKey = "\(title)_\(data.hashValue)"
        if let cached = artworkCache[cacheKey] {
            return cached
        }
        
        // Create image from data
        if let image = NSImage(data: data) {
            // Limit cache size
            if artworkCache.count > 20 {
                artworkCache.removeAll()
            }
            artworkCache[cacheKey] = image
            return image
        }
        
        return nil
    }
    
    private func getAppName(from bundleId: String) -> String {
        if bundleId.contains("spotify") { return "Spotify" }
        if bundleId.contains("Music") || bundleId.contains("music") { return "Music" }
        if bundleId.contains("safari") { return "Safari" }
        if bundleId.contains("chrome") { return "Chrome" }
        if bundleId.contains("firefox") { return "Firefox" }
        if bundleId.contains("arc") { return "Arc" }
        if bundleId.contains("youtube") { return "YouTube" }
        if bundleId.contains("vlc") { return "VLC" }
        return "Media"
    }
    
    // MARK: - Playback Control
    
    func play() {
        sendCommand(.play)
    }
    
    func pause() {
        sendCommand(.pause)
    }
    
    func togglePlayPause() {
        sendCommand(.togglePlayPause)
    }
    
    func nextTrack() {
        sendCommand(.nextTrack)
    }
    
    func previousTrack() {
        sendCommand(.previousTrack)
    }
    
    func skipForward() {
        sendCommand(.skipForward)
    }
    
    func skipBackward() {
        sendCommand(.skipBackward)
    }
    
    func seekToTime(_ time: TimeInterval) {
        MRMediaRemoteSetElapsedTime?(time)
        
        // Update local state immediately for responsiveness
        var updatedInfo = nowPlayingInfo
        updatedInfo.elapsedTime = time
        nowPlayingInfo = updatedInfo
    }
    
    func seekToProgress(_ progress: Double) {
        guard nowPlayingInfo.duration > 0 else { return }
        let time = progress * nowPlayingInfo.duration
        seekToTime(time)
    }
    
    private func sendCommand(_ command: MRCommand) {
        guard let send = MRMediaRemoteSendCommand else { return }
        _ = send(command.rawValue, nil)
        
        // Fetch updated info after command
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
            await fetchNowPlayingInfo()
        }
    }
    
    // MARK: - Force Refresh
    
    func refresh() {
        Task { @MainActor in
            await fetchNowPlayingInfo()
        }
    }
}
#endif

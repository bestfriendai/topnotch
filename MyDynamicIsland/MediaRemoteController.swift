#if APP_STORE_BUILD
import AppKit
import Combine
import Foundation
import OSLog

// MARK: - App Store Build: AppleScript-based MediaRemoteController

@MainActor
final class MediaRemoteController: ObservableObject, MediaControlling {
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
        startMonitoring()
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

    // MARK: - Notification Observers

    private func setupObservers() {
        let center = DistributedNotificationCenter.default()

        // Apple Music
        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] note in
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

    // MARK: - Monitoring

    func startMonitoring() {
        tickCount = 0
        let interval = updateInterval
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.tickCount += 1

                // Poll less frequently when idle (every 10s vs 3s)
                let pollInterval = self.nowPlayingInfo.isPlaying ? 6 : 20
                if self.tickCount % pollInterval == 0 {
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

    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Distributed Notification Handlers

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

        let titleChanged = newInfo.title != self.nowPlayingInfo.title
        newInfo.artwork = self.nowPlayingInfo.artwork
        self.nowPlayingInfo = newInfo

        if titleChanged || newInfo.artwork == nil {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let image = await self.fetchAppleMusicArtworkAsync() {
                    var updated = self.nowPlayingInfo
                    updated.artwork = image
                    updated.dominantColor = ArtworkColorExtractor.extract(from: image)
                    self.nowPlayingInfo = updated
                }
            }
        }
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

        let titleChanged = newInfo.title != self.nowPlayingInfo.title
        let rawArtURL = info["Track Art URL"] as? String ?? info["Image URL"] as? String
        let artURL = (rawArtURL == "missing value" || rawArtURL?.isEmpty == true) ? nil : rawArtURL
        newInfo.artwork = self.nowPlayingInfo.artwork
        self.nowPlayingInfo = newInfo

        if titleChanged || newInfo.artwork == nil {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let image: NSImage?
                if let url = artURL, !url.isEmpty {
                    image = await MediaRemoteHelpers.fetchImageFromURL(url)
                } else {
                    image = await self.fetchSpotifyArtworkAsync()
                }
                if let image {
                    var updated = self.nowPlayingInfo
                    updated.artwork = image
                    updated.dominantColor = ArtworkColorExtractor.extract(from: image)
                    self.nowPlayingInfo = updated
                }
            }
        }
    }

    // MARK: - Full Info Fetching

    func fetchNowPlayingInfo() async {
        let app = nowPlayingInfo.appName
        if app == "Spotify" {
            await fetchSpotifyFullInfo()
        } else if app == "Music" {
            await fetchAppleMusicFullInfo()
        } else {
            let titleBefore = nowPlayingInfo.title
            await fetchSpotifyFullInfo()
            if nowPlayingInfo.title == titleBefore || nowPlayingInfo.title.isEmpty {
                await fetchAppleMusicFullInfo()
            }
        }
    }

    private func fetchAppleMusicFullInfo() async {
        let existingTitle = nowPlayingInfo.title
        let existingArtwork = nowPlayingInfo.artwork

        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty else { return }

        let output = await MediaRemoteHelpers.runAppleScript(MediaRemoteHelpers.musicFullInfoScript)
        guard let output, !output.contains("NOT_RUNNING"), !output.contains("NOT_PLAYING") else { return }
        guard var newInfo = MediaRemoteHelpers.parseMusicOutput(output) else { return }

        if newInfo.title != existingTitle || existingArtwork == nil {
            newInfo.artwork = await fetchAppleMusicArtworkAsync()
        } else {
            newInfo.artwork = existingArtwork
        }

        if let image = newInfo.artwork {
            newInfo.dominantColor = ArtworkColorExtractor.extract(from: image)
        }
        self.nowPlayingInfo = newInfo
        self.isPlaying = newInfo.isPlaying
    }

    private func fetchSpotifyFullInfo() async {
        let existingTitle = nowPlayingInfo.title
        let existingArtwork = nowPlayingInfo.artwork

        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty else { return }

        let output = await MediaRemoteHelpers.runAppleScript(MediaRemoteHelpers.spotifyFullInfoScript)
        guard let output, !output.contains("NOT_RUNNING"), !output.contains("NOT_PLAYING") else { return }
        guard let parsed = MediaRemoteHelpers.parseSpotifyOutput(output) else { return }
        var newInfo = parsed.info

        if let artURL = parsed.artURL,
           (newInfo.title != existingTitle || existingArtwork == nil) {
            newInfo.artwork = await MediaRemoteHelpers.fetchImageFromURL(artURL)
        } else {
            newInfo.artwork = existingArtwork
        }

        if let image = newInfo.artwork {
            newInfo.dominantColor = ArtworkColorExtractor.extract(from: image)
        }
        self.nowPlayingInfo = newInfo
        self.isPlaying = newInfo.isPlaying
    }

    // MARK: - Artwork Fetching

    private func fetchAppleMusicArtworkAsync() async -> NSImage? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty else { return nil }
        guard let data = await MediaRemoteHelpers.runAppleScriptData(MediaRemoteHelpers.musicArtworkScript) else { return nil }
        return data.isEmpty ? nil : NSImage(data: data)
    }

    private func fetchSpotifyArtworkAsync() async -> NSImage? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty else { return nil }
        guard let urlString = await MediaRemoteHelpers.runAppleScript(MediaRemoteHelpers.spotifyArtworkURLScript),
              !urlString.isEmpty else { return nil }
        return await MediaRemoteHelpers.fetchImageFromURL(urlString)
    }

    // MARK: - Playback Control

    func play() {
        MediaRemoteHelpers.sendAppleScriptCommand("play", to: currentAppName)
    }

    func pause() {
        MediaRemoteHelpers.sendAppleScriptCommand("pause", to: currentAppName)
    }

    func togglePlayPause() {
        MediaRemoteHelpers.sendAppleScriptCommand("playpause", to: currentAppName)
    }

    func nextTrack() {
        MediaRemoteHelpers.sendAppleScriptCommand("next track", to: currentAppName)
    }

    func previousTrack() {
        MediaRemoteHelpers.sendAppleScriptCommand("previous track", to: currentAppName)
        var updatedInfo = nowPlayingInfo
        updatedInfo.elapsedTime = 0
        nowPlayingInfo = updatedInfo
    }

    func skipForward() {
        seekToTime(min(nowPlayingInfo.elapsedTime + 15, nowPlayingInfo.duration))
    }

    func skipBackward() {
        seekToTime(max(nowPlayingInfo.elapsedTime - 15, 0))
    }

    func seekToTime(_ time: TimeInterval) {
        let app = currentAppName
        let script = "tell application \"\(app)\" to set player position to \(time)"
        Task.detached(priority: .userInitiated) {
            if let scriptObject = NSAppleScript(source: script) {
                var errorInfo: NSDictionary?
                scriptObject.executeAndReturnError(&errorInfo)
            }
        }
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
        Task { @MainActor in
            await fetchNowPlayingInfo()
        }
    }

    // MARK: - Private Helpers

    private var currentAppName: String {
        nowPlayingInfo.appName == "Spotify" ? "Spotify" : "Music"
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

// MARK: - MediaRemoteController (MediaRemote Framework)

/// Controller for interacting with the MediaRemote private framework.
/// Provides now playing info and playback control.
@MainActor
final class MediaRemoteController: ObservableObject, MediaControlling {
    static let shared = MediaRemoteController()

    // MARK: - Published Properties

    @Published private(set) var nowPlayingInfo = NowPlayingInfo()
    @Published private(set) var isAvailable = false
    @Published private(set) var isPlaying = false

    // MARK: - Private Properties

    private var updateTimer: Timer?
    private var artworkCache: [String: NSImage] = [:]
    private let updateInterval: TimeInterval = 0.5
    private var tickCount: Int = 0

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
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
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

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(
                ptr,
                to: (@convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void).self
            )
        }

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            MRMediaRemoteSendCommand = unsafeBitCast(
                ptr,
                to: (@convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool).self
            )
        }

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
            MRMediaRemoteSetElapsedTime = unsafeBitCast(
                ptr,
                to: (@convention(c) (Double) -> Void).self
            )
        }

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
    }

    // MARK: - Notification Registration

    private func registerForNotifications() {
        MRMediaRemoteRegisterForNowPlayingNotifications?(DispatchQueue.main)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNowPlayingInfoDidChange),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
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

    func startMonitoring() {
        Task { @MainActor in
            await fetchNowPlayingInfo()
        }

        tickCount = 0

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

    func stopMonitoring() {
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
                    // MediaRemote may not track Spotify on newer macOS -- fall back to AppleScript
                    if self?.nowPlayingInfo.title.isEmpty == true {
                        await self?.fetchAppleScriptFallback()
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func fetchAppleScriptFallback() async {
        // Try Spotify first via AppleScript
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty {
            let output = await MediaRemoteHelpers.runAppleScript(MediaRemoteHelpers.spotifyFullInfoScript)
            if let output, !output.contains("NOT_PLAYING") {
                if let parsed = MediaRemoteHelpers.parseSpotifyOutput(output) {
                    var newInfo = parsed.info
                    if let artURL = parsed.artURL {
                        newInfo.artwork = await MediaRemoteHelpers.fetchImageFromURL(artURL)
                    }
                    if let image = newInfo.artwork {
                        newInfo.dominantColor = ArtworkColorExtractor.extract(from: image)
                    }
                    self.nowPlayingInfo = newInfo
                    self.isPlaying = newInfo.isPlaying
                    return
                }
            }
        }

        // Try Apple Music
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty {
            let output = await MediaRemoteHelpers.runAppleScript(MediaRemoteHelpers.musicFullInfoScript)
            if let output, !output.contains("NOT_PLAYING") {
                if var newInfo = MediaRemoteHelpers.parseMusicOutput(output) {
                    if let image = newInfo.artwork {
                        newInfo.dominantColor = ArtworkColorExtractor.extract(from: image)
                    }
                    self.nowPlayingInfo = newInfo
                    self.isPlaying = newInfo.isPlaying
                }
            }
        }
    }

    private func parseNowPlayingInfo(_ info: [String: Any]) {
        var newInfo = NowPlayingInfo()

        newInfo.title = info[kMRMediaRemoteNowPlayingInfoTitle] as? String ?? ""
        newInfo.artist = info[kMRMediaRemoteNowPlayingInfoArtist] as? String ?? ""
        newInfo.album = info[kMRMediaRemoteNowPlayingInfoAlbum] as? String ?? ""

        newInfo.duration = info[kMRMediaRemoteNowPlayingInfoDuration] as? TimeInterval ?? 0
        newInfo.elapsedTime = calculateElapsedTime(from: info)
        newInfo.playbackRate = info[kMRMediaRemoteNowPlayingInfoPlaybackRate] as? Double ?? 0
        newInfo.isPlaying = newInfo.playbackRate > 0

        newInfo.bundleIdentifier = info[kMRNowPlayingClientBundleIdentifier] as? String ?? ""
        newInfo.appName = info[kMRMediaRemoteNowPlayingApplicationDisplayName] as? String ?? MediaRemoteHelpers.appName(from: newInfo.bundleIdentifier)

        if let artworkData = info[kMRMediaRemoteNowPlayingInfoArtworkData] as? Data {
            newInfo.artwork = loadArtwork(from: artworkData, for: newInfo.title)
        } else {
            newInfo.artwork = nil
        }

        if let image = newInfo.artwork {
            newInfo.dominantColor = ArtworkColorExtractor.extract(from: image)
        }
        self.nowPlayingInfo = newInfo
        self.isPlaying = newInfo.isPlaying
    }

    private func calculateElapsedTime(from info: [String: Any]) -> TimeInterval {
        let storedElapsed = info[kMRMediaRemoteNowPlayingInfoElapsedTime] as? TimeInterval ?? 0
        let timestamp = info[kMRMediaRemoteNowPlayingInfoTimestamp] as? Date
        let playbackRate = info[kMRMediaRemoteNowPlayingInfoPlaybackRate] as? Double ?? 0

        if playbackRate > 0, let ts = timestamp {
            let timeSinceUpdate = Date().timeIntervalSince(ts)
            return storedElapsed + (timeSinceUpdate * playbackRate)
        }

        return storedElapsed
    }

    private func updateElapsedTime() async {
        guard nowPlayingInfo.isPlaying, nowPlayingInfo.duration > 0 else { return }

        var updatedInfo = nowPlayingInfo
        updatedInfo.elapsedTime += updateInterval * updatedInfo.playbackRate
        updatedInfo.elapsedTime = min(updatedInfo.elapsedTime, updatedInfo.duration)

        self.nowPlayingInfo = updatedInfo
    }

    private func loadArtwork(from data: Data, for title: String) -> NSImage? {
        let cacheKey = "\(title)_\(data.hashValue)"
        if let cached = artworkCache[cacheKey] {
            return cached
        }

        if let image = NSImage(data: data) {
            if artworkCache.count > 20 {
                artworkCache.removeAll()
            }
            artworkCache[cacheKey] = image
            return image
        }

        return nil
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

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
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

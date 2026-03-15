#if APP_STORE_BUILD
import AppKit
import Combine
import Foundation

@MainActor
final class MediaRemoteController: ObservableObject {
    static let shared = MediaRemoteController()

    @Published private(set) var nowPlayingInfo = NowPlayingInfo()
    @Published private(set) var isAvailable = false

    private init() {}

    func fetchNowPlayingInfo() async {}
    func play() {}
    func pause() {}
    func togglePlayPause() {}
    func nextTrack() {}
    func previousTrack() {}
    func skipForward() {}
    func skipBackward() {}
    func seekToTime(_ time: TimeInterval) {}
    func seekToProgress(_ progress: Double) {}
    func refresh() {}
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
        // Use nonisolated wrapper to call actor-isolated method from deinit
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self)
    }
    
    // MARK: - Framework Loading
    
    private func loadMediaRemoteFramework() {
        let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: frameworkPath)) else {
            print("MediaRemoteController: Failed to load MediaRemote.framework")
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
        
        if isAvailable {
            print("MediaRemoteController: Successfully loaded MediaRemote.framework")
        } else {
            print("MediaRemoteController: Failed to load required functions from MediaRemote.framework")
        }
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

import AppKit
import Combine
import Foundation
import OSLog

// MARK: - MediaControlling Protocol

/// Protocol that unifies media playback control across different implementations.
/// Both the App Store (AppleScript-based) and direct-distribution (MediaRemote framework)
/// builds conform to this protocol.
@MainActor
protocol MediaControlling: ObservableObject {
    var nowPlayingInfo: NowPlayingInfo { get }
    var isAvailable: Bool { get }
    var isPlaying: Bool { get }

    func play()
    func pause()
    func togglePlayPause()
    func nextTrack()
    func previousTrack()
    func skipForward()
    func skipBackward()
    func seekToTime(_ time: TimeInterval)
    func seekToProgress(_ progress: Double)
    func refresh()
    func fetchNowPlayingInfo() async
}

// MARK: - Shared Utilities

/// Shared helper methods used by both MediaRemoteController implementations.
enum MediaRemoteHelpers {

    // MARK: - AppleScript Execution

    /// Run an AppleScript source string off the main thread and return the string result.
    static func runAppleScript(_ source: String) async -> String? {
        await Task.detached(priority: .userInitiated) {
            guard let scriptObject = NSAppleScript(source: source) else { return nil }
            var errorInfo: NSDictionary?
            let result = scriptObject.executeAndReturnError(&errorInfo)
            guard errorInfo == nil else { return nil }
            return result.stringValue
        }.value
    }

    /// Run an AppleScript source string off the main thread and return raw data.
    static func runAppleScriptData(_ source: String) async -> Data? {
        await Task.detached(priority: .utility) {
            guard let scriptObject = NSAppleScript(source: source) else { return nil }
            var errorInfo: NSDictionary?
            let result = scriptObject.executeAndReturnError(&errorInfo)
            guard errorInfo == nil else { return nil }
            return result.data
        }.value
    }

    /// Send a simple command to a media app via AppleScript (fire-and-forget on main thread).
    static func sendAppleScriptCommand(_ command: String, to appName: String) {
        let script = "tell application \"\(appName)\" to \(command)"
        if let scriptObject = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            scriptObject.executeAndReturnError(&errorInfo)
            if let error = errorInfo {
                AppLogger.media.error("AppleScript error: \(error, privacy: .public)")
            }
        }
    }

    // MARK: - Image Fetching

    /// Fetch an image from a URL string, filtering out invalid/missing values.
    static func fetchImageFromURL(_ urlString: String) async -> NSImage? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != "missing value",
              let url = URL(string: trimmed),
              url.scheme == "http" || url.scheme == "https",
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }

    // MARK: - App Name Resolution

    /// Resolve a human-readable app name from a bundle identifier.
    static func appName(from bundleId: String) -> String {
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

    // MARK: - AppleScript Output Parsing

    /// Parse the pipe-delimited output from the Spotify AppleScript query into a NowPlayingInfo.
    /// Expected format: `title|||artist|||album|||duration|||position|||state[|||artURL]`
    static func parseSpotifyOutput(_ output: String) -> (info: NowPlayingInfo, artURL: String?)? {
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6, !parts[0].isEmpty else { return nil }
        var info = NowPlayingInfo()
        info.title = parts[0]
        info.artist = parts[1]
        info.album = parts[2]
        info.duration = Double(parts[3]) ?? 0
        info.elapsedTime = Double(parts[4]) ?? 0
        info.appName = "Spotify"
        info.bundleIdentifier = "com.spotify.client"
        let playing = parts[5].lowercased().contains("playing")
        info.isPlaying = playing
        info.playbackRate = playing ? 1.0 : 0.0
        let artURL = parts.count >= 7 && !parts[6].isEmpty ? parts[6] : nil
        return (info, artURL)
    }

    /// Parse the pipe-delimited output from the Apple Music AppleScript query into a NowPlayingInfo.
    /// Expected format: `title|||artist|||album|||duration|||position|||state`
    static func parseMusicOutput(_ output: String) -> NowPlayingInfo? {
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6, !parts[0].isEmpty else { return nil }
        var info = NowPlayingInfo()
        info.title = parts[0]
        info.artist = parts[1]
        info.album = parts[2]
        info.duration = Double(parts[3]) ?? 0
        info.elapsedTime = Double(parts[4]) ?? 0
        info.appName = "Music"
        info.bundleIdentifier = "com.apple.Music"
        let playing = parts[5].lowercased().contains("playing")
        info.isPlaying = playing
        info.playbackRate = playing ? 1.0 : 0.0
        return info
    }

    // MARK: - AppleScript Sources

    static let spotifyFullInfoScript = """
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

    static let musicFullInfoScript = """
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

    static let musicArtworkScript = """
        tell application "Music"
            try
                set artworks to artwork 1 of current track
                return raw data of artworks
            on error
                return ""
            end try
        end tell
        """

    static let spotifyArtworkURLScript = """
        tell application "Spotify"
            try
                return artwork url of current track
            on error
                return ""
            end try
        end tell
        """
}

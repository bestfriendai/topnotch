import Foundation
import Combine
import SwiftUI

enum YouTubePlaybackMode: Equatable {
    case embed
    case watchPageFallback
}

/// Observable state object for the YouTube player
@MainActor
final class YouTubePlayerState: ObservableObject {
    
    // MARK: - Playback State
    
    /// Whether the video is currently playing
    @Published var isPlaying: Bool = false
    
    /// Whether the player is ready to play
    @Published var isReady: Bool = false
    
    /// Whether the video is currently buffering
    @Published var isBuffering: Bool = false
    
    /// Current playback time in seconds
    @Published var currentTime: Double = 0
    
    /// Total duration of the video in seconds
    @Published var duration: Double = 0
    
    /// Current volume level (0.0 to 1.0)
    @Published var volume: Double = 1.0
    
    /// Whether audio is muted
    @Published var isMuted: Bool = false
    
    /// Current playback rate (0.25, 0.5, 1.0, 1.5, 2.0)
    @Published var playbackRate: Double = 1.0
    
    // MARK: - Video Information
    
    /// Current video ID
    @Published var videoID: String?
    
    /// Current video ID for external use (set when loadVideo is called)
    @Published var currentVideoID: String?
    
    /// Video title (if available)
    @Published var videoTitle: String?
    
    /// Video thumbnail URL
    @Published var thumbnailURL: URL?
    
    // MARK: - Error State
    
    /// Current error, if any
    @Published var error: YouTubePlayerError?
    
    /// Whether an error is currently displayed
    var hasError: Bool { error != nil }
    
    // MARK: - UI State
    
    /// Whether controls should be visible
    @Published var controlsVisible: Bool = true
    
    /// Whether the player is in fullscreen mode
    @Published var isFullscreen: Bool = false
    
    /// Whether Picture-in-Picture is active
    @Published var isPiPActive: Bool = false

    /// Current playback mode.
    @Published var playbackMode: YouTubePlaybackMode = .embed
    
    // MARK: - Computed Properties
    
    /// Progress as a percentage (0.0 to 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    /// Formatted current time string (MM:SS or HH:MM:SS)
    var currentTimeFormatted: String {
        formatTime(currentTime)
    }
    
    /// Formatted duration string (MM:SS or HH:MM:SS)
    var durationFormatted: String {
        formatTime(duration)
    }
    
    /// Formatted remaining time string (MM:SS or HH:MM:SS)
    var remainingTimeFormatted: String {
        let remaining = max(0, duration - currentTime)
        return "-" + formatTime(remaining)
    }
    
    /// Playback state description for accessibility
    var playbackStateDescription: String {
        if isBuffering { return "Buffering" }
        if isPlaying { return "Playing" }
        return "Paused"
    }
    
    // MARK: - Initialization
    
    init() {}
    
    init(videoID: String) {
        self.videoID = videoID
        self.thumbnailURL = YouTubeURLParser.thumbnailURL(for: videoID)
    }
    
    // MARK: - State Updates
    
    /// Resets the player state for a new video
    func reset() {
        isPlaying = false
        isReady = false
        isBuffering = false
        currentTime = 0
        duration = 0
        error = nil
        videoTitle = nil
        playbackMode = .embed
    }
    
    /// Loads a new video
    func loadVideo(id: String) {
        reset()
        videoID = id
        currentVideoID = id
        thumbnailURL = YouTubeURLParser.thumbnailURL(for: id)
    }
    
    /// Updates playback state from YouTube player state code
    func updatePlaybackState(from stateCode: Int) {
        // YouTube player state codes:
        // -1 = unstarted, 0 = ended, 1 = playing, 2 = paused, 3 = buffering, 5 = cued
        switch stateCode {
        case -1:
            isPlaying = false
            isBuffering = false
        case 0:
            isPlaying = false
            isBuffering = false
            // Video ended
        case 1:
            isPlaying = true
            isBuffering = false
            isReady = true
        case 2:
            isPlaying = false
            isBuffering = false
        case 3:
            isBuffering = true
        case 5:
            isReady = true
            isPlaying = false
            isBuffering = false
        default:
            break
        }
    }
    
    /// Sets an error state
    func setError(_ playerError: YouTubePlayerError) {
        self.error = playerError
        isPlaying = false
        isBuffering = false
    }
    
    /// Clears the current error
    func clearError() {
        error = nil
    }

    func switchToWatchPageFallback() {
        error = nil
        isReady = true
        isBuffering = false
        playbackMode = .watchPageFallback
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        
        let totalSeconds = Int(max(0, seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during YouTube playback
enum YouTubePlayerError: Error, LocalizedError {
    case invalidVideoID
    case videoNotFound
    case embeddingDisabled
    case videoUnavailable
    case networkError
    case playbackError(code: Int)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidVideoID:
            return "Invalid video ID"
        case .videoNotFound:
            return "Video not found"
        case .embeddingDisabled:
            return "Embedding disabled for this video"
        case .videoUnavailable:
            return "Video unavailable"
        case .networkError:
            return "Network error"
        case .playbackError(let code):
            return "Playback error (code: \(code))"
        case .unknown(let message):
            return message
        }
    }
    
    /// Creates an error from a YouTube error code
    static func fromYouTubeErrorCode(_ code: Int) -> YouTubePlayerError {
        switch code {
        case 2:
            return .invalidVideoID
        case 5:
            return .playbackError(code: 5)
        case 100:
            return .videoNotFound
        case 101, 150, 152, 153:
            return .embeddingDisabled
        default:
            return .playbackError(code: code)
        }
    }
}

// MARK: - Playback Rate Options

extension YouTubePlayerState {
    /// Available playback rate options
    static let playbackRates: [Double] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    /// Returns the next playback rate in the cycle
    func nextPlaybackRate() -> Double {
        guard let currentIndex = Self.playbackRates.firstIndex(of: playbackRate) else {
            return 1.0
        }
        let nextIndex = (currentIndex + 1) % Self.playbackRates.count
        return Self.playbackRates[nextIndex]
    }
}

import AppKit
import Foundation

/// Model representing the current now playing media information
struct NowPlayingInfo: Equatable {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var artwork: NSImage?
    var duration: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var isPlaying: Bool = false
    var playbackRate: Double = 0
    var bundleIdentifier: String = ""
    var appName: String = ""
    
    /// Progress as a value between 0 and 1
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1.0, max(0.0, elapsedTime / duration))
    }
    
    /// Remaining time in seconds
    var remainingTime: TimeInterval {
        max(0, duration - elapsedTime)
    }
    
    /// Formatted elapsed time string (MM:SS or H:MM:SS)
    var elapsedTimeString: String {
        formatTime(elapsedTime)
    }
    
    /// Formatted remaining time string with negative sign
    var remainingTimeString: String {
        "-" + formatTime(remainingTime)
    }
    
    /// Formatted duration string
    var durationString: String {
        formatTime(duration)
    }
    
    /// Check if we have valid media info
    var hasMedia: Bool {
        !title.isEmpty || !artist.isEmpty || isPlaying
    }
    
    /// Get the appropriate SF Symbol for the source app
    var appIcon: String {
        switch appName.lowercased() {
        case "spotify":
            return "beats.headphones"
        case "music", "apple music":
            return "music.note"
        case "safari":
            return "safari"
        case "chrome", "google chrome":
            return "globe"
        case "firefox":
            return "flame"
        case "arc":
            return "globe"
        case "youtube", "youtube music":
            return "play.rectangle.fill"
        case "soundcloud":
            return "cloud.fill"
        case "podcasts", "apple podcasts":
            return "mic.fill"
        case "audible":
            return "book.fill"
        case "vlc":
            return "play.circle.fill"
        case "quicktime player":
            return "play.rectangle.fill"
        default:
            return "music.note"
        }
    }
    
    /// Get the theme color for the source app
    var appColor: NSColor {
        switch appName.lowercased() {
        case "spotify":
            return NSColor(red: 0.12, green: 0.84, blue: 0.38, alpha: 1.0) // Spotify green
        case "music", "apple music":
            return NSColor(red: 0.98, green: 0.24, blue: 0.38, alpha: 1.0) // Apple Music red
        case "youtube", "youtube music":
            return NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) // YouTube red
        case "soundcloud":
            return NSColor(red: 1.0, green: 0.33, blue: 0.0, alpha: 1.0) // SoundCloud orange
        case "podcasts", "apple podcasts":
            return NSColor(red: 0.55, green: 0.24, blue: 0.86, alpha: 1.0) // Podcasts purple
        case "safari", "chrome", "firefox", "arc":
            return NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // Browser blue
        default:
            return NSColor(red: 0.12, green: 0.84, blue: 0.38, alpha: 1.0) // Default green
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        guard interval.isFinite && interval >= 0 else { return "0:00" }
        
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    static func == (lhs: NowPlayingInfo, rhs: NowPlayingInfo) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        abs(lhs.duration - rhs.duration) < 0.5 // Allow small tolerance
    }
}

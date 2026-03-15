import Foundation

/// Parses various YouTube URL formats and extracts video IDs
struct YouTubeURLParser {
    
    /// Supported YouTube URL patterns
    private static let patterns: [(regex: String, captureGroup: Int)] = [
        // Standard watch URLs: youtube.com/watch?v=VIDEO_ID
        (#"(?:youtube\.com/watch\?.*v=)([a-zA-Z0-9_-]{11})"#, 1),
        // Short URLs: youtu.be/VIDEO_ID
        (#"(?:youtu\.be/)([a-zA-Z0-9_-]{11})"#, 1),
        // Embed URLs: youtube.com/embed/VIDEO_ID
        (#"(?:youtube\.com/embed/)([a-zA-Z0-9_-]{11})"#, 1),
        // YouTube Shorts: youtube.com/shorts/VIDEO_ID
        (#"(?:youtube\.com/shorts/)([a-zA-Z0-9_-]{11})"#, 1),
        // YouTube Live: youtube.com/live/VIDEO_ID
        (#"(?:youtube\.com/live/)([a-zA-Z0-9_-]{11})"#, 1),
        // YouTube Music: music.youtube.com/watch?v=VIDEO_ID
        (#"(?:music\.youtube\.com/watch\?.*v=)([a-zA-Z0-9_-]{11})"#, 1),
        // YouTube nocookie embed: youtube-nocookie.com/embed/VIDEO_ID
        (#"(?:youtube-nocookie\.com/embed/)([a-zA-Z0-9_-]{11})"#, 1),
        // Raw video ID (11 characters, alphanumeric with - and _)
        (#"^([a-zA-Z0-9_-]{11})$"#, 1)
    ]
    
    /// Extracts the video ID from a YouTube URL or raw ID
    /// - Parameter input: A YouTube URL or raw video ID
    /// - Returns: The extracted video ID, or nil if not found
    static func extractVideoID(from input: String) -> String? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for (pattern, captureGroup) in patterns {
            if let videoID = matchPattern(pattern, in: trimmedInput, captureGroup: captureGroup) {
                return videoID
            }
        }
        
        return nil
    }
    
    /// Validates whether a string is a valid YouTube video ID
    /// - Parameter id: The string to validate
    /// - Returns: True if the string is a valid 11-character video ID
    static func isValidVideoID(_ id: String) -> Bool {
        let pattern = #"^[a-zA-Z0-9_-]{11}$"#
        return id.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Generates a standard YouTube watch URL from a video ID
    /// - Parameter videoID: The video ID
    /// - Returns: The full YouTube URL
    static func youtubeURL(for videoID: String) -> URL? {
        guard isValidVideoID(videoID) else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
    }
    
    /// Generates a YouTube embed URL from a video ID
    /// - Parameter videoID: The video ID
    /// - Returns: The embed URL
    static func embedURL(for videoID: String) -> URL? {
        guard isValidVideoID(videoID) else { return nil }
        return URL(string: "https://www.youtube.com/embed/\(videoID)")
    }
    
    /// Generates a YouTube thumbnail URL for a video
    /// - Parameters:
    ///   - videoID: The video ID
    ///   - quality: The thumbnail quality (default, medium, high, standard, maxres)
    /// - Returns: The thumbnail URL
    static func thumbnailURL(for videoID: String, quality: ThumbnailQuality = .high) -> URL? {
        guard isValidVideoID(videoID) else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(videoID)/\(quality.rawValue).jpg")
    }
    
    /// Thumbnail quality options
    enum ThumbnailQuality: String {
        case `default` = "default"      // 120x90
        case medium = "mqdefault"       // 320x180
        case high = "hqdefault"         // 480x360
        case standard = "sddefault"     // 640x480
        case maxres = "maxresdefault"   // 1280x720
    }
    
    // MARK: - Private Helpers
    
    private static func matchPattern(_ pattern: String, in input: String, captureGroup: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(input.startIndex..., in: input)
        guard let match = regex.firstMatch(in: input, options: [], range: range) else {
            return nil
        }
        
        guard captureGroup < match.numberOfRanges,
              let captureRange = Range(match.range(at: captureGroup), in: input) else {
            return nil
        }
        
        return String(input[captureRange])
    }
}

// MARK: - Convenience Extensions

extension YouTubeURLParser {
    /// Result of parsing a YouTube URL
    struct ParseResult {
        let videoID: String
        let originalInput: String
        let watchURL: URL?
        let embedURL: URL?
        let thumbnailURL: URL?
        
        init?(from input: String) {
            guard let id = YouTubeURLParser.extractVideoID(from: input) else {
                return nil
            }
            self.videoID = id
            self.originalInput = input
            self.watchURL = YouTubeURLParser.youtubeURL(for: id)
            self.embedURL = YouTubeURLParser.embedURL(for: id)
            self.thumbnailURL = YouTubeURLParser.thumbnailURL(for: id)
        }
    }
    
    /// Parses input and returns a full result object
    static func parse(_ input: String) -> ParseResult? {
        return ParseResult(from: input)
    }
}

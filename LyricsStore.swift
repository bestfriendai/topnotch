import Foundation
import Combine

struct LRCLine: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval  // seconds
    let text: String
}

@MainActor
final class LyricsStore: ObservableObject {
    static let shared = LyricsStore()
    
    @Published var lines: [LRCLine] = []
    @Published var currentLineIndex: Int = 0
    @Published var isLoading = false
    @Published var hasLyrics = false
    @Published var isEnabled: Bool = (UserDefaults.standard.object(forKey: "lyricsEnabled") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "lyricsEnabled") }
    }
    
    private var currentTrackKey: String = ""
    private var cache: [String: [LRCLine]] = [:]
    
    private init() {}
    
    func fetchLyrics(artist: String, title: String, album: String) async {
        guard isEnabled else { return }
        let key = "\(artist.lowercased())-\(title.lowercased())"
        guard key != currentTrackKey else { return }
        currentTrackKey = key
        
        if let cached = cache[key] {
            lines = cached
            hasLyrics = !cached.isEmpty
            currentLineIndex = 0
            return
        }
        
        isLoading = true
        defer { isLoading = false }

        // Try with album first; if no match, retry without album (broader search)
        let syncedLyrics: String?
        if let found = await fetchSyncedLyrics(artist: artist, title: title, album: album) {
            syncedLyrics = found
        } else {
            syncedLyrics = await fetchSyncedLyrics(artist: artist, title: title, album: nil)
        }

        guard let syncedLyrics else {
            lines = []
            hasLyrics = false
            return
        }
        
        let parsed = parseLRC(syncedLyrics)
        cache[key] = parsed
        // Keep cache under 20 entries — don't evict the current track
        if cache.count > 20 {
            if let keyToRemove = cache.keys.first(where: { $0 != key }) {
                cache.removeValue(forKey: keyToRemove)
            }
        }
        lines = parsed
        hasLyrics = !parsed.isEmpty
        currentLineIndex = 0
    }
    
    func updateCurrentLine(elapsedTime: TimeInterval) {
        guard !lines.isEmpty else { return }
        // Find last line whose timestamp <= elapsedTime
        var newIndex = 0
        for (i, line) in lines.enumerated() {
            if line.timestamp <= elapsedTime + 0.5 {
                newIndex = i
            } else {
                break
            }
        }
        if newIndex != currentLineIndex {
            currentLineIndex = newIndex
        }
    }
    
    private func fetchSyncedLyrics(artist: String, title: String, album: String?) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        if let album, !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let synced = json["syncedLyrics"] as? String,
              !synced.isEmpty else { return nil }
        return synced
    }

    func clearLyrics() {
        lines = []
        hasLyrics = false
        currentLineIndex = 0
        currentTrackKey = ""
    }
    
    private func parseLRC(_ lrc: String) -> [LRCLine] {
        var result: [LRCLine] = []
        let linePattern = #"^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$"#
        guard let regex = try? NSRegularExpression(pattern: linePattern) else { return [] }
        
        for rawLine in lrc.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range) else { continue }
            
            func str(_ i: Int) -> String {
                guard let r = Range(match.range(at: i), in: trimmed) else { return "" }
                return String(trimmed[r])
            }
            
            let minutes = Double(str(1)) ?? 0
            let seconds = Double(str(2)) ?? 0
            let centisStr = str(3)
            let centis = (Double(centisStr) ?? 0) / (centisStr.count == 3 ? 1000.0 : 100.0)
            let timestamp = minutes * 60 + seconds + centis
            let text = str(4).trimmingCharacters(in: .whitespaces)
            
            // Skip empty instrumental lines and metadata tags
            if text.isEmpty || text.hasPrefix("[") { continue }
            result.append(LRCLine(timestamp: timestamp, text: text))
        }
        return result.sorted { $0.timestamp < $1.timestamp }
    }
}

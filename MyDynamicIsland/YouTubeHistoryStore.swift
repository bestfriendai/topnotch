import Combine
import Foundation

// MARK: - YouTube History

struct YouTubeHistoryItem: Codable, Equatable, Identifiable {
    var id: String { videoID }
    let videoID: String
    let addedAt: Date
}

final class YouTubeHistoryStore: ObservableObject {
    private static let key = "yt.recentlyPlayed"
    @Published var items: [YouTubeHistoryItem] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([YouTubeHistoryItem].self, from: data) {
            items = decoded
        }
    }

    func add(videoID: String) {
        items.removeAll { $0.videoID == videoID }
        items.insert(YouTubeHistoryItem(videoID: videoID, addedAt: .now), at: 0)
        if items.count > 5 { items = Array(items.prefix(5)) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

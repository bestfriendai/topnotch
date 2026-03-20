import Combine
import Foundation

struct UpcomingTrack: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
}

@MainActor
final class MusicQueueStore: ObservableObject {
    static let shared = MusicQueueStore()
    
    @Published var upcomingTracks: [UpcomingTrack] = []
    @Published var isAvailable = false  // Only true for Apple Music
    
    private init() {}
    
    func fetchQueue(appName: String) async {
        guard appName == "Music" else {
            upcomingTracks = []
            isAvailable = false
            return
        }
        isAvailable = true
        
        let output: String? = await Task.detached(priority: .userInitiated) {
            let script = """
            tell application "System Events"
                if not (exists process "Music") then return "|||NOT_RUNNING|||"
            end tell
            tell application "Music"
                try
                    if player state is not playing then return "|||NOT_PLAYING|||"
                    set pList to current playlist
                    set curIdx to index of current track
                    set totalCount to count of tracks of pList
                    if curIdx + 1 > totalCount then return "|||QUEUE_EMPTY|||"
                    set endIdx to curIdx + 3
                    if endIdx > totalCount then set endIdx to totalCount
                    set result to ""
                    repeat with i from (curIdx + 1) to endIdx
                        set t to track i of pList
                        set result to result & name of t & "||" & artist of t & "||" & album of t & "\\n"
                    end repeat
                    return result
                on error
                    return "|||ERROR|||"
                end try
            end tell
            """
            guard let scriptObject = NSAppleScript(source: script) else { return nil }
            var errorInfo: NSDictionary?
            let result = scriptObject.executeAndReturnError(&errorInfo)
            guard errorInfo == nil else { return nil }
            return result.stringValue
        }.value
        
        guard let output, !output.contains("|||") else {
            upcomingTracks = []
            return
        }
        
        var tracks: [UpcomingTrack] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: "||")
            guard parts.count >= 3 else { continue }
            tracks.append(UpcomingTrack(title: parts[0], artist: parts[1], album: parts[2]))
        }
        upcomingTracks = tracks
    }
    
    func clear() {
        upcomingTracks = []
        isAvailable = false
    }
}

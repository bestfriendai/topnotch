import AppKit
import Combine
import Foundation

// MARK: - FocusStatusStore

@MainActor
final class FocusStatusStore: ObservableObject {
    static let shared = FocusStatusStore()

    @Published var isDNDActive = false

    private var observer: NSObjectProtocol?

    private init() {
        refresh()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.donotdisturb.stateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    deinit {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
    }

    func refresh() {
        isDNDActive = UserDefaults(suiteName: "com.apple.ncprefs")?.bool(forKey: "dnd_prefs") ?? false
    }
}

// MARK: - ActivityEvent

struct ActivityEvent: Identifiable {
    let id = UUID()
    let type: EventType
    let title: String
    let detail: String
    let timestamp: Date
    var appIcon: String

    enum EventType: String {
        case music = "music"
        case charging = "charging"
        case clipboard = "clipboard"
        case focus = "focus"
        case battery = "battery"
        case system = "system"

        var icon: String {
            switch self {
            case .music:     return "music.note"
            case .charging:  return "bolt.fill"
            case .clipboard: return "doc.on.clipboard"
            case .focus:     return "moon.fill"
            case .battery:   return "battery.75"
            case .system:    return "gear"
            }
        }

        var color: String {
            switch self {
            case .music:     return "#1DB954"
            case .charging:  return "#34D399"
            case .clipboard: return "#60A5FA"
            case .focus:     return "#A78BFA"
            case .battery:   return "#FBBF24"
            case .system:    return "#8E8E93"
            }
        }
    }
}

// MARK: - NotificationDigestStore

@MainActor
final class NotificationDigestStore: ObservableObject {
    static let shared = NotificationDigestStore()

    @Published var events: [ActivityEvent] = []

    private var observers: [NSObjectProtocol] = []
    private let maxEvents = 60

    private init() {}

    func startMonitoring() {
        // Guard against duplicate observer registration
        guard observers.isEmpty else { return }

        let distributed = DistributedNotificationCenter.default()
        let local = NotificationCenter.default

        // Spotify playback
        observers.append(distributed.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil, queue: .main
        ) { [weak self] note in
            let state = note.userInfo?["Player State"] as? String
            let title = note.userInfo?["Name"] as? String ?? "Unknown"
            let artist = note.userInfo?["Artist"] as? String ?? ""
            if state == "Playing" || state == nil {
                Task { @MainActor [weak self] in
                    self?.addEvent(ActivityEvent(
                        type: .music,
                        title: title,
                        detail: artist.isEmpty ? "Spotify" : "Spotify · \(artist)",
                        timestamp: Date(),
                        appIcon: "Spotify"
                    ))
                }
            }
        })

        // Apple Music
        observers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil, queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo,
                  let state = info["Player State"] as? String,
                  state == "Playing",
                  let title = info["Name"] as? String else { return }
            let artist = info["Artist"] as? String ?? ""
            Task { @MainActor [weak self] in
                self?.addEvent(ActivityEvent(
                    type: .music,
                    title: title,
                    detail: artist.isEmpty ? "Apple Music" : "Apple Music · \(artist)",
                    timestamp: Date(),
                    appIcon: "Music"
                ))
            }
        })

        // Clipboard changes
        observers.append(local.addObserver(
            forName: NSNotification.Name("TopNotch.ClipboardChanged"),
            object: nil, queue: .main
        ) { [weak self] note in
            let text = note.userInfo?["text"] as? String ?? ""
            let preview = text.count > 50 ? String(text.prefix(50)) + "…" : text
            Task { @MainActor [weak self] in
                self?.addEvent(ActivityEvent(
                    type: .clipboard,
                    title: "Clipboard Updated",
                    detail: preview,
                    timestamp: Date(),
                    appIcon: "clipboard"
                ))
            }
        })

        // Battery charging started
        observers.append(local.addObserver(
            forName: NSNotification.Name("TopNotch.ChargingStarted"),
            object: nil, queue: .main
        ) { [weak self] note in
            let level = note.userInfo?["level"] as? Int ?? 0
            Task { @MainActor [weak self] in
                self?.addEvent(ActivityEvent(
                    type: .charging,
                    title: "Charging Started",
                    detail: "\(level)% · Connected to power",
                    timestamp: Date(),
                    appIcon: "bolt.fill"
                ))
            }
        })

        // Battery disconnected
        observers.append(local.addObserver(
            forName: NSNotification.Name("TopNotch.ChargingEnded"),
            object: nil, queue: .main
        ) { [weak self] note in
            let level = note.userInfo?["level"] as? Int ?? 0
            Task { @MainActor [weak self] in
                self?.addEvent(ActivityEvent(
                    type: .battery,
                    title: "Power Disconnected",
                    detail: "\(level)% · Running on battery",
                    timestamp: Date(),
                    appIcon: "battery.75"
                ))
            }
        })

        // Focus/DND state changes
        observers.append(distributed.addObserver(
            forName: NSNotification.Name("com.apple.donotdisturb.stateChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in
            let isActive = UserDefaults(suiteName: "com.apple.ncprefs")?.bool(forKey: "dnd_prefs") ?? false
            Task { @MainActor [weak self] in
                self?.addEvent(ActivityEvent(
                    type: .focus,
                    title: isActive ? "Focus Enabled" : "Focus Disabled",
                    detail: isActive ? "Do Not Disturb turned on" : "Do Not Disturb turned off",
                    timestamp: Date(),
                    appIcon: "moon.fill"
                ))
            }
        })
    }

    private func addEvent(_ event: ActivityEvent) {
        // Deduplicate: skip same type+title within 5 seconds
        if let last = events.first,
           last.type == event.type,
           last.title == event.title,
           Date().timeIntervalSince(last.timestamp) < 5 { return }

        events.insert(event, at: 0)
        if events.count > maxEvents { events = Array(events.prefix(maxEvents)) }
    }

    func clearAll() { events = [] }
}

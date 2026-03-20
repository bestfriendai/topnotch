import AppKit
import Combine
import Foundation

struct ShortcutItem: Identifiable {
    let id = UUID()
    let name: String
    
    var icon: String {
        // Map common shortcut names to icons
        let lower = name.lowercased()
        if lower.contains("photo") || lower.contains("image") { return "photo" }
        if lower.contains("message") || lower.contains("send") { return "message" }
        if lower.contains("music") || lower.contains("play") { return "music.note" }
        if lower.contains("reminder") || lower.contains("todo") { return "checklist" }
        if lower.contains("note") { return "note.text" }
        if lower.contains("email") || lower.contains("mail") { return "envelope" }
        if lower.contains("calendar") { return "calendar" }
        if lower.contains("file") || lower.contains("folder") { return "folder" }
        if lower.contains("web") || lower.contains("url") || lower.contains("open") { return "globe" }
        if lower.contains("clipboard") || lower.contains("copy") { return "clipboard" }
        return "bolt.fill"
    }
}

@MainActor
final class ShortcutsStore: ObservableObject {
    static let shared = ShortcutsStore()
    
    @Published var shortcuts: [ShortcutItem] = []
    @Published var isLoading = false
    @Published var isRunning = false
    @Published var lastRunName: String = ""
    
    private init() {}
    
    func fetchShortcuts() async {
        isLoading = true
        defer { isLoading = false }

        #if APP_STORE_BUILD
        // App Store: use AppleScript to list shortcuts (Process() is sandbox-blocked)
        let names: [String] = await Task.detached(priority: .userInitiated) {
            let script = """
            tell application "Shortcuts"
                return name of every shortcut
            end tell
            """
            guard let scriptObject = NSAppleScript(source: script) else { return [] }
            var errorInfo: NSDictionary?
            let result = scriptObject.executeAndReturnError(&errorInfo)
            guard errorInfo == nil else { return [] }
            var names: [String] = []
            let count = result.numberOfItems
            if count > 0 {
                for i in 1...count {
                    if let name = result.atIndex(i)?.stringValue {
                        names.append(name)
                    }
                }
            }
            return names
        }.value
        shortcuts = names.map { ShortcutItem(name: $0) }
        #else
        let output: String? = await Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            proc.arguments = ["list"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            guard (try? proc.run()) != nil else { return nil }
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        }.value

        guard let output else { return }
        let names = output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        shortcuts = names.map { ShortcutItem(name: $0) }
        #endif
    }

    func runShortcut(_ name: String) {
        isRunning = true
        lastRunName = name
        #if APP_STORE_BUILD
        // App Store: use URL scheme to run shortcut (Process() is sandbox-blocked)
        Task { @MainActor in
            if let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") {
                NSWorkspace.shared.open(url)
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            isRunning = false
            lastRunName = ""
        }
        #else
        Task.detached(priority: .userInitiated) { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            proc.arguments = ["run", name]
            let launched = (try? proc.run()) != nil
            if launched { proc.waitUntilExit() }
            Task { @MainActor [weak self] in
                // Small delay so user can see "running" state
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.isRunning = false
                self?.lastRunName = ""
            }
        }
        #endif
    }
}

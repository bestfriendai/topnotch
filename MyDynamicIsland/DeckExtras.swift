import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Design Colors (clipboard)

private let cardBgClip = Color(red: 0.086, green: 0.086, blue: 0.102)
private let textPrimaryClip = Color(red: 0.98, green: 0.98, blue: 0.976)
private let textSecondaryClip = Color(red: 0.42, green: 0.42, blue: 0.44)
private let textTertiaryClip = Color(red: 0.29, green: 0.29, blue: 0.31)
private let borderSubtleClip = Color(red: 0.165, green: 0.165, blue: 0.18)
private let accentCyanClip = Color(red: 0.024, green: 0.714, blue: 0.831)
private let accentBlueClip = Color(red: 0.039, green: 0.518, blue: 1.0)
private let accentGreenClip = Color(red: 0.196, green: 0.835, blue: 0.514)
private let accentRedClip = Color(red: 0.91, green: 0.353, blue: 0.31)

// MARK: - Clipboard History Card

struct ClipboardDeckCard: View {
    @StateObject private var clipboard = ClipboardHistoryStore.shared
    @State private var contentAppeared = false
    @State private var copiedItemID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: "Clipboard" title + item count
            HStack {
                Image(systemName: "clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentCyanClip)
                Text(NSLocalizedString("nav.clipboard", comment: ""))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(textPrimaryClip)
                Spacer()
                Text(String(format: NSLocalizedString("clipboard.itemCount", comment: ""), clipboard.items.count))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textSecondaryClip)
            }

            // Items list — show last 3 clipboard items as previews
            VStack(spacing: 5) {
                if clipboard.items.isEmpty {
                    ClipboardEmptyState()
                } else {
                    ForEach(Array(clipboard.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                        compactClipboardRow(item: item, index: index)
                    }
                }
            }

            Spacer(minLength: 0)

            // Bottom row: NSLocalizedString("clipboard.clearAll", comment: "") + remaining count
            if !clipboard.items.isEmpty {
                HStack {
                    Button(action: { clipboard.clearAll() }) {
                        Text(NSLocalizedString("clipboard.clearAll", comment: ""))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accentRedClip)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if clipboard.items.count > 3 {
                        Text(String(format: NSLocalizedString("clipboard.moreItems", comment: ""), clipboard.items.count - 3))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(textTertiaryClip)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func compactClipboardRow(item: ClipboardItem, index: Int) -> some View {
        let isCopied = copiedItemID == item.id
        return HStack(spacing: 6) {
            // Type icon
            Image(systemName: item.icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(item.iconColor.opacity(0.7))
                .frame(width: 14)

            // Content preview (2 lines max)
            Text(item.preview)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(textPrimaryClip)
                .lineLimit(2)

            Spacer(minLength: 4)

            // Copy feedback or time
            if isCopied {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(accentGreenClip)
                    Text(NSLocalizedString("clipboard.copied", comment: ""))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(accentGreenClip)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text(item.timeAgo)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(textTertiaryClip)
            }

            // Delete button
            Button(action: { clipboard.removeItem(item) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(textTertiaryClip)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCopied ? accentGreenClip.opacity(0.08) : cardBgClip)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isCopied ? accentGreenClip.opacity(0.3) : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            clipboard.copyItem(item)
            withAnimation(.easeInOut(duration: 0.15)) { copiedItemID = item.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.2)) { copiedItemID = nil }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isCopied)
    }
}

// MARK: - Clipboard Empty State

struct ClipboardEmptyState: View {
    @State private var breathing = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "clipboard")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(breathing ? 0.2 : 0.12))
                .scaleEffect(breathing ? 1.05 : 0.95)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: breathing
                )
            Text(NSLocalizedString("clipboard.copySomething", comment: ""))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
                .foregroundStyle(.white.opacity(0.08))
        )
        .onAppear { breathing = true }
    }
}

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let index: Int
    let onCopy: () -> Void

    @State private var isHovered = false
    @State private var justCopied = false

    /// Font for the content preview — monospaced for code, default for others
    private var previewFont: Font {
        switch item.type {
        case .code:
            return .system(size: 9, weight: .medium, design: .monospaced)
        default:
            return .system(size: 9, weight: .medium)
        }
    }

    var body: some View {
        Button(action: {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            onCopy()
            withAnimation(.easeInOut(duration: 0.15)) {
                justCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    justCopied = false
                }
            }
        }) {
            HStack(spacing: 6) {
                // Numbered badge
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 16, height: 16)
                    Text("\(index + 1)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }

                // Left accent border
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(item.iconColor.opacity(isHovered ? 0.7 : 0.35))
                    .frame(width: 2, height: 16)

                // Type indicator — globe for URLs, standard icon for others
                ZStack {
                    Circle()
                        .fill(item.iconColor.opacity(0.15))
                        .frame(width: 12, height: 12)
                    Image(systemName: item.type == .url ? "globe" : item.icon)
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(item.iconColor)
                }

                // Content preview (monospaced for code)
                Text(item.preview)
                    .font(previewFont)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                // Right side: copy feedback or time
                if justCopied {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.green)
                        Text(NSLocalizedString("clipboard.copied", comment: ""))
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else if isHovered {
                    HStack(spacing: 2) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.cyan)
                        Text(NSLocalizedString("clipboard.copy", comment: ""))
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text(item.timeAgo)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(justCopied ? Color.green.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: justCopied)
    }
}

// MARK: - Clipboard Data Model

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let type: ClipboardItemType
    let timestamp: Date

    init(content: String, type: ClipboardItemType, timestamp: Date) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = timestamp
    }

    enum ClipboardItemType: String, Codable {
        case text, url, code
    }

    var icon: String {
        switch type {
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        }
    }

    var iconColor: Color {
        switch type {
        case .url: return .blue
        case .code: return .green
        case .text: return .cyan
        }
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(60))
    }

    var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60 { return NSLocalizedString("time.now", comment: "") }
        if seconds < 3600 { return String(format: NSLocalizedString("time.minutesAgo", comment: ""), seconds / 60) }
        return String(format: NSLocalizedString("time.hoursAgo", comment: ""), seconds / 3600)
    }
}

// MARK: - Clipboard History Store

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    static let shared = ClipboardHistoryStore()

    private static let persistenceKey = "clipboardHistoryItems"
    private static let maxItems = 20

    @Published var items: [ClipboardItem] = [] {
        didSet { persistItems() }
    }

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    /// Set to true briefly after we programmatically write to the pasteboard
    /// so the next poll doesn't re-add the same item.
    private var suppressNextChange = false

    private init() {
        loadPersistedItems()
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
        // Seed with current clipboard content
        checkClipboard()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkClipboard()
            }
        }
    }

    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // If we just wrote to the pasteboard ourselves, skip this cycle
        if suppressNextChange {
            suppressNextChange = false
            return
        }

        guard let rawString = NSPasteboard.general.string(forType: .string),
              !rawString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Truncate extremely large clipboard content to prevent memory bloat
        let string = rawString.count > 10_000 ? String(rawString.prefix(10_000)) : rawString

        // Don't add duplicates of the most recent item
        if let first = items.first, first.content == string { return }

        // Remove any older duplicate of this exact content so it moves to the top
        items.removeAll { $0.content == string }

        let type = Self.detectType(string)
        let item = ClipboardItem(content: string, type: type, timestamp: Date())
        withAnimation(.easeInOut(duration: 0.25)) {
            items.insert(item, at: 0)
        }

        // Keep max items
        if items.count > Self.maxItems {
            items = Array(items.prefix(Self.maxItems))
        }

        // Notify the Activity Feed
        NotificationCenter.default.post(
            name: NSNotification.Name("TopNotch.ClipboardChanged"),
            object: nil,
            userInfo: ["text": string]
        )
    }

    /// Detect the type of clipboard content.
    static func detectType(_ string: String) -> ClipboardItem.ClipboardItemType {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return .url
        } else if trimmed.contains("{") || trimmed.contains("func ") || trimmed.contains("class ") || trimmed.contains("import ") {
            return .code
        } else {
            return .text
        }
    }

    func copyItem(_ item: ClipboardItem) {
        suppressNextChange = true
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    func removeItem(_ item: ClipboardItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            items.removeAll { $0.id == item.id }
        }
    }

    func clearAll() {
        withAnimation(.easeInOut(duration: 0.25)) {
            items.removeAll()
        }
    }

    // MARK: - Persistence

    private func persistItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.persistenceKey)
    }

    private func loadPersistedItems() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = Array(decoded.prefix(Self.maxItems))
    }
}

// MARK: - App Launcher Grid Card

struct AppLauncherDeckCard: View {
    @StateObject private var store = AppLauncherStore()
    @State private var contentAppeared = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.purple)
                Text(NSLocalizedString("shortcuts.title", comment: ""))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(NSLocalizedString("clipboard.edit", comment: ""))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }

            // Subtle divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.06), .white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            // App grid with staggered entrance
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(store.apps.enumerated()), id: \.element.id) { index, app in
                    AppGridItem(app: app)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 8)
                        .animation(
                            .spring(duration: 0.4, bounce: 0.3).delay(min(Double(index) * 0.05, 0.30)),
                            value: contentAppeared
                        )
                }
            }
        }
        .onAppear {
            withAnimation { contentAppeared = true }
        }
        .onDisappear {
            contentAppeared = false
        }
    }
}

struct AppGridItem: View {
    let app: LauncherApp
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            NSWorkspace.shared.open(app.url)
        }) {
            VStack(spacing: 4) {
                ZStack {
                    // Rounded rect background that lights up on hover
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(isHovered ? 0.1 : 0.04))
                        .frame(width: 48, height: 48)
                        .animation(.easeInOut(duration: 0.15), value: isHovered)

                    // Subtle glow on hover
                    if isHovered {
                        Circle()
                            .fill((app.glowColor).opacity(0.2))
                            .frame(width: 42, height: 42)
                            .blur(radius: 8)
                            .transition(.opacity)
                    }

                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            .overlay(
                                // Shine / reflection overlay
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(isHovered ? 0.18 : 0.1),
                                                .clear,
                                                .clear,
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "app.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white.opacity(0.5))
                            )
                    }
                }

                Text(app.name)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(isHovered ? 1.0 : 0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 48)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
            .scaleEffect(isPressed ? 0.9 : (isHovered ? 1.05 : 1.0))
            .animation(.spring(duration: 0.2, bounce: 0.4), value: isHovered)
            .animation(.spring(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - App Launcher Store

struct LauncherApp: Identifiable {
    var id: String { url.path }
    let name: String
    let url: URL
    let icon: NSImage?

    /// Approximate glow color derived from the app icon
    var glowColor: Color {
        guard let icon = icon,
              let tiff = icon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return .purple
        }
        // Sample center pixel for dominant color
        let x = bitmap.pixelsWide / 2
        let y = bitmap.pixelsHigh / 2
        guard let color = bitmap.colorAt(x: x, y: y) else { return .purple }
        return Color(nsColor: color)
    }
}

@MainActor
final class AppLauncherStore: ObservableObject {
    @Published var apps: [LauncherApp] = []

    init() {
        loadPopularApps()
    }

    private func loadPopularApps() {
        let appPaths = [
            "/Applications/Safari.app",
            "/Applications/Spotify.app",
            "/System/Applications/Messages.app",
            "/Applications/Slack.app",
            "/System/Applications/Notes.app",
            "/System/Applications/Music.app",
        ]

        var loaded: [LauncherApp] = []
        for path in appPaths {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let name = url.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 64, height: 64)
            loaded.append(LauncherApp(name: name, url: url, icon: icon))
            if loaded.count >= 6 { break }
        }

        // If we don't have 6, fill with more system apps
        let fallbackPaths = [
            "/System/Applications/Calendar.app",
            "/System/Applications/Mail.app",
            "/System/Applications/FaceTime.app",
            "/System/Applications/Photos.app",
            "/System/Applications/System Settings.app",
            "/Applications/Visual Studio Code.app",
            "/Applications/Arc.app",
            "/Applications/Google Chrome.app",
            "/Applications/Firefox.app",
            "/Applications/Discord.app",
        ]

        for path in fallbackPaths where loaded.count < 6 {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let name = url.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 64, height: 64)
            loaded.append(LauncherApp(name: name, url: url, icon: icon))
        }

        apps = loaded
    }
}

// MARK: - File Shelf Store

struct ShelfFile: Identifiable, Equatable {
    var id: String { url.absoluteString }
    let url: URL
    let name: String
    let icon: NSImage
    let addedAt: Date

    static func == (lhs: ShelfFile, rhs: ShelfFile) -> Bool {
        lhs.url == rhs.url
    }
}

@MainActor
final class FileShelfStore: ObservableObject {
    static let shared = FileShelfStore()
    private init() {}

    @Published var files: [ShelfFile] = []

    func addFile(url: URL) {
        // Prevent duplicates
        guard !files.contains(where: { $0.url == url }) else { return }

        let name = url.lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)

        withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
            files.insert(ShelfFile(url: url, name: name, icon: icon, addedAt: Date()), at: 0)
        }

        // Limit to 10 files
        if files.count > 10 {
            files.removeLast()
        }
    }

    func removeFile(_ file: ShelfFile) {
        withAnimation {
            files.removeAll(where: { $0.id == file.id })
        }
    }

    func clearAll() {
        withAnimation {
            files.removeAll()
        }
    }
}

// MARK: - File Shelf Card

struct FileShelfDeckCard: View {
    @StateObject private var store = FileShelfStore.shared
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(NSLocalizedString("fileShelf.title", comment: ""), systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)
                Spacer()
                if !store.files.isEmpty {
                    Button(NSLocalizedString("fileShelf.clear", comment: "")) { store.clearAll() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            if store.files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "plus.circle.dotted")
                        .font(.system(size: isTargeted ? 32 : 24))
                        .foregroundStyle(isTargeted ? Color.orange : .white.opacity(0.2))
                        .scaleEffect(isTargeted ? 1.15 : 1.0)
                        .animation(.spring(duration: 0.3, bounce: 0.5), value: isTargeted)
                    Text(isTargeted ? NSLocalizedString("fileShelf.releaseToAdd", comment: "") : NSLocalizedString("fileShelf.dropFilesHere", comment: ""))
                        .font(.system(size: 12, weight: isTargeted ? .semibold : .regular))
                        .foregroundStyle(isTargeted ? Color.orange : .white.opacity(0.3))
                        .animation(.easeInOut(duration: 0.2), value: isTargeted)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isTargeted ? Color.orange.opacity(0.06) : Color.clear)
                        .animation(.easeInOut(duration: 0.2), value: isTargeted)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [4, 4])
                        )
                        .foregroundStyle(isTargeted ? Color.orange.opacity(0.8) : Color.white.opacity(0.1))
                        .animation(.easeInOut(duration: 0.2), value: isTargeted)
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(store.files) { file in
                            HStack(spacing: 10) {
                                Image(nsImage: file.icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                Text(file.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)
                                Spacer()
                                Button(action: { store.removeFile(file) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.2))
                                }.buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                            .onDrag {
                                return NSItemProvider(contentsOf: file.url) ?? NSItemProvider()
                            }
                        }
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            store.addFile(url: url)
                        }
                    }
                }
            }
            return true
        }
    }
}

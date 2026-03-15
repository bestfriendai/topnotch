import AppKit
import Combine
import SwiftUI

// MARK: - Clipboard History Card

struct ClipboardDeckCard: View {
    @StateObject private var clipboard = ClipboardHistoryStore()
    @State private var contentAppeared = false
    @State private var countPulse = false
    @State private var previousCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan)
                Text("Clipboard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)

                // Clear button (visible when items exist)
                if !clipboard.items.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            clipboard.items.removeAll()
                        }
                    }) {
                        Text("Clear")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                // Item count badge with pulse
                Text("\(clipboard.items.count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .scaleEffect(countPulse ? 1.25 : 1.0)
                    .animation(.spring(duration: 0.3, bounce: 0.5), value: countPulse)
            }

            if clipboard.items.isEmpty {
                Spacer(minLength: 0)
                ClipboardEmptyState()
                Spacer(minLength: 0)
            } else {
                // List of clipboard items (scrollable, max 5)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(Array(clipboard.items.prefix(5).enumerated()), id: \.offset) { index, item in
                            ClipboardItemRow(item: item, index: index) {
                                clipboard.copyItem(item)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 6)
                .animation(.easeOut(duration: 0.35), value: contentAppeared)
            }
        }
        .onAppear {
            previousCount = clipboard.items.count
            withAnimation { contentAppeared = true }
        }
        .onChange(of: clipboard.items.count) { newCount in
            if newCount > previousCount {
                countPulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    countPulse = false
                }
            }
            previousCount = newCount
        }
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
            Text("Copy something to see it here")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
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
                // Left accent border
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(item.iconColor.opacity(isHovered ? 0.7 : 0.35))
                    .frame(width: 2, height: 16)

                // Type indicator in colored circle
                ZStack {
                    Circle()
                        .fill(item.iconColor.opacity(0.15))
                        .frame(width: 12, height: 12)
                    Image(systemName: item.icon)
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(item.iconColor)
                }

                // Content preview
                Text(item.preview)
                    .font(.system(size: 9, weight: .medium))
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
                        Text("Copied")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else if isHovered {
                    HStack(spacing: 2) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.cyan)
                        Text("Copy")
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

struct ClipboardItem {
    let content: String
    let type: ClipboardItemType
    let timestamp: Date

    enum ClipboardItemType {
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
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}

// MARK: - Clipboard History Store

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    @Published var items: [ClipboardItem] = []
    private var timer: Timer?
    private var lastChangeCount: Int = 0

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
        // Seed with current clipboard content
        checkClipboard()
    }

    deinit {
        timer?.invalidate()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
    }

    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let string = NSPasteboard.general.string(forType: .string),
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Don't add duplicates of the most recent item
        if let first = items.first, first.content == string { return }

        let type: ClipboardItem.ClipboardItemType
        if string.hasPrefix("http://") || string.hasPrefix("https://") {
            type = .url
        } else if string.contains("{") || string.contains("func ") || string.contains("class ") || string.contains("import ") {
            type = .code
        } else {
            type = .text
        }

        let item = ClipboardItem(content: string, type: type, timestamp: Date())
        withAnimation(.easeInOut(duration: 0.25)) {
            items.insert(item, at: 0)
        }

        // Keep max 20 items
        if items.count > 20 {
            items = Array(items.prefix(20))
        }
    }

    func copyItem(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
    }
}

// MARK: - App Launcher Grid Card

struct AppLauncherDeckCard: View {
    @StateObject private var store = AppLauncherStore()
    @State private var contentAppeared = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.purple)
                Text("Apps")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("Edit")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
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
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(store.apps.enumerated()), id: \.element.id) { index, app in
                    AppGridItem(app: app)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 8)
                        .animation(
                            .spring(duration: 0.4, bounce: 0.3).delay(Double(index) * 0.05),
                            value: contentAppeared
                        )
                }
            }
        }
        .onAppear {
            withAnimation { contentAppeared = true }
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
            VStack(spacing: 3) {
                ZStack {
                    // Subtle glow on hover
                    if isHovered {
                        Circle()
                            .fill((app.glowColor).opacity(0.2))
                            .frame(width: 36, height: 36)
                            .blur(radius: 8)
                            .transition(.opacity)
                    }

                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            .overlay(
                                // Shine / reflection overlay
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "app.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white.opacity(0.5))
                            )
                    }
                }

                Text(app.name)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(isHovered ? 1.0 : 0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
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
    let id = UUID()
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
